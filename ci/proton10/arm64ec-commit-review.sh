#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work/proton10}"
OUT_DIR="${WCP_OUTPUT_DIR:-${ROOT_DIR}/out}"
REPORT_FILE="${ARM64EC_REVIEW_REPORT:-${ROOT_DIR}/docs/ARM64EC_PATCH_REVIEW.md}"
SERIES_FILE="${ARM64EC_SERIES_FILE:-${OUT_DIR}/arm64ec-series.txt}"
LOG_DIR="${OUT_DIR}/logs"

: "${ANDRE_WINE_REPO:=https://github.com/AndreRH/wine.git}"
: "${ANDRE_ARM64EC_REF:=arm64ec}"
: "${ANDRE_BASE_REF:=master}"
: "${VALVE_WINE_REPO:=https://github.com/ValveSoftware/wine.git}"
: "${VALVE_WINE_REF:=986bda11d3e569813ec0f86e56ef94d7c384da04}"
: "${ARM64EC_TOPIC_REGEX:=arm64ec|hangover|woa|wow64ec|arm64x|arm64ecfex}"
: "${ARM64EC_FILE_GLOB_1:=*arm64ec*}"
: "${ARM64EC_FILE_GLOB_2:=*hangover*}"
: "${ARM64EC_FILE_GLOB_3:=*woa*}"
: "${ARM64EC_EXCLUDE_SUBJECT_REGEX:=^ntdll: (Store special environment variables with a UNIX_|Set the environment variables for Unix child processes from their UNIX_|Treat all the XDG_|Get rid of the wine_unix_to_nt_file_name syscall\\.|Get rid of the wine_nt_to_unix_file_name syscall\\.|Implement NtGetNextProcess\\.)}"
: "${ARM64EC_MAX_COMMITS:=0}"

log() { printf '[proton10][review] %s\n' "$*"; }
fail() { printf '[proton10][review][error] %s\n' "$*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

retry_cmd() {
  local attempts delay n
  attempts="${RETRY_ATTEMPTS:-3}"
  delay="${RETRY_DELAY_SEC:-5}"
  n=1
  while true; do
    if "$@"; then
      return 0
    fi
    if [[ "${n}" -ge "${attempts}" ]]; then
      return 1
    fi
    log "Command failed (attempt ${n}/${attempts}), retrying in ${delay}s: $*"
    sleep "${delay}"
    n=$((n + 1))
  done
}

infer_purpose() {
  local subject_lc files
  subject_lc="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  files="$2"

  if printf '%s\n%s\n' "${subject_lc}" "${files}" | grep -qi 'arm64ec'; then
    printf 'Усиление/исправление ARM64EC совместимости.'
  elif printf '%s\n%s\n' "${subject_lc}" "${files}" | grep -qi 'wow64'; then
    printf 'Изменения WoW64 пути исполнения и межархитектурной связки.'
  elif printf '%s\n%s\n' "${subject_lc}" "${files}" | grep -qi 'ntdll'; then
    printf 'Низкоуровневые изменения ntdll для корректной инициализации и ABI.'
  elif printf '%s\n%s\n' "${subject_lc}" "${files}" | grep -qi '^loader/'; then
    printf 'Правки загрузчика/инициализации процесса.'
  elif printf '%s\n%s\n' "${subject_lc}" "${files}" | grep -qi '^server/'; then
    printf 'Изменения wine server протокола/синхронизации.'
  else
    printf 'Поддерживающие изменения для портирования/стабилизации ветки.'
  fi
}

main() {
  local andre_dir series_ref base_ref valve_ref range_ref merge_base valve_merge_base commit_count today
  local full_series_file subject_hits_file path_hits_file selected_set_file filtered_count total_count
  local selected_filtered_file hash subject

  require_cmd git
  require_cmd awk
  require_cmd sed
  require_cmd wc

  mkdir -p "${WORK_DIR}" "${OUT_DIR}" "${LOG_DIR}" "$(dirname "${REPORT_FILE}")"
  andre_dir="${WORK_DIR}/wine-andre"
  rm -rf "${andre_dir}"

  log "Cloning ${ANDRE_WINE_REPO}"
  retry_cmd git clone --filter=blob:none --single-branch --branch "${ANDRE_ARM64EC_REF}" \
    "${ANDRE_WINE_REPO}" "${andre_dir}" || fail "Unable to clone ${ANDRE_WINE_REPO}"
  pushd "${andre_dir}" >/dev/null

  retry_cmd git fetch --force --no-tags origin \
    "${ANDRE_ARM64EC_REF}:refs/remotes/origin/${ANDRE_ARM64EC_REF}" \
    || fail "Unable to fetch ${ANDRE_ARM64EC_REF}"
  retry_cmd git fetch --force --no-tags origin \
    "${ANDRE_BASE_REF}:refs/remotes/origin/${ANDRE_BASE_REF}" \
    || fail "Unable to fetch ${ANDRE_BASE_REF}"
  if git remote get-url valve >/dev/null 2>&1; then
    git remote set-url valve "${VALVE_WINE_REPO}"
  else
    git remote add valve "${VALVE_WINE_REPO}"
  fi
  retry_cmd git fetch --force --no-tags valve "${VALVE_WINE_REF}:refs/tmp/valve-base" || fail "Unable to fetch Valve base ${VALVE_WINE_REF}"

  series_ref="refs/remotes/origin/${ANDRE_ARM64EC_REF}"
  base_ref="refs/remotes/origin/${ANDRE_BASE_REF}"
  valve_ref="refs/tmp/valve-base"
  range_ref="${valve_ref}..${series_ref}"
  merge_base="$(git merge-base "${series_ref}" "${base_ref}" || true)"
  [[ -n "${merge_base}" ]] || fail "Unable to compute merge-base between ${ANDRE_ARM64EC_REF} and ${ANDRE_BASE_REF}"
  valve_merge_base="$(git merge-base "${series_ref}" "${valve_ref}" || true)"
  [[ -n "${valve_merge_base}" ]] || fail "Unable to compute merge-base between ${ANDRE_ARM64EC_REF} and valve base ${VALVE_WINE_REF}"

  full_series_file="${OUT_DIR}/arm64ec-series.full.txt"
  subject_hits_file="${OUT_DIR}/arm64ec-series.subject.txt"
  path_hits_file="${OUT_DIR}/arm64ec-series.paths.txt"
  selected_set_file="${OUT_DIR}/arm64ec-series.selected.txt"

  # Build only the arm64ec delta that is not already in the selected Valve base.
  git rev-list --no-merges --reverse "${range_ref}" > "${full_series_file}"
  git rev-list --no-merges --reverse --regexp-ignore-case --grep="${ARM64EC_TOPIC_REGEX}" "${range_ref}" > "${subject_hits_file}" || true
  git rev-list --no-merges --reverse "${range_ref}" -- \
    "${ARM64EC_FILE_GLOB_1}" \
    "${ARM64EC_FILE_GLOB_2}" \
    "${ARM64EC_FILE_GLOB_3}" > "${path_hits_file}" || true

  cat "${subject_hits_file}" "${path_hits_file}" | sed '/^$/d' | sort -u > "${selected_set_file}"
  selected_filtered_file="${selected_set_file}.filtered"
  : > "${selected_filtered_file}"
  while IFS= read -r hash; do
    [[ -n "${hash}" ]] || continue
    subject="$(git show -s --format='%s' "${hash}")"
    if printf '%s\n' "${subject}" | grep -Eiq "${ARM64EC_EXCLUDE_SUBJECT_REGEX}"; then
      continue
    fi
    printf '%s\n' "${hash}" >> "${selected_filtered_file}"
  done < "${selected_set_file}"
  mv -f "${selected_filtered_file}" "${selected_set_file}"

  if [[ -s "${selected_set_file}" ]]; then
    awk 'NR==FNR { keep[$1]=1; next } keep[$1] { print $1 }' "${selected_set_file}" "${full_series_file}" > "${SERIES_FILE}"
  else
    cp -f "${full_series_file}" "${SERIES_FILE}"
  fi

  total_count="$(wc -l < "${full_series_file}" | tr -d '[:space:]')"
  filtered_count="$(wc -l < "${SERIES_FILE}" | tr -d '[:space:]')"
  if [[ "${ARM64EC_MAX_COMMITS}" -gt 0 && "${filtered_count}" -gt "${ARM64EC_MAX_COMMITS}" ]]; then
    # Optional hard cap for emergency tuning; disabled by default.
    # Keep oldest entries to preserve linear stack dependencies.
    head -n "${ARM64EC_MAX_COMMITS}" "${SERIES_FILE}" > "${SERIES_FILE}.tmp"
    mv "${SERIES_FILE}.tmp" "${SERIES_FILE}"
  fi

  commit_count="$(wc -l < "${SERIES_FILE}" | tr -d '[:space:]')"
  [[ "${commit_count}" != "0" ]] || fail "ARM64EC commit series is empty"

  today="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  {
    printf '# ARM64EC Patch Review\n\n'
    printf 'Generated at: `%s`\n\n' "${today}"
    printf -- '- Source repo: `%s`\n' "${ANDRE_WINE_REPO}"
    printf -- '- Source ref: `%s`\n' "${ANDRE_ARM64EC_REF}"
    printf -- '- Source base ref: `%s`\n' "${ANDRE_BASE_REF}"
    printf -- '- Valve base repo: `%s`\n' "${VALVE_WINE_REPO}"
    printf -- '- Valve base ref: `%s`\n' "${VALVE_WINE_REF}"
    printf -- '- Merge base (arm64ec vs source base): `%s`\n' "${merge_base}"
    printf -- '- Merge base (arm64ec vs valve base): `%s`\n' "${valve_merge_base}"
    printf -- '- Selection range: `%s`\n' "${range_ref}"
    printf -- '- Topic regex: `%s`\n' "${ARM64EC_TOPIC_REGEX}"
    printf -- '- File globs: `%s`, `%s`, `%s`\n' "${ARM64EC_FILE_GLOB_1}" "${ARM64EC_FILE_GLOB_2}" "${ARM64EC_FILE_GLOB_3}"
    printf -- '- Exclude subject regex: `%s`\n' "${ARM64EC_EXCLUDE_SUBJECT_REGEX}"
    printf -- '- Commits in full range: `%s`\n' "${total_count}"
    printf -- '- Commits after topic/path filtering: `%s`\n' "${filtered_count}"
    printf -- '- Max commits limit: `%s`\n' "${ARM64EC_MAX_COMMITS}"
    printf -- '- Commits in final series: `%s`\n\n' "${commit_count}"
    printf '## Per-commit reflective analysis\n'
  } > "${REPORT_FILE}"

  while IFS= read -r hash; do
    local subject author commit_date diffstat files touched_list risk category purpose effect
    local file_count has_loader has_ntdll has_wow64 has_dlls has_server has_tools

    subject="$(git show -s --format='%s' "${hash}")"
    author="$(git show -s --format='%an <%ae>' "${hash}")"
    commit_date="$(git show -s --format='%aI' "${hash}")"
    diffstat="$(git show --stat --format= "${hash}")"
    files="$(git show --name-only --pretty=format: "${hash}" | sed '/^$/d')"
    file_count="$(printf '%s\n' "${files}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"

    has_loader="$(printf '%s\n' "${files}" | grep -E '^loader/' || true)"
    has_ntdll="$(printf '%s\n' "${files}" | grep -E '^dlls/ntdll/' || true)"
    has_wow64="$(printf '%s\n' "${files}" | grep -E '(^dlls/wow64|/wow64|wow64)' || true)"
    has_dlls="$(printf '%s\n' "${files}" | grep -E '^dlls/' || true)"
    has_server="$(printf '%s\n' "${files}" | grep -E '^server/' || true)"
    has_tools="$(printf '%s\n' "${files}" | grep -E '^tools/' || true)"

    touched_list=""
    [[ -n "${has_loader}" ]] && touched_list="${touched_list} loader/"
    [[ -n "${has_ntdll}" ]] && touched_list="${touched_list} ntdll/"
    [[ -n "${has_wow64}" ]] && touched_list="${touched_list} wow64*/"
    [[ -n "${has_dlls}" ]] && touched_list="${touched_list} dlls/"
    [[ -n "${has_server}" ]] && touched_list="${touched_list} server/"
    [[ -n "${has_tools}" ]] && touched_list="${touched_list} tools/"
    [[ -n "${touched_list}" ]] || touched_list="general/"

    risk="LOW"
    if [[ -n "${has_ntdll}" || -n "${has_loader}" || -n "${has_server}" ]]; then
      risk="MED"
    fi
    if [[ "${file_count}" -gt 20 && ( -n "${has_ntdll}" || -n "${has_loader}" || -n "${has_server}" ) ]]; then
      risk="HIGH"
    fi

    category="MAY"
    if [[ -n "${has_ntdll}" || -n "${has_wow64}" || -n "${has_loader}" ]]; then
      category="MUST"
    elif [[ -n "${has_dlls}" || -n "${has_server}" || -n "${has_tools}" ]]; then
      category="SHOULD"
    fi
    if [[ "${risk}" == "HIGH" ]]; then
      category="RISKY"
    fi

    purpose="$(infer_purpose "${subject}" "${files}")"
    case "${category}" in
      MUST) effect="Критичен для ARM64EC/WoW64 цепочки; без него вероятна некорректная работа Winlator WCP." ;;
      SHOULD) effect="Улучшает стабильность/совместимость на ARM64EC, желателен для полноценного Proton профиля." ;;
      RISKY) effect="Даёт нужную функциональность, но повышает риск конфликтов и регрессий при переносе на Valve base." ;;
      *) effect="Вспомогательный вклад, ограниченный эффект на итоговый Winlator WCP." ;;
    esac

    {
      printf '\n### %s\n\n' "${subject}"
      printf -- '- Hash: `%s`\n' "${hash}"
      printf -- '- Author: `%s`\n' "${author}"
      printf -- '- Date: `%s`\n' "${commit_date}"
      printf -- '- Touched areas: `%s`\n' "${touched_list}"
      printf -- '- Зачем коммит: %s\n' "${purpose}"
      printf -- '- Риск/конфликтность: `%s`\n' "${risk}"
      printf -- '- Категория: `%s`\n' "${category}"
      printf -- '- Ожидаемый эффект: %s\n\n' "${effect}"
      printf '#### Diffstat\n\n```text\n%s\n```\n\n' "${diffstat}"
      printf '#### Files\n'
      printf '%s\n' "${files}" | sed 's#^#- `#;s#$#`#'
      printf '\n'
    } >> "${REPORT_FILE}"
  done < "${SERIES_FILE}"

  popd >/dev/null
  log "Commit review report generated: ${REPORT_FILE}"
  log "Commit list saved: ${SERIES_FILE}"
}

main "$@"
