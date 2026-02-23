#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WINLATOR_SRC_DIR="${1:-}"
PATCH_DIR="${2:-${ROOT_DIR}/ci/winlator/patches}"

log()  { printf '[winlator-patch] %s\n' "$*"; }
fail() { printf '[winlator-patch][error] %s\n' "$*" >&2; exit 1; }

[[ -n "${WINLATOR_SRC_DIR}" ]] || fail "usage: $0 <winlator-src-dir> [patch-dir]"
[[ -d "${WINLATOR_SRC_DIR}/.git" ]] || fail "Not a git checkout: ${WINLATOR_SRC_DIR}"
[[ -d "${PATCH_DIR}" ]] || fail "Patch directory not found: ${PATCH_DIR}"

shopt -s nullglob
patches=("${PATCH_DIR}"/*.patch)
shopt -u nullglob

(( ${#patches[@]} )) || { log "No patches found in ${PATCH_DIR}; skipping"; exit 0; }

apply_one() {
  local patch="$1"
  local name; name="$(basename -- "$patch")"

  # If patch already applied, reverse-check succeeds -> skip
  if git -C "$WINLATOR_SRC_DIR" apply --reverse --check --recount "$patch" >/dev/null 2>&1; then
    log "Already applied: $name (skipping)"
    return 0
  fi

  # Try clean apply (3way + stage)
  if git -C "$WINLATOR_SRC_DIR" apply --index --3way --recount --whitespace=nowarn "$patch" >/dev/null 2>&1; then
    log "Applied: $name"
    return 0
  fi

  # Fallback: generate rejects (NO --3way with --reject)
  log "Conflicts, generating *.rej: $name"
  git -C "$WINLATOR_SRC_DIR" apply --recount --reject --whitespace=nowarn "$patch" || true

  fail "Failed to apply $name. Show *.rej:\n  find \"$WINLATOR_SRC_DIR\" -name '*.rej' -maxdepth 4 -print -exec sed -n '1,160p' {} \\;"
}

for patch in "${patches[@]}"; do
  log "Applying $(basename -- "$patch")"
  apply_one "$patch"
done

log "All patches applied"
