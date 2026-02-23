#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WINLATOR_SRC_DIR="${1:-}"
PATCH_DIR="${2:-${ROOT_DIR}/ci/winlator/patches}"

log() { printf '[winlator-patch] %s\n' "$*"; }
fail() { printf '[winlator-patch][error] %s\n' "$*" >&2; exit 1; }

[[ -n "${WINLATOR_SRC_DIR}" ]] || fail "usage: $0 <winlator-src-dir> [patch-dir]"
[[ -d "${WINLATOR_SRC_DIR}/.git" ]] || fail "Not a git checkout: ${WINLATOR_SRC_DIR}"
[[ -d "${PATCH_DIR}" ]] || fail "Patch directory not found: ${PATCH_DIR}"

shopt -s nullglob
patches=("${PATCH_DIR}"/*.patch)
shopt -u nullglob

if [[ "${#patches[@]}" -eq 0 ]]; then
  log "No patches found in ${PATCH_DIR}; skipping"
  exit 0
fi

for patch in "${patches[@]}"; do
  log "Applying $(basename -- "${patch}")"
  git -C "${WINLATOR_SRC_DIR}" apply --3way --ignore-whitespace "${patch}" || fail "Failed to apply patch: ${patch}"
done

log "All patches applied"
