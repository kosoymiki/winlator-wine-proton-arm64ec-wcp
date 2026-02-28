#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_DIR="${1:-${ROOT_DIR}/ci/winlator/patches}"
: "${WINLATOR_PATCH_SANITIZE_DRY_RUN:=0}"

log() { printf '[patch-sanitize] %s\n' "$*"; }
fail() { printf '[patch-sanitize][error] %s\n' "$*" >&2; exit 1; }

[[ -d "${PATCH_DIR}" ]] || fail "Patch dir not found: ${PATCH_DIR}"
[[ "${WINLATOR_PATCH_SANITIZE_DRY_RUN}" =~ ^[01]$ ]] || fail "WINLATOR_PATCH_SANITIZE_DRY_RUN must be 0 or 1"

PATCH_DIR="$(cd -- "${PATCH_DIR}" && pwd)"

tmp_json="$(mktemp /tmp/winlator_patch_sanitize.XXXXXX.json)"
trap 'rm -f "${tmp_json}"' EXIT

python3 - "${PATCH_DIR}" "${WINLATOR_PATCH_SANITIZE_DRY_RUN}" "${tmp_json}" <<'PY'
import json
import re
import sys
from pathlib import Path

patch_dir = Path(sys.argv[1])
dry_run = sys.argv[2] == "1"
out_json = Path(sys.argv[3])

def sanitize_patch(text: str):
    parts = text.split("diff --git ")
    kept = [parts[0]]
    removed = 0
    for part in parts[1:]:
        block = "diff --git " + part
        lines = part.splitlines()
        header = lines[0] if lines else ""
        if re.search(r"\.rej(\s|$)|\.orig(\s|$)", header):
            removed += 1
            continue
        kept.append(block)
    return "".join(kept), removed

changed_files = []
removed_total = 0
for patch in sorted(patch_dir.glob("*.patch")):
    original = patch.read_text(encoding="utf-8")
    sanitized, removed = sanitize_patch(original)
    if removed > 0:
        removed_total += removed
        changed_files.append({"file": str(patch), "removed_blocks": removed})
        if not dry_run:
            patch.write_text(sanitized, encoding="utf-8")

payload = {
    "dry_run": dry_run,
    "changed_files": changed_files,
    "removed_blocks_total": removed_total,
}
out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

removed_total="$(python3 - "${tmp_json}" <<'PY'
import json,sys
obj=json.load(open(sys.argv[1],encoding='utf-8'))
print(obj.get("removed_blocks_total",0))
PY
)"

if [[ "${removed_total}" == "0" ]]; then
  log "no stray .rej/.orig patch hunks found"
else
  if [[ "${WINLATOR_PATCH_SANITIZE_DRY_RUN}" == "1" ]]; then
    log "dry-run: found ${removed_total} stray hunk(s) with .rej/.orig paths"
  else
    log "removed ${removed_total} stray hunk(s) with .rej/.orig paths"
  fi
fi

python3 - "${tmp_json}" <<'PY'
import json,sys
obj=json.load(open(sys.argv[1],encoding='utf-8'))
for row in obj.get("changed_files",[]):
    print(f"[patch-sanitize] {row['file']}: removed_blocks={row['removed_blocks']}")
PY
