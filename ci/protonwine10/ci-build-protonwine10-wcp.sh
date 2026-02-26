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
: "${PROTONWINE_REF:=proton_10.0}"
: "${ANDROID_SUPPORT_REPO:=https://github.com/sidaodomorro/proton-wine.git}"
: "${ANDROID_SUPPORT_REF:=47e79a66652afae9fd0e521b03736d1e6536ac5a}"
: "${PROTONWINE_ANDROID_SUPPORT_ROOT:=}"
: "${PROTONWINE_UPSTREAM_FIX_COMMITS:=}"
: "${LLVM_MINGW_TAG:=${LLVM_MINGW_VER:-20260210}}"
: "${TARGET_HOST:=aarch64-linux-gnu}"
: "${WCP_NAME:=protonwine10-gamenative-arm64ec}"
: "${WCP_COMPRESS:=xz}"
# Keep version metadata compatible with Winlator identifier parsing.
: "${WCP_VERSION_NAME:=10.10-arm64ec}"
: "${WCP_VERSION_CODE:=0}"
: "${WCP_CHANNEL:=stable}"
: "${WCP_DELIVERY:=remote}"
: "${WCP_DISPLAY_CATEGORY:=Wine/Proton}"
: "${WCP_SOURCE_REPO:=${GITHUB_REPOSITORY:-kosoymiki/winlator-wine-proton-arm64ec-wcp}}"
: "${WCP_RELEASE_TAG:=wcp-latest}"
: "${WCP_DESCRIPTION:=ProtonWine10 GameNative ARM64EC WCP}"
: "${WCP_PROFILE_NAME:=ProtonWine10 GameNative ARM64EC}"
: "${WCP_TARGET_RUNTIME:=winlator-bionic}"
: "${WCP_RUNTIME_CLASS_TARGET:=bionic-native}"
: "${WCP_RUNTIME_CLASS_ENFORCE:=1}"
: "${WCP_PRUNE_EXTERNAL_COMPONENTS:=1}"
: "${WCP_ENABLE_SDL2_RUNTIME:=1}"
: "${WCP_GLIBC_SOURCE_MODE:=host}"
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
: "${WCP_MAINLINE_BIONIC_ONLY:=1}"
: "${WCP_MAINLINE_FEX_EXTERNAL_ONLY:=1}"
: "${WCP_ALLOW_GLIBC_EXPERIMENTAL:=0}"
: "${WCP_BIONIC_SOURCE_MAP_FILE:=${ROOT_DIR}/ci/runtime-sources/bionic-source-map.json}"
: "${WCP_BIONIC_SOURCE_MAP_FORCE:=0}"
: "${WCP_BIONIC_SOURCE_MAP_REQUIRED:=0}"
: "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:=}"
: "${WCP_BIONIC_UNIX_SOURCE_WCP_URL:=}"
: "${WCP_BIONIC_DONOR_PREFLIGHT:=1}"
: "${WCP_BIONIC_UNIX_CORE_ADOPT:=0}"
: "${WCP_GN_PATCHSET_ENABLE:=0}"
: "${WCP_GN_PATCHSET_REF:=28c3a06ba773f6d29b9f3ed23b9297f94af4771c}"
: "${WCP_GN_PATCHSET_STRICT:=1}"
: "${WCP_GN_PATCHSET_VERIFY_AUTOFIX:=1}"
: "${WCP_GN_PATCHSET_REPORT:=${LOG_DIR}/gamenative-patchset-protonwine.tsv}"
: "${WINE_TOOLS_CONFIGURE_EXTRA_ARGS:=--without-gstreamer --without-wayland}"
: "${WINE_CONFIGURE_EXTRA_ARGS:=--without-fontconfig --without-gstreamer --without-wayland}"
: "${WINE_CONFIGURE_PROFILE:=proton-android-minimal}"

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
  wcp_require_bool WCP_RUNTIME_CLASS_ENFORCE "${WCP_RUNTIME_CLASS_ENFORCE}"
  wcp_require_bool WCP_INCLUDE_FEX_DLLS "${WCP_INCLUDE_FEX_DLLS}"
  wcp_require_bool WCP_MAINLINE_BIONIC_ONLY "${WCP_MAINLINE_BIONIC_ONLY}"
  wcp_require_bool WCP_MAINLINE_FEX_EXTERNAL_ONLY "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}"
  wcp_require_bool WCP_ALLOW_GLIBC_EXPERIMENTAL "${WCP_ALLOW_GLIBC_EXPERIMENTAL}"
  wcp_require_bool WCP_BIONIC_SOURCE_MAP_FORCE "${WCP_BIONIC_SOURCE_MAP_FORCE}"
  wcp_require_bool WCP_BIONIC_SOURCE_MAP_REQUIRED "${WCP_BIONIC_SOURCE_MAP_REQUIRED}"
  wcp_require_bool WCP_GN_PATCHSET_ENABLE "${WCP_GN_PATCHSET_ENABLE}"
  wcp_require_bool WCP_GN_PATCHSET_STRICT "${WCP_GN_PATCHSET_STRICT}"
  wcp_require_bool WCP_GN_PATCHSET_VERIFY_AUTOFIX "${WCP_GN_PATCHSET_VERIFY_AUTOFIX}"
  wcp_require_enum WCP_RUNTIME_CLASS_TARGET "${WCP_RUNTIME_CLASS_TARGET}" bionic-native glibc-wrapped
  wcp_require_enum WCP_FEX_EXPECTATION_MODE "${WCP_FEX_EXPECTATION_MODE}" external bundled
  wcp_require_enum WCP_RUNTIME_BUNDLE_LOCK_MODE "${WCP_RUNTIME_BUNDLE_LOCK_MODE}" audit enforce relaxed-enforce
  if [[ "${WCP_FEX_EXPECTATION_MODE}" == "bundled" && "${WCP_PRUNE_EXTERNAL_COMPONENTS}" == "1" ]]; then
    fail "WCP_FEX_EXPECTATION_MODE=bundled conflicts with WCP_PRUNE_EXTERNAL_COMPONENTS=1"
  fi
  wcp_validate_winlator_profile_identifier "${WCP_VERSION_NAME}" "${WCP_VERSION_CODE}"
  wcp_enforce_mainline_bionic_policy
  wcp_enforce_mainline_external_runtime_policy
  winlator_preflight_bionic_source_contract
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
  wcp_try_bootstrap_winevulkan "${WINE_SRC_DIR}" "${make_vulkan_log}"

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
  if [[ "${WCP_GN_PATCHSET_ENABLE}" == "1" ]]; then
    WCP_GN_PATCHSET_STRICT="${WCP_GN_PATCHSET_STRICT}" \
      WCP_GN_PATCHSET_VERIFY_AUTOFIX="${WCP_GN_PATCHSET_VERIFY_AUTOFIX}" \
      WCP_GN_PATCHSET_REF="${WCP_GN_PATCHSET_REF}" \
      WCP_GN_PATCHSET_REPORT="${WCP_GN_PATCHSET_REPORT}" \
      bash "${ROOT_DIR}/ci/gamenative/apply-android-patchset.sh" --target wine --source-dir "${WINE_SRC_DIR}"
  else
    log "GameNative patchset integration disabled for protonwine10 (WCP_GN_PATCHSET_ENABLE=0)"
  fi
  log "Running GameNative contract in warn-only mode for protonwine source"
  WCP_GN_PATCHSET_STRICT=0 \
    bash "${ROOT_DIR}/ci/validation/check-gamenative-patch-contract.sh" --target wine --source-dir "${WINE_SRC_DIR}"
  build_wine

  compose_wcp_tree_from_stage "${STAGE_DIR}" "${WCP_ROOT}"
  wcp_prune_external_runtime_components "${WCP_ROOT}" "${LOG_DIR}/pruned-components.txt"
  wcp_write_forensic_manifest "${WCP_ROOT}"
  validate_wcp_tree_arm64ec "${WCP_ROOT}"
  artifact="$(pack_wcp "${WCP_ROOT}" "${OUT_DIR}" "${WCP_NAME}")"
  smoke_check_wcp "${artifact}" "${WCP_COMPRESS}"

  cp -f "${ROOT_DIR}/docs/PROTONWINE_ANDROID_SUPPORT_REVIEW.md" "${LOG_DIR}/PROTONWINE_ANDROID_SUPPORT_REVIEW.md"
  log "Build completed: ${artifact}"
}

main "$@"
