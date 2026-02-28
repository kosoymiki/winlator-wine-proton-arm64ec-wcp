#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_DIR="${1:-}"
PATCH_DIR="${2:-${ROOT_DIR}/ci/winlator/patches}"
MAINLINE_PATCH="${PATCH_DIR}/0001-mainline-full-stack-consolidated.patch"
: "${WINLATOR_FOLD_DROP_SLICES:=1}"

log() { printf '[patch-fold] %s\n' "$*"; }
fail() { printf '[patch-fold][error] %s\n' "$*" >&2; exit 1; }

[[ -n "${SRC_DIR}" ]] || fail "usage: $0 <winlator-src-git-dir> [patch-dir]"
[[ -d "${SRC_DIR}/.git" ]] || fail "Not a git checkout: ${SRC_DIR}"
[[ -d "${PATCH_DIR}" ]] || fail "Patch dir not found: ${PATCH_DIR}"
[[ -f "${MAINLINE_PATCH}" ]] || fail "Mainline patch missing: ${MAINLINE_PATCH}"
[[ "${WINLATOR_FOLD_DROP_SLICES}" =~ ^[01]$ ]] || fail "WINLATOR_FOLD_DROP_SLICES must be 0 or 1"

mapfile -t patch_files < <(find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' -printf '%f\n' | sort)
(( ${#patch_files[@]} > 0 )) || fail "No patch files in ${PATCH_DIR}"

extra_count=0
for p in "${patch_files[@]}"; do
  [[ "${p}" == "0001-mainline-full-stack-consolidated.patch" ]] || extra_count=$((extra_count + 1))
done

if (( extra_count == 0 )); then
  log "No slice patches to fold; patch base already consolidated"
  exit 0
fi

TMP_DIR="$(mktemp -d /tmp/winlator_patch_fold_XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT
CLONE_DIR="${TMP_DIR}/src"
NEW_PATCH="${TMP_DIR}/0001-mainline-full-stack-consolidated.patch"

git clone -q --no-hardlinks -- "${SRC_DIR}" "${CLONE_DIR}"
git -C "${CLONE_DIR}" reset --hard -q HEAD
git -C "${CLONE_DIR}" clean -fdqx

log "Applying current stack in temporary clone"
bash "${ROOT_DIR}/ci/winlator/apply-repo-patches.sh" "${CLONE_DIR}" "${PATCH_DIR}" >/dev/null

log "Rebuilding ${MAINLINE_PATCH} from full applied tree"
git -C "${CLONE_DIR}" diff --cached --binary --no-color HEAD > "${NEW_PATCH}"
[[ -s "${NEW_PATCH}" ]] || fail "Regenerated patch is empty"

cp -f "${NEW_PATCH}" "${MAINLINE_PATCH}"

if [[ "${WINLATOR_FOLD_DROP_SLICES}" == "1" ]]; then
  log "Dropping folded slice patches"
  find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' ! -name '0001-mainline-full-stack-consolidated.patch' -delete
fi

bash "${ROOT_DIR}/ci/winlator/validate-patch-sequence.sh" "${PATCH_DIR}" >/dev/null
log "Fold complete"
