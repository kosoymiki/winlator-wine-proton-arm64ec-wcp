#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
ASSET_ZIP="${1:-}"
SRC_DIR="${2:-}"
PATCH_DIR="${3:-${ROOT_DIR}/ci/winlator/patches}"

: "${WINLATOR_ASSET_SLUG:=aesolator-safezone-allskins-assets}"
: "${WINLATOR_ASSET_IMPORT_MODE:=fold}"
: "${WINLATOR_ASSET_DEST_SUBDIR:=app/src/main}"
: "${WINLATOR_ASSET_VALIDATE_ONLY:=0}"
: "${WINLATOR_FOLD_DROP_SLICES:=1}"

log() { printf '[asset-import] %s\n' "$*"; }
fail() { printf '[asset-import][error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") <assets-zip> <winlator-src-git-dir> [patch-dir]

Import Ae.solator Android resource overlay (res/*) into Winlator source,
create a slice patch, and optionally fold back into consolidated mainline patch.

Env:
  WINLATOR_ASSET_SLUG          default: aesolator-safezone-allskins-assets
  WINLATOR_ASSET_IMPORT_MODE   default: fold (slice|fold)
  WINLATOR_ASSET_DEST_SUBDIR   default: app/src/main
  WINLATOR_ASSET_VALIDATE_ONLY default: 0
  WINLATOR_FOLD_DROP_SLICES    default: 1
USAGE
}

[[ -n "${ASSET_ZIP}" ]] || { usage; fail "assets zip path is required"; }
[[ -n "${SRC_DIR}" ]] || { usage; fail "source dir path is required"; }
[[ -f "${ASSET_ZIP}" ]] || fail "assets zip not found: ${ASSET_ZIP}"
[[ -d "${SRC_DIR}/.git" ]] || fail "not a git checkout: ${SRC_DIR}"
[[ -d "${PATCH_DIR}" ]] || fail "patch dir not found: ${PATCH_DIR}"
[[ "${WINLATOR_ASSET_IMPORT_MODE}" =~ ^(slice|fold)$ ]] || fail "WINLATOR_ASSET_IMPORT_MODE must be slice or fold"
[[ "${WINLATOR_ASSET_VALIDATE_ONLY}" =~ ^[01]$ ]] || fail "WINLATOR_ASSET_VALIDATE_ONLY must be 0 or 1"

command -v unzip >/dev/null 2>&1 || fail "unzip is required"
command -v git >/dev/null 2>&1 || fail "git is required"

dest_dir="${SRC_DIR}/${WINLATOR_ASSET_DEST_SUBDIR}"
[[ -d "${dest_dir}" ]] || fail "asset destination root not found: ${dest_dir}"
[[ -d "${dest_dir}/res" ]] || fail "asset destination has no res/: ${dest_dir}/res"

zip_entries="$(unzip -Z -1 "${ASSET_ZIP}" | wc -l | tr -d '[:space:]')"
res_entries="$(unzip -Z -1 "${ASSET_ZIP}" | grep -E '^res/' | wc -l | tr -d '[:space:]')"
log "zip=${ASSET_ZIP}"
log "entries=${zip_entries}, res_entries=${res_entries}"

if [[ "${WINLATOR_ASSET_VALIDATE_ONLY}" == "1" ]]; then
  log "validate-only mode: no source mutations"
  exit 0
fi

before_dirty=0
if ! git -C "${SRC_DIR}" diff --quiet || ! git -C "${SRC_DIR}" diff --cached --quiet; then
  before_dirty=1
fi

log "extracting assets into ${dest_dir}"
unzip -oq "${ASSET_ZIP}" -d "${dest_dir}"

if git -C "${SRC_DIR}" diff --quiet && git -C "${SRC_DIR}" diff --cached --quiet; then
  if [[ "${before_dirty}" == "0" ]]; then
    log "no source delta after extract (assets already applied)"
  else
    log "no new source delta from this import (tree already dirty)"
  fi
  exit 0
fi

log "creating slice patch (${WINLATOR_ASSET_SLUG})"
slice_log="$(mktemp /tmp/winlator_asset_slice_XXXXXX.log)"
if ! bash "${ROOT_DIR}/ci/winlator/create-slice-patch.sh" "${SRC_DIR}" "${WINLATOR_ASSET_SLUG}" "${PATCH_DIR}" >"${slice_log}" 2>&1; then
  if grep -Fq "slice patch is empty" "${slice_log}"; then
    cat "${slice_log}"
    rm -f "${slice_log}"
    log "no patch delta from asset import; consolidated patch already includes these assets"
    exit 0
  fi
  cat "${slice_log}" >&2
  rm -f "${slice_log}"
  fail "slice patch generation failed"
fi
cat "${slice_log}"
rm -f "${slice_log}"

if [[ "${WINLATOR_ASSET_IMPORT_MODE}" == "fold" ]]; then
  log "folding slice(s) into consolidated mainline patch"
  WINLATOR_FOLD_DROP_SLICES="${WINLATOR_FOLD_DROP_SLICES}" \
    bash "${ROOT_DIR}/ci/winlator/fold-into-mainline.sh" "${SRC_DIR}" "${PATCH_DIR}"
fi

log "validating patch sequence + audits"
bash "${ROOT_DIR}/ci/winlator/validate-patch-sequence.sh" "${PATCH_DIR}"
bash "${ROOT_DIR}/ci/winlator/run-reflective-audits.sh"

log "asset import complete"
