#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { printf '[gh-failures] %s\n' "$*"; }
fail() { printf '[gh-failures][error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
usage: ci/validation/gh-latest-failures.sh [limit] [branch] [since_hours]

Collects active failed GitHub Actions workflows (latest run per workflow)
in this repository and prints focused failure snippets using
extract-gh-job-failures.sh.

Examples:
  bash ci/validation/gh-latest-failures.sh
  bash ci/validation/gh-latest-failures.sh 5
  bash ci/validation/gh-latest-failures.sh 5 main
  bash ci/validation/gh-latest-failures.sh 20 main 24

Env:
  WLT_FAILURES_OUTPUT_PREFIX=/tmp/gh-active-failures  # optional .tsv/.meta outputs
  WLT_AUTO_TRIAGE_FAILED_RUNS=0  # when 1, run gh-run-root-cause.sh per active failed run
  WLT_AUTO_TRIAGE_MAX_RUNS=3
  WLT_AUTO_TRIAGE_MAX_JOBS=3
  WLT_AUTO_TRIAGE_DIR=/tmp/gh-active-run-triage-<ts>
EOF
}

limit="${1:-3}"
[[ "${limit}" =~ ^[0-9]+$ ]] || { usage; fail "limit must be numeric"; }
branch="${2:-main}"
[[ -n "${branch}" ]] || { usage; fail "branch must be non-empty"; }
since_hours="${3:-24}"
[[ "${since_hours}" =~ ^[0-9]+$ ]] || { usage; fail "since_hours must be numeric"; }
: "${WLT_FAILURES_OUTPUT_PREFIX:=}"
: "${WLT_AUTO_TRIAGE_FAILED_RUNS:=0}"
: "${WLT_AUTO_TRIAGE_MAX_RUNS:=3}"
: "${WLT_AUTO_TRIAGE_MAX_JOBS:=3}"
: "${WLT_AUTO_TRIAGE_DIR:=}"
[[ "${WLT_AUTO_TRIAGE_FAILED_RUNS}" =~ ^[01]$ ]] || fail "WLT_AUTO_TRIAGE_FAILED_RUNS must be 0 or 1"
[[ "${WLT_AUTO_TRIAGE_MAX_RUNS}" =~ ^[0-9]+$ ]] || fail "WLT_AUTO_TRIAGE_MAX_RUNS must be numeric"
[[ "${WLT_AUTO_TRIAGE_MAX_JOBS}" =~ ^[0-9]+$ ]] || fail "WLT_AUTO_TRIAGE_MAX_JOBS must be numeric"

command -v gh >/dev/null 2>&1 || fail "gh is required"
[[ -x "${ROOT_DIR}/ci/validation/extract-gh-job-failures.sh" ]] || \
  fail "Missing executable parser: ci/validation/extract-gh-job-failures.sh"
if [[ "${WLT_AUTO_TRIAGE_FAILED_RUNS}" == "1" ]]; then
  [[ -x "${ROOT_DIR}/ci/validation/gh-run-root-cause.sh" ]] || \
    fail "Missing executable triage helper: ci/validation/gh-run-root-cause.sh"
fi
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

since_epoch="$(
  python3 - "${since_hours}" <<'PY'
import sys
import time

hours = int(sys.argv[1])
print(int(time.time()) - (hours * 3600))
PY
)"

scan_limit=$(( limit * 30 ))
(( scan_limit < 100 )) && scan_limit=100

runs_json="$(
  gh run list --limit "${scan_limit}" --branch "${branch}" \
    --json databaseId,workflowName,status,conclusion,createdAt,url,displayTitle
)"

runs_json_file="$(mktemp /tmp/gh-active-runs.XXXXXX.json)"
cleanup_tmp() { rm -f "${runs_json_file}"; }
trap cleanup_tmp EXIT
printf '%s\n' "${runs_json}" > "${runs_json_file}"

runs="$(
  python3 - "${limit}" "${since_epoch}" "${runs_json_file}" <<'PY'
import json
import sys

limit = int(sys.argv[1])
since_epoch = int(sys.argv[2])
input_json = sys.argv[3]
with open(input_json, "r", encoding="utf-8") as fh:
    data = json.load(fh)

def to_epoch(ts: str) -> int:
    # createdAt is RFC3339 Z
    # YYYY-MM-DDTHH:MM:SSZ -> epoch
    from datetime import datetime, timezone
    return int(datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp())

latest_by_workflow = {}
for row in data:
    workflow = row.get("workflowName") or ""
    if not workflow:
        continue
    created = row.get("createdAt") or ""
    if not created:
        continue
    prev = latest_by_workflow.get(workflow)
    if prev is None or created > prev.get("createdAt", ""):
        latest_by_workflow[workflow] = row

bad = []
for row in latest_by_workflow.values():
    created = row.get("createdAt") or ""
    if not created:
        continue
    if to_epoch(created) < since_epoch:
        continue
    conclusion = (row.get("conclusion") or "").lower()
    if conclusion not in {"failure", "cancelled", "timed_out"}:
        continue
    bad.append(row)

bad.sort(key=lambda r: r.get("createdAt", ""), reverse=True)
for row in bad[:limit]:
    values = [
        str(row.get("databaseId", "")),
        row.get("workflowName", ""),
        row.get("createdAt", ""),
        row.get("url", ""),
        row.get("displayTitle", ""),
    ]
    print("\t".join(values))
PY
)"
rm -f "${runs_json_file}"
trap - EXIT

if [[ -z "${runs}" ]]; then
  log "No active failed workflows for branch=${branch} within ${since_hours}h."
  if [[ -n "${WLT_FAILURES_OUTPUT_PREFIX}" ]]; then
    mkdir -p "$(dirname -- "${WLT_FAILURES_OUTPUT_PREFIX}")"
    printf 'run_id\tworkflow\tcreated_at\turl\ttitle\n' > "${WLT_FAILURES_OUTPUT_PREFIX}.tsv"
    {
      printf 'branch=%s\n' "${branch}"
      printf 'since_hours=%s\n' "${since_hours}"
      printf 'count=0\n'
      printf 'auto_triage=%s\n' "${WLT_AUTO_TRIAGE_FAILED_RUNS}"
    } > "${WLT_FAILURES_OUTPUT_PREFIX}.meta"
    log "wrote ${WLT_FAILURES_OUTPUT_PREFIX}.tsv"
    log "wrote ${WLT_FAILURES_OUTPUT_PREFIX}.meta"
  fi
  exit 0
fi

if [[ -n "${WLT_FAILURES_OUTPUT_PREFIX}" ]]; then
  mkdir -p "$(dirname -- "${WLT_FAILURES_OUTPUT_PREFIX}")"
  {
    printf 'run_id\tworkflow\tcreated_at\turl\ttitle\n'
    printf '%s\n' "${runs}"
  } > "${WLT_FAILURES_OUTPUT_PREFIX}.tsv"
  {
    printf 'branch=%s\n' "${branch}"
    printf 'since_hours=%s\n' "${since_hours}"
    printf 'count=%s\n' "$(printf '%s\n' "${runs}" | wc -l | tr -d ' ')"
    printf 'auto_triage=%s\n' "${WLT_AUTO_TRIAGE_FAILED_RUNS}"
  } > "${WLT_FAILURES_OUTPUT_PREFIX}.meta"
  log "wrote ${WLT_FAILURES_OUTPUT_PREFIX}.tsv"
  log "wrote ${WLT_FAILURES_OUTPUT_PREFIX}.meta"
fi

triage_count=0
triage_base=""
triage_failures=0
if [[ "${WLT_AUTO_TRIAGE_FAILED_RUNS}" == "1" ]]; then
  triage_base="${WLT_AUTO_TRIAGE_DIR:-/tmp/gh-active-run-triage-$(date +%Y%m%d_%H%M%S)}"
  mkdir -p "${triage_base}"
  log "auto-triage enabled: base=${triage_base} max_runs=${WLT_AUTO_TRIAGE_MAX_RUNS} max_jobs=${WLT_AUTO_TRIAGE_MAX_JOBS}"
fi

while IFS=$'\t' read -r run_id workflow created_at run_url title; do
  [[ -n "${run_id}" ]] || continue
  log "Run ${run_id} | ${workflow} | ${created_at}"
  log "Title: ${title}"
  log "URL: ${run_url}"

  job_id="$(
    gh run view "${run_id}" --json jobs \
      --jq '.jobs[] | select(.conclusion=="failure" or .conclusion=="cancelled" or .conclusion=="timed_out") | .databaseId' \
      | head -n 1 || true
  )"

  if [[ -z "${job_id}" ]]; then
    log "No failed job details found for run ${run_id}"
    continue
  fi

  tmp_log="$(mktemp /tmp/gh-run-${run_id}-job-${job_id}.XXXXXX.log)"
  gh run view "${run_id}" --job "${job_id}" --log > "${tmp_log}" || {
    rm -f "${tmp_log}"
    fail "Unable to fetch log for run ${run_id} job ${job_id}"
  }
  bash "${ROOT_DIR}/ci/validation/extract-gh-job-failures.sh" "${tmp_log}"
  rm -f "${tmp_log}"

  if [[ "${WLT_AUTO_TRIAGE_FAILED_RUNS}" == "1" ]]; then
    if (( triage_count < WLT_AUTO_TRIAGE_MAX_RUNS )); then
      triage_count=$((triage_count + 1))
      triage_dir="${triage_base}/run-${run_id}"
      triage_log="${triage_base}/run-${run_id}.log"
      log "Auto-triage run ${run_id} -> ${triage_dir}"
      if ! WLT_RUN_TRIAGE_DIR="${triage_dir}" \
        bash "${ROOT_DIR}/ci/validation/gh-run-root-cause.sh" "${run_id}" "${WLT_AUTO_TRIAGE_MAX_JOBS}" \
        > "${triage_log}" 2>&1; then
        triage_failures=$((triage_failures + 1))
        log "Auto-triage failed for run ${run_id}; see ${triage_log}"
      fi
    fi
  fi
done <<< "${runs}"

if [[ "${WLT_AUTO_TRIAGE_FAILED_RUNS}" == "1" ]]; then
  log "Auto-triage summary: attempts=${triage_count} failures=${triage_failures} base=${triage_base}"
fi
