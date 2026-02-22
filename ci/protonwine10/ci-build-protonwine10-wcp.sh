#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${WCP_OUTPUT_DIR:-${ROOT_DIR}/out/protonwine10}"
CACHE_DIR="${CACHE_DIR:-${ROOT_DIR}/.cache}"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work/protonwine10}"
LOG_DIR="${OUT_DIR}/logs"
STAGE_DIR="${WORK_DIR}/stage"
WCP_ROOT="${WORK_DIR}/wcp_root"
BUILD_WINE_DIR="${WORK_DIR}/build-wine"
WINE_SRC_DIR="${WORK_DIR}/wine-src"

: "${PROTONWINE_REPO:=https://github.com/GameNative/proton-wine.git}"
: "${PROTONWINE_REF:=e7dbb4a10b85c1e8d505068d36249127d8b7fe79}"
: "${ANDROID_SUPPORT_REPO:=https://github.com/sidaodomorro/proton-wine.git}"
: "${ANDROID_SUPPORT_REF:=47e79a66652afae9fd0e521b03736d1e6536ac5a}"
: "${PROTONWINE_ANDROID_SUPPORT_ROOT:=}"
: "${PROTONWINE_UPSTREAM_FIX_COMMITS:=}"
: "${LLVM_MINGW_TAG:=${LLVM_MINGW_VER:-20260210}}"
: "${TARGET_HOST:=aarch64-linux-gnu}"
: "${WCP_NAME:=protonwine10-gamenative-arm64ec}"
: "${WCP_COMPRESS:=xz}"
: "${WCP_VERSION_NAME:=ProtonWine10-GameNative-arm64ec}"
: "${WCP_VERSION_CODE:=10010}"
: "${WCP_DESCRIPTION:=ProtonWine10 GameNative ARM64EC WCP}"
: "${WCP_PROFILE_NAME:=ProtonWine10 GameNative ARM64EC}"
: "${WCP_TARGET_RUNTIME:=winlator-bionic}"
: "${WCP_PRUNE_EXTERNAL_COMPONENTS:=1}"
: "${WCP_ENABLE_SDL2_RUNTIME:=1}"

TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-${CACHE_DIR}/llvm-mingw}"
export TOOLCHAIN_DIR CACHE_DIR LLVM_MINGW_TAG

log() { printf '[protonwine10] %s\n' "$*"; }
fail() { printf '[protonwine10][error] %s\n' "$*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

source "${ROOT_DIR}/ci/lib/wcp_common.sh"

preflight_runtime_profile() {
  [[ -n "${WCP_TARGET_RUNTIME}" ]] || fail "WCP_TARGET_RUNTIME must not be empty"
  wcp_require_bool WCP_PRUNE_EXTERNAL_COMPONENTS "${WCP_PRUNE_EXTERNAL_COMPONENTS}"
  wcp_require_bool WCP_ENABLE_SDL2_RUNTIME "${WCP_ENABLE_SDL2_RUNTIME}"
}

prepare_layout() {
  mkdir -p "${OUT_DIR}" "${CACHE_DIR}" "${WORK_DIR}" "${LOG_DIR}"
  rm -rf "${BUILD_WINE_DIR}" "${STAGE_DIR}" "${WCP_ROOT}" "${WINE_SRC_DIR}"
  mkdir -p "${BUILD_WINE_DIR}" "${STAGE_DIR}" "${WCP_ROOT}" "${LOG_DIR}"
}

clone_protonwine_source() {
  log "Cloning GameNative/proton-wine at ${PROTONWINE_REF}"
  git clone --filter=blob:none --no-checkout "${PROTONWINE_REPO}" "${WINE_SRC_DIR}"
  git -C "${WINE_SRC_DIR}" fetch --no-tags origin "${PROTONWINE_REF}"
  git -C "${WINE_SRC_DIR}" checkout --detach "${PROTONWINE_REF}"
}

ensure_sdl2_tooling() {
  [[ "${WCP_ENABLE_SDL2_RUNTIME}" == "1" ]] || return
  require_cmd pkg-config
  pkg-config --exists sdl2 || fail "SDL2 development files are missing (pkg-config sdl2 failed)"
}

validate_sdl2_runtime_payload() {
  local winebus_module
  [[ "${WCP_ENABLE_SDL2_RUNTIME}" == "1" ]] || return

  if [[ -f "${STAGE_DIR}/usr/lib/wine/aarch64-unix/winebus.so" ]]; then
    winebus_module="${STAGE_DIR}/usr/lib/wine/aarch64-unix/winebus.so"
  elif [[ -f "${STAGE_DIR}/usr/lib/wine/aarch64-unix/winebus.sys.so" ]]; then
    winebus_module="${STAGE_DIR}/usr/lib/wine/aarch64-unix/winebus.sys.so"
  else
    fail "SDL2 runtime check failed: missing winebus.so (or winebus.sys.so)"
  fi

  if readelf -d "${winebus_module}" | grep -Eiq 'NEEDED.*SDL2'; then
    log "SDL2 runtime check passed ($(basename "${winebus_module}") links against SDL2)"
  else
    log "SDL2 runtime probe is inconclusive for $(basename "${winebus_module}"); continuing"
  fi
}

prune_external_runtime_components() {
  local path

  [[ "${WCP_PRUNE_EXTERNAL_COMPONENTS}" == "1" ]] || return

  local prune_paths=(
    "lib/wine/aarch64-windows/libarm64ecfex.dll"
    "lib/wine/aarch64-windows/libwow64fex.dll"
    "lib/wine/i386-windows/libwow64fex.dll"
    "lib/wine/fexcore"
    "lib/fexcore"
    "share/fexcore"
    "lib/wine/dxvk"
    "lib/wine/vkd3d"
    "lib/wine/vk3d"
    "lib/dxvk"
    "lib/vkd3d"
    "share/dxvk"
    "share/vkd3d"
    "share/vulkan/icd.d"
    "share/vulkan/implicit_layer.d"
    "share/vulkan/explicit_layer.d"
  )

  : > "${LOG_DIR}/pruned-components.txt"
  for path in "${prune_paths[@]}"; do
    if [[ -e "${WCP_ROOT}/${path}" ]]; then
      rm -rf "${WCP_ROOT:?}/${path}"
      printf '%s\n' "${path}" >> "${LOG_DIR}/pruned-components.txt"
    fi
  done
}

run_upstream_analysis_and_fixes() {
  export ROOT_DIR WORK_DIR WCP_OUTPUT_DIR="${OUT_DIR}" WINE_SRC_DIR
  export PROTONWINE_REPO PROTONWINE_REF
  export ANDROID_SUPPORT_REPO ANDROID_SUPPORT_REF PROTONWINE_ANDROID_SUPPORT_ROOT
  export PROTONWINE_UPSTREAM_FIX_COMMITS

  bash "${ROOT_DIR}/ci/protonwine10/inspect-upstreams.sh"
  bash "${ROOT_DIR}/ci/protonwine10/android-support-review.sh"
  bash "${ROOT_DIR}/ci/protonwine10/apply-upstream-fixes.sh"
  bash "${ROOT_DIR}/ci/protonwine10/apply-our-fixes.sh"
}

build_wine() {
  local make_vulkan_log make_vulkan_py vk_xml video_xml
  ensure_sdl2_tooling

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

  if [[ ! -f "${WINE_SRC_DIR}/include/wine/vulkan.h" ]]; then
    make_vulkan_log="${LOG_DIR}/make_vulkan.log"
    make_vulkan_py="${WINE_SRC_DIR}/dlls/winevulkan/make_vulkan"
    vk_xml="${WINE_SRC_DIR}/dlls/winevulkan/vk.xml"
    video_xml="${WINE_SRC_DIR}/dlls/winevulkan/video.xml"

    if [[ ! -f "${vk_xml}" && -f "${WINE_SRC_DIR}/Vulkan-Headers/registry/vk.xml" ]]; then
      vk_xml="${WINE_SRC_DIR}/Vulkan-Headers/registry/vk.xml"
      video_xml="${WINE_SRC_DIR}/Vulkan-Headers/registry/video.xml"
    fi

    if [[ -f "${make_vulkan_py}" && -f "${vk_xml}" ]]; then
      if [[ -f "${video_xml}" ]]; then
        python3 "${make_vulkan_py}" -x "${vk_xml}" -X "${video_xml}" >"${make_vulkan_log}" 2>&1 || fail "make_vulkan failed; see ${make_vulkan_log}"
      else
        python3 "${make_vulkan_py}" -x "${vk_xml}" >"${make_vulkan_log}" 2>&1 || fail "make_vulkan failed; see ${make_vulkan_log}"
      fi
    else
      log "Skipping make_vulkan bootstrap (missing script or vk.xml)"
    fi
  fi

  build_wine_tools_host "${WINE_SRC_DIR}" "${BUILD_WINE_DIR}"
  build_wine_multiarc_arm64ec "${WINE_SRC_DIR}" "${BUILD_WINE_DIR}" "${STAGE_DIR}"
  validate_sdl2_runtime_payload
}

main() {
  local artifact

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
  require_cmd perl
  require_cmd pkg-config

  preflight_runtime_profile
  wcp_check_host_arch
  prepare_layout
  ensure_llvm_mingw
  clone_protonwine_source
  run_upstream_analysis_and_fixes
  build_wine

  compose_wcp_tree_from_stage "${STAGE_DIR}" "${WCP_ROOT}"
  prune_external_runtime_components
  validate_wcp_tree_arm64ec "${WCP_ROOT}"
  artifact="$(pack_wcp "${WCP_ROOT}" "${OUT_DIR}" "${WCP_NAME}")"
  smoke_check_wcp "${artifact}" "${WCP_COMPRESS}"

  cp -f "${ROOT_DIR}/docs/PROTONWINE_ANDROID_SUPPORT_REVIEW.md" "${LOG_DIR}/PROTONWINE_ANDROID_SUPPORT_REVIEW.md"
  log "Build completed: ${artifact}"
}

main "$@"
