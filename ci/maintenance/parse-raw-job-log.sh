#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: ci/maintenance/parse-raw-job-log.sh --url <raw-job-log-url> [options]

Parses GitHub Actions raw job logs via HTTP byte ranges (without downloading full log).

options:
  --url URL             Raw Azure log URL (required)
  --tail-bytes N        Bytes to fetch from log tail (default: 600000)
  --pattern REGEX       Regex for important lines (default: common build failures)
  --matches N           Max matching lines to print (default: 120)
  --tail-lines N        Tail lines to print if no matches (default: 80)
EOF
}

RAW_URL=""
TAIL_BYTES=600000
MATCH_LIMIT=120
TAIL_LINES=80
PATTERN='error:|fatal:|FAILED|Process completed with exit code|##\[error\]|Traceback|No space left|out of memory|killed'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      RAW_URL="${2:-}"
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

[[ -n "${RAW_URL}" ]] || { usage; exit 2; }
command -v curl >/dev/null 2>&1 || { echo "curl not found" >&2; exit 1; }

TMP_FILE="$(mktemp /tmp/raw-job-log-tail.XXXXXX)"
trap 'rm -f "${TMP_FILE}"' EXIT

CONTENT_LENGTH="$(
  curl -sSI "${RAW_URL}" \
    | tr -d '\r' \
    | awk 'tolower($1)=="content-length:"{print $2}' \
    | tail -n1
)"

if [[ -z "${CONTENT_LENGTH}" || ! "${CONTENT_LENGTH}" =~ ^[0-9]+$ ]]; then
  echo "Failed to read Content-Length from raw log URL" >&2
  exit 1
fi

if (( CONTENT_LENGTH == 0 )); then
  echo "Remote log is empty (Content-Length=0)"
  exit 0
fi

if (( TAIL_BYTES < 1 )); then
  echo "--tail-bytes must be > 0" >&2
  exit 2
fi

START=$(( CONTENT_LENGTH - TAIL_BYTES ))
if (( START < 0 )); then
  START=0
fi
END=$(( CONTENT_LENGTH - 1 ))

curl -sS --fail \
  -H "Range: bytes=${START}-${END}" \
  "${RAW_URL}" \
  > "${TMP_FILE}"

FETCHED_BYTES="$(wc -c < "${TMP_FILE}")"
echo "[raw-log] total_bytes=${CONTENT_LENGTH} fetched_bytes=${FETCHED_BYTES} range=${START}-${END}"

if command -v rg >/dev/null 2>&1; then
  MATCHES="$(rg -n -i -e "${PATTERN}" "${TMP_FILE}" || true)"
else
  MATCHES="$(grep -nEi "${PATTERN}" "${TMP_FILE}" || true)"
fi

if [[ -n "${MATCHES}" ]]; then
  echo "[raw-log] matched lines (tail ${MATCH_LIMIT}):"
  printf '%s\n' "${MATCHES}" | tail -n "${MATCH_LIMIT}"
else
  echo "[raw-log] no matches for pattern; tail ${TAIL_LINES}:"
  tail -n "${TAIL_LINES}" "${TMP_FILE}"
fi
