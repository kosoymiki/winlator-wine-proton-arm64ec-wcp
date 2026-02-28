#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_DIR="${2:-${ROOT_DIR}/ci/winlator/patches}"
SRC_DIR="${1:-}"
TMP_DIR=""
: "${WINLATOR_PATCH_PLAN_FILE:=${ROOT_DIR}/ci/winlator/patch-batch-plan.tsv}"
: "${WINLATOR_PATCH_PHASE:=}"
: "${WINLATOR_PATCH_FROM:=}"
: "${WINLATOR_PATCH_TO:=}"
: "${WINLATOR_PATCH_SANITIZE:=1}"

log() { printf '[patch-stack-check] %s\n' "$*"; }
fail() { printf '[patch-stack-check][error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
usage: ci/winlator/check-patch-stack.sh <winlator-src-git-dir> [patch-dir]

Creates a temporary clean clone of <winlator-src-git-dir>, applies all patches
from [patch-dir] using ci/winlator/apply-repo-patches.sh, runs diff checks, and
prints a simple overlap report (files touched by multiple patches).

Optional env:
  WINLATOR_PATCH_PLAN_FILE=...  Phase plan file used by WINLATOR_PATCH_PHASE.
  WINLATOR_PATCH_PHASE=<name>   Named phase from patch-batch-plan.tsv.
  WINLATOR_PATCH_FROM=NNNN   First patch number in the apply window.
  WINLATOR_PATCH_TO=NNNN     Last patch number in the apply window.
  WINLATOR_PATCH_SANITIZE=1  Remove stray .rej/.orig hunks from patch files.
EOF
}

cleanup() {
  [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]] && rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

[[ -n "${SRC_DIR}" ]] || { usage; exit 1; }
[[ -d "${SRC_DIR}/.git" ]] || fail "Not a git checkout: ${SRC_DIR}"
[[ -d "${PATCH_DIR}" ]] || fail "Patch dir not found: ${PATCH_DIR}"
[[ -f "${WINLATOR_PATCH_PLAN_FILE}" ]] || fail "Plan file not found: ${WINLATOR_PATCH_PLAN_FILE}"
[[ -z "${WINLATOR_PATCH_FROM}" || "${WINLATOR_PATCH_FROM}" =~ ^[0-9]{4}$ ]] || fail "WINLATOR_PATCH_FROM must be empty or NNNN"
[[ -z "${WINLATOR_PATCH_TO}" || "${WINLATOR_PATCH_TO}" =~ ^[0-9]{4}$ ]] || fail "WINLATOR_PATCH_TO must be empty or NNNN"
[[ "${WINLATOR_PATCH_SANITIZE}" =~ ^[01]$ ]] || fail "WINLATOR_PATCH_SANITIZE must be 0 or 1"

SRC_DIR="$(cd -- "${SRC_DIR}" && pwd)"
PATCH_DIR="$(cd -- "${PATCH_DIR}" && pwd)"

phase_label=""
if [[ -n "${WINLATOR_PATCH_PHASE}" ]]; then
  [[ -z "${WINLATOR_PATCH_FROM}" && -z "${WINLATOR_PATCH_TO}" ]] || fail "WINLATOR_PATCH_PHASE cannot be combined with WINLATOR_PATCH_FROM/TO"
  declare -A phase_map=()
  while IFS='=' read -r key value; do
    phase_map["${key}"]="${value}"
  done < <(bash "${ROOT_DIR}/ci/winlator/resolve-patch-phase.sh" "${WINLATOR_PATCH_PHASE}" "${WINLATOR_PATCH_PLAN_FILE}")
  WINLATOR_PATCH_FROM="${phase_map[first]}"
  WINLATOR_PATCH_TO="${phase_map[last]}"
  phase_label="${phase_map[phase]}"
fi

command -v git >/dev/null 2>&1 || fail "git not found"
command -v awk >/dev/null 2>&1 || fail "awk not found"

log "Validating patch numbering contract"
bash "${ROOT_DIR}/ci/winlator/validate-patch-sequence.sh" "${PATCH_DIR}"
if [[ "${WINLATOR_PATCH_SANITIZE}" == "1" ]]; then
  log "Sanitizing patch stack before apply-check"
  bash "${ROOT_DIR}/ci/winlator/sanitize-patch-stack.sh" "${PATCH_DIR}"
fi

TMP_DIR="$(mktemp -d /tmp/winlator_patch_stack_check_XXXXXX)"
CLONE_DIR="${TMP_DIR}/src"

log "Creating clean local clone"
git clone -q --no-hardlinks -- "${SRC_DIR}" "${CLONE_DIR}"
git -C "${CLONE_DIR}" reset --hard -q HEAD
git -C "${CLONE_DIR}" clean -fdqx

if [[ -n "${phase_label}" ]]; then
  log "Applying phase ${phase_label} (${WINLATOR_PATCH_FROM}..${WINLATOR_PATCH_TO}) from $(basename -- "${PATCH_DIR}")"
elif [[ -n "${WINLATOR_PATCH_FROM}" || -n "${WINLATOR_PATCH_TO}" ]]; then
  log "Applying patch window ${WINLATOR_PATCH_FROM:-start}..${WINLATOR_PATCH_TO:-end} from $(basename -- "${PATCH_DIR}")"
else
  log "Applying patch stack from $(basename -- "${PATCH_DIR}")"
fi
WINLATOR_PATCH_FROM="${WINLATOR_PATCH_FROM}" \
WINLATOR_PATCH_TO="${WINLATOR_PATCH_TO}" \
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

if [[ -n "${WINLATOR_PATCH_FROM}" || -n "${WINLATOR_PATCH_TO}" ]]; then
  PATCH_COUNT="$(find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' -printf '%f\n' | sort | awk -v from="${WINLATOR_PATCH_FROM}" -v to="${WINLATOR_PATCH_TO}" '
    {
      if (match($0, /^([0-9][0-9][0-9][0-9])-/)) {
        num = substr($0, 1, 4) + 0
        if (from != "" && num < (from + 0)) next
        if (to != "" && num > (to + 0)) next
        count++
      }
    }
    END { print count + 0 }
  ')"
else
  PATCH_COUNT="$(find "${PATCH_DIR}" -maxdepth 1 -name '*.patch' | wc -l | tr -d ' ')"
fi
log "Patch stack apply-check passed (${PATCH_COUNT} patches)"
log "Temporary clone: ${CLONE_DIR} (auto-cleanup on exit)"
