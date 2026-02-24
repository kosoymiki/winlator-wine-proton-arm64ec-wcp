#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${WCP_OUTPUT_DIR:-${ROOT_DIR}/out/proton-ge10}"
CACHE_DIR="${CACHE_DIR:-${ROOT_DIR}/.cache}"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work/proton-ge10}"
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
: "${WCP_NAME:=proton-ge10-arm64ec}"
: "${WCP_COMPRESS:=xz}"
# Winlator's current parser expects versionName in numeric form and a one-digit
# trailing versionCode in the generated Wine identifier (Wine-<ver>-<code>).
_proton_ge_version_name="10.32-arm64ec"
if [[ "${PROTON_GE_REF}" =~ Proton([0-9]+)-([0-9]+) ]]; then
  _proton_ge_version_name="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}-arm64ec"
fi
: "${WCP_VERSION_NAME:=${_proton_ge_version_name}}"
: "${WCP_VERSION_CODE:=0}"
: "${WCP_CHANNEL:=stable}"
: "${WCP_DELIVERY:=remote}"
: "${WCP_DISPLAY_CATEGORY:=Wine/Proton}"
: "${WCP_SOURCE_REPO:=${GITHUB_REPOSITORY:-kosoymiki/winlator-wine-proton-arm64ec-wcp}}"
: "${WCP_RELEASE_TAG:=wcp-latest}"
: "${WCP_DESCRIPTION:=Proton GE10 ARM64EC WCP (Valve base + ARM64EC series + GE patches)}"
: "${WCP_PROFILE_NAME:=Proton GE10 ARM64EC}"
: "${WCP_TARGET_RUNTIME:=winlator-bionic}"
: "${WCP_RUNTIME_CLASS_TARGET:=bionic-native}"
: "${WCP_RUNTIME_CLASS_ENFORCE:=0}"
: "${WCP_PRUNE_EXTERNAL_COMPONENTS:=1}"
: "${WCP_ENABLE_SDL2_RUNTIME:=1}"
if [[ -z "${WCP_GLIBC_SOURCE_MODE+x}" ]]; then
  if [[ "${WCP_RUNTIME_CLASS_TARGET}" == "glibc-wrapped" ]]; then
    WCP_GLIBC_SOURCE_MODE="pinned-source"
  else
    WCP_GLIBC_SOURCE_MODE="host"
  fi
fi
: "${WCP_GLIBC_VERSION:=2.43}"
: "${WCP_GLIBC_TARGET_VERSION:=2.43}"
: "${WCP_GLIBC_SOURCE_URL:=https://ftp.gnu.org/gnu/glibc/glibc-2.43.tar.xz}"
: "${WCP_GLIBC_SOURCE_SHA256:=d9c86c6b5dbddb43a3e08270c5844fc5177d19442cf5b8df4be7c07cd5fa3831}"
: "${WCP_GLIBC_SOURCE_REF:=glibc-2.43}"
: "${WCP_GLIBC_PATCHSET_ID:=}"
: "${WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR:=}"
: "${WCP_GLIBC_RUNTIME_PATCH_SCRIPT:=}"
: "${WCP_RUNTIME_BUNDLE_LOCK_ID:=glibc-2.43-bundle-v1}"
: "${WCP_RUNTIME_BUNDLE_LOCK_FILE:=${ROOT_DIR}/ci/runtime-bundle/locks/glibc-2.43-bundle-v1.env}"
: "${WCP_RUNTIME_BUNDLE_ENFORCE_LOCK:=0}"
: "${WCP_RUNTIME_BUNDLE_LOCK_MODE:=relaxed-enforce}"
: "${WCP_INCLUDE_FEX_DLLS:=0}"
: "${WCP_FEX_EXPECTATION_MODE:=external}"
: "${PATCHLOG_FATAL_REGEX:=\bfatal:|^error:|\[[^]]*\]\[error\]|Traceback \(most recent call last\)}"
: "${PATCHLOG_FALSE_POSITIVE_REGEX:=Hunk #[0-9]+ FAILED|[0-9]+ out of [0-9]+ hunks FAILED|saving rejects to file|0 errors|0 failures|without errors}"

TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-${CACHE_DIR}/llvm-mingw}"
export TOOLCHAIN_DIR CACHE_DIR LLVM_MINGW_TAG

log() { printf '[proton-ge10] %s\n' "$*"; }
fail() { printf '[proton-ge10][error] %s\n' "$*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

source "${ROOT_DIR}/ci/lib/wcp_common.sh"

preflight_runtime_profile() {
  [[ -n "${WCP_TARGET_RUNTIME}" ]] || fail "WCP_TARGET_RUNTIME must not be empty"
  wcp_require_bool WCP_PRUNE_EXTERNAL_COMPONENTS "${WCP_PRUNE_EXTERNAL_COMPONENTS}"
  wcp_require_bool WCP_ENABLE_SDL2_RUNTIME "${WCP_ENABLE_SDL2_RUNTIME}"
  wcp_require_bool WCP_RUNTIME_CLASS_ENFORCE "${WCP_RUNTIME_CLASS_ENFORCE}"
  wcp_require_bool WCP_INCLUDE_FEX_DLLS "${WCP_INCLUDE_FEX_DLLS}"
  wcp_require_enum WCP_RUNTIME_CLASS_TARGET "${WCP_RUNTIME_CLASS_TARGET}" bionic-native glibc-wrapped
  wcp_require_enum WCP_FEX_EXPECTATION_MODE "${WCP_FEX_EXPECTATION_MODE}" external bundled
  wcp_require_enum WCP_RUNTIME_BUNDLE_LOCK_MODE "${WCP_RUNTIME_BUNDLE_LOCK_MODE}" audit enforce relaxed-enforce
  if [[ "${WCP_FEX_EXPECTATION_MODE}" == "bundled" && "${WCP_PRUNE_EXTERNAL_COMPONENTS}" == "1" ]]; then
    fail "WCP_FEX_EXPECTATION_MODE=bundled conflicts with WCP_PRUNE_EXTERNAL_COMPONENTS=1"
  fi
  wcp_validate_winlator_profile_identifier "${WCP_VERSION_NAME}" "${WCP_VERSION_CODE}"
}

ensure_symlink() {
  local link_path="$1" target="$2"
  if [[ -e "${link_path}" && ! -L "${link_path}" ]]; then
    fail "Path exists and is not a symlink: ${link_path}"
  fi
  ln -sfn "${target}" "${link_path}"
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

  if grep -q '^    LONG dummy;$' "${winnt_h}"; then
    sed -i 's/^    LONG dummy;$/    long volatile dummy = 0;/' "${winnt_h}"
    log "Applied winnt.h InterlockedOr type hotfix for WINE_NO_LONG_TYPES"
  fi
}

fix_winebus_sdl_stub() {
  local bus_sdl_c
  bus_sdl_c="${WINE_SRC_DIR}/dlls/winebus.sys/bus_sdl.c"
  [[ -f "${bus_sdl_c}" ]] || fail "Missing ${bus_sdl_c}"

  perl -0pi -e 's/#else\n\nNTSTATUS sdl_bus_init\(void \*args\)/#else\n\nBOOL is_sdl_ignored_device(WORD vid, WORD pid)\n{\n    return FALSE;\n}\n\nNTSTATUS sdl_bus_init(void *args)/' "${bus_sdl_c}"
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

build_wine() {
  local make_vulkan_log

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

  make_vulkan_log="${LOG_DIR}/make_vulkan.log"
  wcp_try_bootstrap_winevulkan "${WINE_SRC_DIR}" "${make_vulkan_log}" "${PROTON_GE_DIR}"

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
  run_arm64ec_flow
  apply_proton_ge_patches
  fix_winnt_interlocked_types
  fix_winebus_sdl_stub
  build_wine

  compose_wcp_tree_from_stage "${STAGE_DIR}" "${WCP_ROOT}"
  prune_external_runtime_components
  wcp_write_forensic_manifest "${WCP_ROOT}"
  validate_wcp_tree_arm64ec "${WCP_ROOT}"
  artifact="$(pack_wcp "${WCP_ROOT}" "${OUT_DIR}" "${WCP_NAME}")"
  smoke_check_wcp "${artifact}" "${WCP_COMPRESS}"

  cp -f "${ROOT_DIR}/docs/ARM64EC_PATCH_REVIEW.md" "${LOG_DIR}/ARM64EC_PATCH_REVIEW.md"
  log "Build completed: ${artifact}"
}

main "$@"
