#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: ci/maintenance/parse-job-log.sh --job <job-id> [options]

Resolve a GitHub Actions job log URL and parse it via byte-range tail scan.

options:
  --job ID              Actions job id (required)
  --repo OWNER/REPO     GitHub repository (auto-detected by default)
  --tail-bytes N        Forwarded to parse-raw-job-log.sh (default: 600000)
  --pattern REGEX       Forwarded to parse-raw-job-log.sh
  --matches N           Forwarded to parse-raw-job-log.sh (default: 120)
  --tail-lines N        Forwarded to parse-raw-job-log.sh (default: 80)
  --print-url           Print resolved raw URL before parsing
EOF
}

JOB_ID=""
REPO=""
TAIL_BYTES=600000
MATCH_LIMIT=120
TAIL_LINES=80
PATTERN=""
PRINT_URL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --job)
      JOB_ID="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --tail-bytes)
      TAIL_BYTES="${2:-}"
      shift 2
      ;;
    --pattern)
      PATTERN="${2:-}"
      shift 2
      ;;
    --matches)
      MATCH_LIMIT="${2:-}"
      shift 2
      ;;
    --tail-lines)
      TAIL_LINES="${2:-}"
      shift 2
      ;;
    --print-url)
      PRINT_URL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

[[ -n "${JOB_ID}" ]] || { usage; exit 2; }
command -v gh >/dev/null 2>&1 || { echo "gh not found" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl not found" >&2; exit 1; }

detect_repo_from_git() {
  local remote
  remote="$(git config --get remote.origin.url 2>/dev/null || true)"
  if [[ "${remote}" =~ github\.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

if [[ -z "${REPO}" ]]; then
  REPO="$(detect_repo_from_git || true)"
fi
if [[ -z "${REPO}" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
[[ -n "${REPO}" ]] || { echo "Failed to detect repository; pass --repo OWNER/REPO" >&2; exit 1; }

TOKEN="$(gh auth token)"
[[ -n "${TOKEN}" ]] || { echo "gh auth token is empty" >&2; exit 1; }

JOB_LOG_ENDPOINT="https://api.github.com/repos/${REPO}/actions/jobs/${JOB_ID}/logs"
RAW_URL="$(
  curl -sSI \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "${JOB_LOG_ENDPOINT}" \
    | tr -d '\r' \
    | awk 'tolower($1)=="location:"{print $2}' \
    | tail -n1
)"

[[ -n "${RAW_URL}" ]] || {
  echo "Failed to resolve raw log URL for job ${JOB_ID} (${REPO})" >&2
  exit 1
}

echo "[job-log] repo=${REPO} job=${JOB_ID}"
if [[ "${PRINT_URL}" == "1" ]]; then
  echo "[job-log] raw_url=${RAW_URL}"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RAW_PARSER="${SCRIPT_DIR}/parse-raw-job-log.sh"
[[ -x "${RAW_PARSER}" ]] || { echo "Missing parser: ${RAW_PARSER}" >&2; exit 1; }

cmd=("${RAW_PARSER}" --url "${RAW_URL}" --tail-bytes "${TAIL_BYTES}" --matches "${MATCH_LIMIT}" --tail-lines "${TAIL_LINES}")
if [[ -n "${PATTERN}" ]]; then
  cmd+=(--pattern "${PATTERN}")
fi
"${cmd[@]}"
