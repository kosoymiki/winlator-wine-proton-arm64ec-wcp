#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_DIR="${1:-}"
SLUG="${2:-slice}"
PATCH_DIR="${3:-${ROOT_DIR}/ci/winlator/patches}"

log() { printf '[slice-patch] %s\n' "$*"; }
fail() { printf '[slice-patch][error] %s\n' "$*" >&2; exit 1; }

[[ -n "${SRC_DIR}" ]] || fail "usage: $0 <winlator-src-dir> [slug] [patch-dir]"
[[ -d "${SRC_DIR}/.git" ]] || fail "Not a git checkout: ${SRC_DIR}"
[[ -d "${PATCH_DIR}" ]] || fail "Patch dir not found: ${PATCH_DIR}"

if [[ ! "${SLUG}" =~ ^[a-z0-9._-]+$ ]]; then
  fail "slug must match [a-z0-9._-]+"
fi

TMP_DIR="$(mktemp -d /tmp/winlator_slice_patch_XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT
BASE_DIR="${TMP_DIR}/base"

log "Preparing clean baseline clone"
git clone -q --no-hardlinks -- "${SRC_DIR}" "${BASE_DIR}"
git -C "${BASE_DIR}" reset --hard -q HEAD
git -C "${BASE_DIR}" clean -fdqx
git -C "${BASE_DIR}" config user.name codex
git -C "${BASE_DIR}" config user.email codex@example.invalid

log "Applying current patch stack"
bash "${ROOT_DIR}/ci/winlator/apply-repo-patches.sh" "${BASE_DIR}" "${PATCH_DIR}" >/dev/null

git -C "${BASE_DIR}" commit -q -am baseline-mainline

log "Overlaying source working tree onto patched baseline"
rsync -a --delete --exclude '.git' "${SRC_DIR}/" "${BASE_DIR}/"

git -C "${BASE_DIR}" add -A
if git -C "${BASE_DIR}" diff --cached --quiet; then
  fail "No delta between source tree and patched baseline; slice patch is empty"
fi

next_info="$(bash "${ROOT_DIR}/ci/winlator/next-patch-number.sh" "${PATCH_DIR}" "${SLUG}")"
next_number="$(printf '%s\n' "${next_info}" | awk -F= '/^next_number=/{print $2}')"
out_file="${PATCH_DIR}/${next_number}-${SLUG}.patch"

log "Writing ${out_file}"
git -C "${BASE_DIR}" diff --cached --binary --no-color HEAD > "${out_file}"
[[ -s "${out_file}" ]] || fail "Generated patch is empty: ${out_file}"

bash "${ROOT_DIR}/ci/winlator/validate-patch-sequence.sh" "${PATCH_DIR}" >/dev/null
log "Slice patch created: ${out_file}"
