#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { printf '[forensic-local] %s\n' "$*"; }
fail() { printf '[forensic-local][error] %s\n' "$*" >&2; exit 1; }

run_name_policy_matrix() {
  python3 - <<'PY'
import re
import sys

pattern = re.compile(r"^xuser-([1-9][0-9]*)$")
cases = [
    ("xuser-1", True),
    ("xuser-2.pre_norm_bad", False),
    ("backup_xuser2.pre_norm_bad", False),
    ("xuser-", False),
    ("xuser-a", False),
    ("xuser-01a", False),
    ("xuser-01", False),
]
bad = []
for name, expected in cases:
    got = bool(pattern.match(name))
    if got != expected:
        bad.append((name, expected, got))

if bad:
    for name, exp, got in bad:
        print(f"FAIL {name}: expected {exp}, got {got}", file=sys.stderr)
    sys.exit(1)

print("Name policy matrix passed.")
PY
}

check_wcp_forensics_archive() {
  local wcp_path="$1"
  local list_file
  [[ -f "${wcp_path}" ]] || fail "WCP not found: ${wcp_path}"
  list_file="$(mktemp)"
  trap 'rm -f "${list_file:-}"' RETURN

  if tar -tJf "${wcp_path}" > "${list_file}" 2>/dev/null; then
    :
  elif tar --zstd -tf "${wcp_path}" > "${list_file}" 2>/dev/null; then
    :
  else
    fail "Unable to list WCP archive: ${wcp_path}"
  fi

  sed -i 's#^\./##' "${list_file}"
  for rel in \
    share/wcp-forensics/manifest.json \
    share/wcp-forensics/critical-sha256.tsv \
    share/wcp-forensics/file-index.txt \
    share/wcp-forensics/build-env.txt \
    share/wcp-forensics/source-refs.json; do
    grep -qx "${rel}" "${list_file}" || fail "Missing forensic artifact in ${wcp_path}: ${rel}"
  done
  log "Forensic manifest present in $(basename "${wcp_path}")"
}

main() {
  log "Running local forensic regression checks"
  run_name_policy_matrix

  if [[ "$#" -gt 0 ]]; then
    local wcp
    for wcp in "$@"; do
      check_wcp_forensics_archive "${wcp}"
    done
  fi

  log "All local forensic checks passed"
}

main "$@"
