#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${WCP_OUTPUT_DIR:-${ROOT_DIR}/out}"
CACHE_DIR="${CACHE_DIR:-${ROOT_DIR}/.cache}"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work/proton10}"
LOG_DIR="${OUT_DIR}/logs"
STAGE_DIR="${WORK_DIR}/stage"
WCP_ROOT="${WORK_DIR}/wcp_root"
BUILD_WINE_DIR="${WORK_DIR}/build-wine"
WINE_SRC_DIR="${WORK_DIR}/wine-src"
PROTON_GE_DIR="${WORK_DIR}/proton-ge-custom"
PATCHLOG_FILE="${OUT_DIR}/patchlog.txt"
SERIES_FILE="${ARM64EC_SERIES_FILE:-${OUT_DIR}/arm64ec-series.txt}"

: "${VALVE_WINE_REPO:=https://github.com/ValveSoftware/wine.git}"
: "${VALVE_WINE_REF:=986bda11d3e569813ec0f86e56ef94d7c384da04}"
: "${ANDRE_WINE_REPO:=https://github.com/AndreRH/wine.git}"
: "${ANDRE_ARM64EC_REF:=arm64ec}"
: "${PROTON_GE_REPO:=https://github.com/GloriousEggroll/proton-ge-custom.git}"
: "${PROTON_GE_REF:=GE-Proton10-32}"
: "${LLVM_MINGW_TAG:=${LLVM_MINGW_VER:-20260210}}"
: "${TARGET_HOST:=aarch64-linux-gnu}"
: "${WCP_NAME:=proton-10-arm64ec}"
: "${WCP_COMPRESS:=xz}"
: "${WCP_VERSION_NAME:=Proton10-${PROTON_GE_REF}-arm64ec}"
: "${WCP_VERSION_CODE:=10032}"
: "${WCP_DESCRIPTION:=Proton 10 ARM64EC for Winlator (Valve base + ARM64EC series + GE patches)}"
: "${PATCHLOG_FATAL_REGEX:=\\bfatal:|^error:|\\[[^]]*\\]\\[error\\]|Traceback \\(most recent call last\\)}"
: "${PATCHLOG_FALSE_POSITIVE_REGEX:=Hunk #[0-9]+ FAILED|[0-9]+ out of [0-9]+ hunks FAILED|saving rejects to file|0 errors|0 failures|without errors}"

TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-${CACHE_DIR}/llvm-mingw}"
export TOOLCHAIN_DIR
export CACHE_DIR
export LLVM_MINGW_TAG

source "${ROOT_DIR}/ci/lib/llvm-mingw.sh"

log() { printf '[proton10] %s\n' "$*"; }
fail() { printf '[proton10][error] %s\n' "$*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

ensure_symlink() {
  local link_path="$1" target="$2"
  if [[ -e "${link_path}" && ! -L "${link_path}" ]]; then
    fail "Path exists and is not a symlink: ${link_path}"
  fi
  ln -sfn "${target}" "${link_path}"
}

check_host_arch() {
  local arch
  arch="$(uname -m)"
  if [[ "${arch}" != "aarch64" && "${arch}" != "arm64" ]]; then
    fail "ARM64 host is required (aarch64/arm64). Current arch: ${arch}"
  fi
}

prepare_layout() {
  mkdir -p "${OUT_DIR}" "${CACHE_DIR}" "${WORK_DIR}" "${LOG_DIR}"
  rm -rf "${BUILD_WINE_DIR}" "${STAGE_DIR}" "${WCP_ROOT}" "${PROTON_GE_DIR}"
  mkdir -p "${BUILD_WINE_DIR}" "${STAGE_DIR}" "${WCP_ROOT}" "${LOG_DIR}"
}

run_arm64ec_flow() {
  export ROOT_DIR WORK_DIR WCP_OUTPUT_DIR="${OUT_DIR}"
  export VALVE_WINE_REPO VALVE_WINE_REF ANDRE_WINE_REPO ANDRE_ARM64EC_REF
  export ARM64EC_SERIES_FILE="${SERIES_FILE}"
  export ARM64EC_REVIEW_REPORT="${ROOT_DIR}/docs/ARM64EC_PATCH_REVIEW.md"

  bash "${ROOT_DIR}/ci/proton10/arm64ec-commit-review.sh"
  bash "${ROOT_DIR}/ci/proton10/apply-arm64ec-series.sh"
}

apply_proton_ge_patches() {
  local matches filtered warning_matches wine_parent

  log "Cloning proton-ge-custom at ${PROTON_GE_REF}"
  git clone --filter=blob:none --recurse-submodules "${PROTON_GE_REPO}" "${PROTON_GE_DIR}"
  pushd "${PROTON_GE_DIR}" >/dev/null
  git checkout "${PROTON_GE_REF}"
  git submodule update --init --recursive

  rm -rf "${PROTON_GE_DIR}/wine"
  ln -s "${WINE_SRC_DIR}" "${PROTON_GE_DIR}/wine"
  wine_parent="$(dirname "${WINE_SRC_DIR}")"
  # protonprep-valve-staging.sh expects ../patches and ../wine-staging relative to ./wine.
  ensure_symlink "${wine_parent}/patches" "${PROTON_GE_DIR}/patches"
  ensure_symlink "${wine_parent}/wine-staging" "${PROTON_GE_DIR}/wine-staging"

  [[ -x "./patches/protonprep-valve-staging.sh" ]] || fail "protonprep script not found"
  ./patches/protonprep-valve-staging.sh &> "${PATCHLOG_FILE}"
  popd >/dev/null

  matches="$(grep -niE "${PATCHLOG_FATAL_REGEX}" "${PATCHLOG_FILE}" || true)"
  filtered="${matches}"
  if [[ -n "${PATCHLOG_FALSE_POSITIVE_REGEX}" ]]; then
    filtered="$(printf '%s\n' "${matches}" | grep -viE "${PATCHLOG_FALSE_POSITIVE_REGEX}" || true)"
  fi

  if [[ -n "${filtered}" ]]; then
    printf '%s\n' "${filtered}" > "${LOG_DIR}/patchlog-failures.txt"
    fail "Detected fatal markers in patchlog.txt. See ${LOG_DIR}/patchlog-failures.txt"
  fi

  warning_matches="$(grep -niE 'Hunk #[0-9]+ FAILED|[0-9]+ out of [0-9]+ hunks FAILED|saving rejects to file' "${PATCHLOG_FILE}" || true)"
  if [[ -n "${warning_matches}" ]]; then
    printf '%s\n' "${warning_matches}" > "${LOG_DIR}/patchlog-warnings.txt"
    log "Patch warnings detected (non-fatal); see ${LOG_DIR}/patchlog-warnings.txt"
  fi

  log "Proton GE patch application completed without fatal markers"
}

fix_winnt_interlocked_types() {
  local winnt_h
  winnt_h="${WINE_SRC_DIR}/include/winnt.h"
  [[ -f "${winnt_h}" ]] || fail "Missing ${winnt_h}"

  # With WINE_NO_LONG_TYPES on i386, LONG may be int while InterlockedOr expects long.
  # Keep this local CI hotfix until the upstream-compatible variant is fully replayed.
  if grep -q '^    LONG dummy;$' "${winnt_h}"; then
    sed -i 's/^    LONG dummy;$/    long volatile dummy = 0;/' "${winnt_h}"
    log "Applied winnt.h InterlockedOr type hotfix for WINE_NO_LONG_TYPES"
  fi
}

build_wine() {
  local make_vulkan_log vk_xml video_xml

  export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"
  export CC=clang
  export CXX=clang++
  export LD=ld.lld
  export AR=llvm-ar
  export RANLIB=llvm-ranlib
  export STRIP=llvm-strip
  export TARGET_HOST

  log "TARGET_HOST=${TARGET_HOST}"
  log "clang path: $(command -v clang)"
  log "ld.lld path: $(command -v ld.lld)"
  which clang > "${LOG_DIR}/clang.which.txt"
  which ld.lld > "${LOG_DIR}/lld.which.txt"

  if [[ ! -f "${WINE_SRC_DIR}/include/wine/vulkan.h" ]]; then
    log "Generating missing include/wine/vulkan.h via make_vulkan"
    make_vulkan_log="${LOG_DIR}/make_vulkan.log"
    vk_xml="${PROTON_GE_DIR}/Vulkan-Headers/registry/vk.xml"
    video_xml="${PROTON_GE_DIR}/Vulkan-Headers/registry/video.xml"
    if [[ -f "${vk_xml}" && -f "${video_xml}" ]]; then
      if ! python3 "${WINE_SRC_DIR}/dlls/winevulkan/make_vulkan" -x "${vk_xml}" -X "${video_xml}" >"${make_vulkan_log}" 2>&1; then
        log "Bundled Vulkan registry parse failed; retrying with script-pinned registry download"
        python3 "${WINE_SRC_DIR}/dlls/winevulkan/make_vulkan" >>"${make_vulkan_log}" 2>&1 || fail "make_vulkan failed; see ${make_vulkan_log}"
      fi
    else
      # Fallback downloads XML into cache if bundled registry files are unavailable.
      python3 "${WINE_SRC_DIR}/dlls/winevulkan/make_vulkan" >"${make_vulkan_log}" 2>&1 || fail "make_vulkan failed; see ${make_vulkan_log}"
    fi
  fi
  [[ -f "${WINE_SRC_DIR}/include/wine/vulkan.h" ]] || fail "Missing include/wine/vulkan.h after make_vulkan"

  pushd "${BUILD_WINE_DIR}" >/dev/null
  "${WINE_SRC_DIR}/configure" \
    --prefix=/usr \
    --disable-tests \
    --with-mingw=clang \
    --enable-archs=arm64ec,aarch64,i386

  if ! make -j"$(nproc)" tools; then
    log "make tools target is unavailable; proceeding with full build"
  fi
  make -j"$(nproc)"
  make install DESTDIR="${STAGE_DIR}"
  [[ -f "config.log" ]] && cp -f "config.log" "${LOG_DIR}/wine-config.log"
  popd >/dev/null
}

compose_wcp_tree() {
  local utc_now out_wcp

  rsync -a "${STAGE_DIR}/usr/" "${WCP_ROOT}/"
  [[ -f "${ROOT_DIR}/prefixPack.txz" ]] || fail "prefixPack.txz is required but missing in repository root"
  cp -f "${ROOT_DIR}/prefixPack.txz" "${WCP_ROOT}/prefixPack.txz"

  mkdir -p "${WCP_ROOT}/winetools" "${WCP_ROOT}/share/winetools"
  cat > "${WCP_ROOT}/winetools/manifest.txt" <<'MANIFEST'
bin/wine
bin/wineserver
bin/winecfg
bin/regedit
bin/explorer
bin/msiexec
bin/notepad
MANIFEST

  {
    echo "== ELF (Unix launchers) =="
    for f in "${WCP_ROOT}/bin/wine" "${WCP_ROOT}/bin/wineserver"; do
      [[ -e "${f}" ]] || continue
      echo "--- ${f}"
      file "${f}" || true
      readelf -d "${f}" 2>/dev/null | sed -n '1,120p' || true
    done
  } > "${WCP_ROOT}/share/winetools/linking-report.txt"

  utc_now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  cat > "${WCP_ROOT}/profile.json" <<EOF_PROFILE
{
  "type": "Wine",
  "contentType": "Wine",
  "name": "Proton 10 ARM64EC",
  "versionName": "${WCP_VERSION_NAME}",
  "versionCode": ${WCP_VERSION_CODE},
  "description": "${WCP_DESCRIPTION}",
  "files": [],
  "wine": {
    "binPath": "bin",
    "libPath": "lib",
    "prefixPack": "prefixPack.txz"
  },
  "built": "${utc_now}"
}
EOF_PROFILE

  [[ -f "${WCP_ROOT}/bin/wine" ]] || fail "Missing bin/wine after staging"
  [[ -f "${WCP_ROOT}/bin/wineserver" ]] || fail "Missing bin/wineserver after staging"
  [[ -d "${WCP_ROOT}/lib/wine" ]] || fail "Missing lib/wine after staging"
  [[ -d "${WCP_ROOT}/share" ]] || fail "Missing share after staging"

  out_wcp="${OUT_DIR}/${WCP_NAME}.wcp"
  case "${WCP_COMPRESS}" in
    xz)
      tar -cJf "${out_wcp}" -C "${WCP_ROOT}" .
      ;;
    zst|zstd)
      tar --zstd -cf "${out_wcp}" -C "${WCP_ROOT}" .
      ;;
    *)
      fail "WCP_COMPRESS must be xz or zst"
      ;;
  esac
}

main() {
  cd "${ROOT_DIR}"

  require_cmd bash
  require_cmd curl
  require_cmd git
  require_cmd tar
  require_cmd rsync
  require_cmd file
  require_cmd readelf
  require_cmd python3
  require_cmd cmake
  require_cmd make
  require_cmd grep
  require_cmd sed
  [[ -n "${TARGET_HOST}" ]] || fail "TARGET_HOST must be set"

  check_host_arch
  prepare_layout
  ensure_llvm_mingw
  run_arm64ec_flow
  apply_proton_ge_patches
  fix_winnt_interlocked_types
  build_wine
  compose_wcp_tree
  bash "${ROOT_DIR}/ci/proton10/smoke-check-wcp.sh" "${OUT_DIR}/${WCP_NAME}.wcp" "${WCP_COMPRESS}"

  cp -f "${ROOT_DIR}/docs/ARM64EC_PATCH_REVIEW.md" "${LOG_DIR}/ARM64EC_PATCH_REVIEW.md"
  log "Build completed: ${OUT_DIR}/${WCP_NAME}.wcp"
}

main "$@"
