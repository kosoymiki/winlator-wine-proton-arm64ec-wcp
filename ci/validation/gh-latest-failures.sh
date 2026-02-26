#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { printf '[gh-failures] %s\n' "$*"; }
fail() { printf '[gh-failures][error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
usage: ci/validation/gh-latest-failures.sh [limit]

Collects latest failed GitHub Actions runs in this repository and prints
focused failure snippets using extract-gh-job-failures.sh.

Examples:
  bash ci/validation/gh-latest-failures.sh
  bash ci/validation/gh-latest-failures.sh 5
EOF
}

limit="${1:-3}"
[[ "${limit}" =~ ^[0-9]+$ ]] || { usage; fail "limit must be numeric"; }

command -v gh >/dev/null 2>&1 || fail "gh is required"
[[ -x "${ROOT_DIR}/ci/validation/extract-gh-job-failures.sh" ]] || \
  fail "Missing executable parser: ci/validation/extract-gh-job-failures.sh"

runs="$(
  gh run list --limit "${limit}" --status failure \
    --json databaseId,workflowName,conclusion,createdAt,url,displayTitle \
    --jq '.[] | [.databaseId,.workflowName,.createdAt,.url,.displayTitle] | @tsv'
)"

if [[ -z "${runs}" ]]; then
  log "No failed runs in latest ${limit} entries."
  exit 0
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
done <<< "${runs}"
