#!/usr/bin/env bash
set -euo pipefail

log() { printf '[gh-log] %s\n' "$*"; }
fail() { printf '[gh-log][error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
usage: ci/validation/extract-gh-job-failures.sh <job-log-url-or-file>

Accepts:
  - GitHub Actions raw job log URL
  - Local job log file path

Prints:
  - first hard-failure markers
  - compiler/runtime error lines
  - last 120 lines for final context
EOF
}

[[ $# -ge 1 ]] || { usage; exit 1; }

src="$1"
tmp="$(mktemp /tmp/gh-job-log.XXXXXX.txt)"
cleanup() { rm -f "${tmp}"; }
trap cleanup EXIT

if [[ "${src}" =~ ^https?:// ]]; then
  command -v curl >/dev/null 2>&1 || fail "curl is required for URL mode"
  log "Downloading job log from URL"
  curl -fsSL "${src}" -o "${tmp}"
else
  [[ -f "${src}" ]] || fail "File not found: ${src}"
  cp -f "${src}" "${tmp}"
fi

log "Failure markers"
grep -nE '(^Error:|^\[.*error.*\]| make: \*\*\*|failed \(|The operation was canceled)' "${tmp}" | head -n 80 || true

log "Compiler/runtime error lines"
grep -nE '(^/home/runner/.*error:|^make: \*\*\*|^Error:|undefined reference|incompatible pointer types|undeclared function|contract validation failed|SDL2 runtime check failed)' "${tmp}" | head -n 120 || true

log "Tail context"
tail -n 120 "${tmp}"
