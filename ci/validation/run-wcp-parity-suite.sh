#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_WCP_PARITY_OUT_DIR:=${ROOT_DIR}/docs/reverse/deep-ide}"
: "${WLT_WCP_PARITY_PAIRS_FILE:=${ROOT_DIR}/ci/validation/wcp-parity-pairs.tsv}"
: "${WLT_WCP_PARITY_REQUIRE_ANY:=0}"
: "${WLT_WCP_PARITY_FAIL_ON_MISSING:=0}"
: "${WLT_WCP_PARITY_LABELS:=}"

log() { printf '[wcp-parity-suite] %s\n' "$*"; }
warn() { printf '[wcp-parity-suite][warn] %s\n' "$*" >&2; }
fail() { printf '[wcp-parity-suite][error] %s\n' "$*" >&2; exit 1; }

[[ "${WLT_WCP_PARITY_REQUIRE_ANY}" =~ ^[01]$ ]] || fail "WLT_WCP_PARITY_REQUIRE_ANY must be 0 or 1"
[[ "${WLT_WCP_PARITY_FAIL_ON_MISSING}" =~ ^[01]$ ]] || fail "WLT_WCP_PARITY_FAIL_ON_MISSING must be 0 or 1"
[[ -f "${WLT_WCP_PARITY_PAIRS_FILE}" ]] || fail "pairs file not found: ${WLT_WCP_PARITY_PAIRS_FILE}"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

resolve_path() {
  local raw="$1"
  if [[ "${raw}" = /* ]]; then
    printf '%s\n' "${raw}"
  else
    printf '%s/%s\n' "${ROOT_DIR}" "${raw}"
  fi
}

label_selected() {
  local needle="$1"
  local labels item
  if [[ -z "${WLT_WCP_PARITY_LABELS}" ]]; then
    return 0
  fi
  IFS=',' read -r -a labels <<< "${WLT_WCP_PARITY_LABELS}"
  for item in "${labels[@]}"; do
    item="$(trim "${item}")"
    [[ -n "${item}" ]] || continue
    if [[ "${item}" == "${needle}" ]]; then
      return 0
    fi
  done
  return 1
}

sanitize_label() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'
}

mkdir -p "${WLT_WCP_PARITY_OUT_DIR}"
status_tsv="${WLT_WCP_PARITY_OUT_DIR}/PARITY_SUITE_STATUS.tsv"
summary_md="${WLT_WCP_PARITY_OUT_DIR}/PARITY_SUITE_REPORT.md"
summary_meta="${WLT_WCP_PARITY_OUT_DIR}/PARITY_SUITE.summary.meta"
printf 'label\tstatus\trc\tsource\tinstalled\treport\tnote\n' > "${status_tsv}"

total_rows=0
selected_rows=0
executed_rows=0
passed_rows=0
failed_rows=0
missing_rows=0
suite_rc=0

while IFS=$'\t' read -r raw_label raw_source raw_installed raw_note _rest; do
  raw_label="$(trim "${raw_label:-}")"
  raw_source="$(trim "${raw_source:-}")"
  raw_installed="$(trim "${raw_installed:-}")"
  raw_note="$(trim "${raw_note:-}")"

  [[ -n "${raw_label}" ]] || continue
  [[ "${raw_label}" == \#* ]] && continue
  total_rows=$((total_rows + 1))

  if ! label_selected "${raw_label}"; then
    continue
  fi

  selected_rows=$((selected_rows + 1))
  safe_label="$(sanitize_label "${raw_label}")"
  report_md="${WLT_WCP_PARITY_OUT_DIR}/PARITY_${safe_label}.md"
  rc=0

  if [[ -z "${raw_source}" || -z "${raw_installed}" ]]; then
    warn "invalid row in pairs file for label=${raw_label}: source/installed is empty"
    failed_rows=$((failed_rows + 1))
    suite_rc=1
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${raw_label}" "invalid-row" "1" "${raw_source}" "${raw_installed}" "-" "${raw_note}" >> "${status_tsv}"
    continue
  fi

  source_path="$(resolve_path "${raw_source}")"
  installed_path="$(resolve_path "${raw_installed}")"

  missing_source=0
  missing_installed=0
  [[ -e "${source_path}" ]] || missing_source=1
  [[ -d "${installed_path}" ]] || missing_installed=1

  if [[ "${missing_source}" == "1" || "${missing_installed}" == "1" ]]; then
    status="missing"
    if [[ "${missing_source}" == "1" && "${missing_installed}" == "1" ]]; then
      status="missing-both"
      warn "missing source+installed for ${raw_label}"
    elif [[ "${missing_source}" == "1" ]]; then
      status="missing-source"
      warn "missing source for ${raw_label}: ${source_path}"
    else
      status="missing-installed"
      warn "missing installed for ${raw_label}: ${installed_path}"
    fi
    missing_rows=$((missing_rows + 1))
    if [[ "${WLT_WCP_PARITY_FAIL_ON_MISSING}" == "1" ]]; then
      suite_rc=1
      rc=1
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${raw_label}" "${status}" "${rc}" "${source_path}" "${installed_path}" "-" "${raw_note}" >> "${status_tsv}"
    continue
  fi

  executed_rows=$((executed_rows + 1))
  if python3 "${ROOT_DIR}/ci/validation/check-wcp-content-parity.py" \
      --source "${source_path}" \
      --installed "${installed_path}" \
      --out "${report_md}"; then
    passed_rows=$((passed_rows + 1))
    status="pass"
    rc=0
  else
    failed_rows=$((failed_rows + 1))
    suite_rc=1
    status="fail"
    rc=1
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${raw_label}" "${status}" "${rc}" "${source_path}" "${installed_path}" "${report_md}" "${raw_note}" >> "${status_tsv}"
done < "${WLT_WCP_PARITY_PAIRS_FILE}"

if [[ "${WLT_WCP_PARITY_REQUIRE_ANY}" == "1" && "${executed_rows}" == "0" ]]; then
  warn "require-any is set but no parity pair was executed"
  suite_rc=1
fi

{
  printf '# WCP Parity Suite\n\n'
  printf -- '- Date (UTC): `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '- Pairs file: `%s`\n' "${WLT_WCP_PARITY_PAIRS_FILE}"
  printf -- '- Selected rows: **%s**\n' "${selected_rows}"
  printf -- '- Executed rows: **%s**\n' "${executed_rows}"
  printf -- '- Passed rows: **%s**\n' "${passed_rows}"
  printf -- '- Failed rows: **%s**\n' "${failed_rows}"
  printf -- '- Missing rows: **%s**\n' "${missing_rows}"
  printf -- '- Status rc: **%s**\n\n' "${suite_rc}"
  printf '## Pair Status\n\n'
  printf '| label | status | rc | source | installed | report | note |\n'
  printf '| --- | --- | --- | --- | --- | --- | --- |\n'
  awk -F '\t' 'NR>1 {
    printf("| %s | %s | %s | `%s` | `%s` | `%s` | %s |\n", $1, $2, $3, $4, $5, $6, $7)
  }' "${status_tsv}"
  printf '\n'
} > "${summary_md}"

{
  printf 'time_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'pairs_file=%s\n' "${WLT_WCP_PARITY_PAIRS_FILE}"
  printf 'labels=%s\n' "${WLT_WCP_PARITY_LABELS}"
  printf 'require_any=%s\n' "${WLT_WCP_PARITY_REQUIRE_ANY}"
  printf 'fail_on_missing=%s\n' "${WLT_WCP_PARITY_FAIL_ON_MISSING}"
  printf 'total_rows=%s\n' "${total_rows}"
  printf 'selected_rows=%s\n' "${selected_rows}"
  printf 'executed_rows=%s\n' "${executed_rows}"
  printf 'passed_rows=%s\n' "${passed_rows}"
  printf 'failed_rows=%s\n' "${failed_rows}"
  printf 'missing_rows=%s\n' "${missing_rows}"
  printf 'rc=%s\n' "${suite_rc}"
} > "${summary_meta}"

log "Suite report: ${summary_md}"
log "Suite status: ${status_tsv}"
exit "${suite_rc}"
