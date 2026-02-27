#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
MAP_FILE="${WCP_BIONIC_SOURCE_MAP_FILE:-${ROOT_DIR}/ci/runtime-sources/bionic-source-map.json}"
PKG_NAME="${1:-${WCP_NAME:-}}"
CHECK_REMOTE="${CHECK_REMOTE:-1}"

log() { printf '[donor-resolve] %s\n' "$*"; }
fail() { printf '[donor-resolve][error] %s\n' "$*" >&2; exit 1; }

[[ -n "${PKG_NAME}" ]] || fail "Package name is required (arg1 or WCP_NAME)"
[[ -f "${MAP_FILE}" ]] || fail "Source map not found: ${MAP_FILE}"

command -v python3 >/dev/null 2>&1 || fail "python3 is required"

resolved="$(python3 - "${MAP_FILE}" "${PKG_NAME}" <<'PY'
import json
import re
import sys
from pathlib import Path

map_file = Path(sys.argv[1])
pkg = sys.argv[2]
data = json.loads(map_file.read_text(encoding='utf-8'))
entry = (data.get('packages') or {}).get(pkg)
if not isinstance(entry, dict):
    print('ERROR=missing-package')
    raise SystemExit(0)

sha_re = re.compile(r'^[0-9a-f]{64}$')

def norm_sha(v):
    if v is None:
        return ''
    s = str(v).strip().lower()
    return s

launcher_url = str(entry.get('launcherSourceWcpUrl') or '').strip()
unix_url = str(entry.get('unixSourceWcpUrl') or '').strip()
launcher_sha = norm_sha(entry.get('launcherSourceSha256'))
unix_sha = norm_sha(entry.get('unixSourceSha256'))
launcher_alt = [norm_sha(x) for x in (entry.get('launcherSourceSha256Alternates') or []) if str(x).strip()]
unix_alt = [norm_sha(x) for x in (entry.get('unixSourceSha256Alternates') or []) if str(x).strip()]

for k, s in [('launcherSourceSha256', launcher_sha), ('unixSourceSha256', unix_sha)]:
    if s and not sha_re.fullmatch(s):
        print(f'ERROR=invalid-{k}')
        raise SystemExit(0)
for k, arr in [('launcherSourceSha256Alternates', launcher_alt), ('unixSourceSha256Alternates', unix_alt)]:
    for idx, s in enumerate(arr):
        if not sha_re.fullmatch(s):
            print(f'ERROR=invalid-{k}-{idx}')
            raise SystemExit(0)

if launcher_url and not (launcher_sha or launcher_alt):
    print('ERROR=launcher-sha-missing')
    raise SystemExit(0)
if unix_url and not (unix_sha or unix_alt):
    print('ERROR=unix-sha-missing')
    raise SystemExit(0)

print(f'WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL={launcher_url}')
print(f'WCP_BIONIC_UNIX_SOURCE_WCP_URL={unix_url}')
print(f'WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256={launcher_sha}')
print(f'WCP_BIONIC_UNIX_SOURCE_WCP_SHA256={unix_sha}')
print('WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256_ALTERNATES=' + ' '.join(launcher_alt))
print('WCP_BIONIC_UNIX_SOURCE_WCP_SHA256_ALTERNATES=' + ' '.join(unix_alt))
PY
)"

while IFS= read -r line; do
  [[ -n "${line}" ]] || continue
  key="${line%%=*}"
  value="${line#*=}"
  if [[ "${key}" == "ERROR" ]]; then
    fail "Failed to resolve package '${PKG_NAME}' from ${MAP_FILE}: ${value}"
  fi
  printf -v "${key}" '%s' "${value}"
  export "${key}"
done <<< "${resolved}"

if [[ "${CHECK_REMOTE}" == "1" ]]; then
  command -v curl >/dev/null 2>&1 || fail "curl is required for remote check"
  if [[ -n "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:-}" ]]; then
    curl -fsSIL --connect-timeout 15 --max-time 60 "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL}" >/dev/null || \
      fail "Launcher donor URL is unreachable: ${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL}"
  fi
  if [[ -n "${WCP_BIONIC_UNIX_SOURCE_WCP_URL:-}" ]]; then
    curl -fsSIL --connect-timeout 15 --max-time 60 "${WCP_BIONIC_UNIX_SOURCE_WCP_URL}" >/dev/null || \
      fail "Unix donor URL is unreachable: ${WCP_BIONIC_UNIX_SOURCE_WCP_URL}"
  fi
fi

log "resolved package=${PKG_NAME} map=$(basename "${MAP_FILE}")"
log "launcher_url=${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:-<unset>}"
log "unix_url=${WCP_BIONIC_UNIX_SOURCE_WCP_URL:-<unset>}"
