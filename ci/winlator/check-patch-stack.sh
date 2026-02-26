#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_DIR="${2:-${ROOT_DIR}/ci/winlator/patches}"
SRC_DIR="${1:-}"
TMP_DIR=""

log() { printf '[patch-stack-check] %s\n' "$*"; }
fail() { printf '[patch-stack-check][error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
usage: ci/winlator/check-patch-stack.sh <winlator-src-git-dir> [patch-dir]

Creates a temporary clean clone of <winlator-src-git-dir>, applies all patches
from [patch-dir] using ci/winlator/apply-repo-patches.sh, runs diff checks, and
prints a simple overlap report (files touched by multiple patches).
EOF
}

cleanup() {
  [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]] && rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

[[ -n "${SRC_DIR}" ]] || { usage; exit 1; }
[[ -d "${SRC_DIR}/.git" ]] || fail "Not a git checkout: ${SRC_DIR}"
[[ -d "${PATCH_DIR}" ]] || fail "Patch dir not found: ${PATCH_DIR}"

command -v git >/dev/null 2>&1 || fail "git not found"
command -v awk >/dev/null 2>&1 || fail "awk not found"

log "Validating patch numbering contract"
bash "${ROOT_DIR}/ci/winlator/validate-patch-sequence.sh" "${PATCH_DIR}"

TMP_DIR="$(mktemp -d /tmp/winlator_patch_stack_check_XXXXXX)"
CLONE_DIR="${TMP_DIR}/src"

log "Creating clean local clone"
git clone -q --no-hardlinks -- "${SRC_DIR}" "${CLONE_DIR}"
git -C "${CLONE_DIR}" reset --hard -q HEAD
git -C "${CLONE_DIR}" clean -fdqx

log "Applying patch stack from $(basename -- "${PATCH_DIR}")"
bash "${ROOT_DIR}/ci/winlator/apply-repo-patches.sh" "${CLONE_DIR}" "${PATCH_DIR}"

log "Running diff integrity checks"
git -C "${CLONE_DIR}" diff --check
if ! git -C "${CLONE_DIR}" diff --cached --check > "${TMP_DIR}/cached-diff-check.txt" 2>&1; then
  log "Cached diff check reported warnings (often CRLF-style lines in upstream XML):"
  sed -n '1,80p' "${TMP_DIR}/cached-diff-check.txt"
fi

log "Building overlap report (files touched by multiple patches)"
awk '
  FNR == 1 { patch = FILENAME; gsub(/^.*\//, "", patch) }
  /^\+\+\+ b\// {
    file = substr($0, 7)
    if (file == "/dev/null") next
    key = file
    if (!(seen[patch SUBSEP key]++)) {
      counts[key]++
      if (patch_list[key] == "") patch_list[key] = patch
      else patch_list[key] = patch_list[key] ", " patch
    }
  }
  END {
    overlap = 0
    for (k in counts) {
      if (counts[k] > 1) {
        overlap++
        printf("  %s (%d): %s\n", k, counts[k], patch_list[k])
      }
    }
    if (!overlap) print "  (no overlaps)"
  }
' "${PATCH_DIR}"/*.patch | sort > "${TMP_DIR}/overlap.txt"
cat "${TMP_DIR}/overlap.txt"

PATCH_COUNT="$(find "${PATCH_DIR}" -maxdepth 1 -name '*.patch' | wc -l | tr -d ' ')"
log "Patch stack apply-check passed (${PATCH_COUNT} patches)"
log "Temporary clone: ${CLONE_DIR} (auto-cleanup on exit)"
