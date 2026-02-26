#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_SNAPSHOT_DIR:=/tmp/mainline-forensic-snapshot-$(date +%Y%m%d_%H%M%S)}"
: "${WLT_BRANCH:=main}"
: "${WLT_SINCE_HOURS:=24}"
: "${WLT_FAILURE_LIMIT:=20}"
: "${WLT_TRIAGE_ACTIVE_RUNS:=0}"
: "${WLT_TRIAGE_MAX_RUNS:=3}"
: "${WLT_TRIAGE_MAX_JOBS:=3}"

log() { printf '[mainline-snapshot] %s\n' "$*"; }
fail() { printf '[mainline-snapshot][error] %s\n' "$*" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || fail "gh is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
[[ "${WLT_TRIAGE_ACTIVE_RUNS}" =~ ^[01]$ ]] || fail "WLT_TRIAGE_ACTIVE_RUNS must be 0 or 1"
[[ "${WLT_TRIAGE_MAX_RUNS}" =~ ^[0-9]+$ ]] || fail "WLT_TRIAGE_MAX_RUNS must be numeric"
[[ "${WLT_TRIAGE_MAX_JOBS}" =~ ^[0-9]+$ ]] || fail "WLT_TRIAGE_MAX_JOBS must be numeric"

mkdir -p "${WLT_SNAPSHOT_DIR}"

run_capture() {
  local name="$1"; shift
  local out="${WLT_SNAPSHOT_DIR}/${name}.log"
  if "$@" >"${out}" 2>&1; then
    printf '0\n'
  else
    rc=$?
    printf '%s\n' "${rc}"
  fi
}

printf 'time_utc=%s\nbranch=%s\nsince_hours=%s\nfailure_limit=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${WLT_BRANCH}" "${WLT_SINCE_HOURS}" "${WLT_FAILURE_LIMIT}" \
  > "${WLT_SNAPSHOT_DIR}/snapshot.meta"
git -C "${ROOT_DIR}" rev-parse HEAD > "${WLT_SNAPSHOT_DIR}/git-head.txt"
git -C "${ROOT_DIR}" status --short > "${WLT_SNAPSHOT_DIR}/git-status.txt"
git -C "${ROOT_DIR}" rev-list --count origin/main..main > "${WLT_SNAPSHOT_DIR}/ahead-count.txt" 2>/dev/null || true

health_rc="$(run_capture "health" env WLT_HEALTH_OUTPUT_PREFIX="${WLT_SNAPSHOT_DIR}/mainline-health" \
  bash "${ROOT_DIR}/ci/validation/gh-mainline-health.sh" "${WLT_BRANCH}" "${WLT_SINCE_HOURS}")"
failures_rc="$(run_capture "active-failures" env WLT_FAILURES_OUTPUT_PREFIX="${WLT_SNAPSHOT_DIR}/active-failures" \
  bash "${ROOT_DIR}/ci/validation/gh-latest-failures.sh" "${WLT_FAILURE_LIMIT}" "${WLT_BRANCH}" "${WLT_SINCE_HOURS}")"
urc_rc="$(run_capture "urc-check" bash "${ROOT_DIR}/ci/validation/check-urc-mainline-policy.sh")"
triage_rc=0

if [[ "${WLT_TRIAGE_ACTIVE_RUNS}" == "1" && "${failures_rc}" == "0" ]]; then
  active_tsv="${WLT_SNAPSHOT_DIR}/active-failures.tsv"
  if [[ -f "${active_tsv}" ]]; then
    mapfile -t active_run_ids < <(tail -n +2 "${active_tsv}" | cut -f1 | sed '/^$/d' | head -n "${WLT_TRIAGE_MAX_RUNS}")
    if [[ "${#active_run_ids[@]}" -gt 0 ]]; then
      triage_dir="${WLT_SNAPSHOT_DIR}/run-triage"
      mkdir -p "${triage_dir}"
      for run_id in "${active_run_ids[@]}"; do
        log "triage run ${run_id}"
        if ! WLT_RUN_TRIAGE_DIR="${triage_dir}/run-${run_id}" \
          bash "${ROOT_DIR}/ci/validation/gh-run-root-cause.sh" "${run_id}" "${WLT_TRIAGE_MAX_JOBS}" \
          > "${triage_dir}/run-${run_id}.log" 2>&1; then
          triage_rc=1
        fi
      done
    fi
  fi
fi

{
  printf 'health_rc=%s\n' "${health_rc}"
  printf 'active_failures_rc=%s\n' "${failures_rc}"
  printf 'urc_rc=%s\n' "${urc_rc}"
  printf 'triage_rc=%s\n' "${triage_rc}"
} > "${WLT_SNAPSHOT_DIR}/status.meta"

if [[ "${health_rc}" != "0" || "${failures_rc}" != "0" || "${urc_rc}" != "0" || "${triage_rc}" != "0" ]]; then
  log "snapshot captured with failures: ${WLT_SNAPSHOT_DIR}"
  fail "one or more checks failed (health=${health_rc}, active_failures=${failures_rc}, urc=${urc_rc}, triage=${triage_rc})"
fi

log "snapshot captured: ${WLT_SNAPSHOT_DIR}"
