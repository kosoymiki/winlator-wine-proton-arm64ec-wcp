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
: "${WCP_DESCRIPTION:=Proton 10 ARM64EC for Winlator bionic (Valve base + ARM64EC series + GE patches)}"
: "${WCP_TARGET_RUNTIME:=winlator-bionic}"
: "${WCP_PRUNE_EXTERNAL_COMPONENTS:=1}"
: "${WCP_ENABLE_SDL2_RUNTIME:=1}"
: "${PATCHLOG_FATAL_REGEX:=\\bfatal:|^error:|\\[[^]]*\\]\\[error\\]|Traceback \\(most recent call last\\)}"
: "${PATCHLOG_FALSE_POSITIVE_REGEX:=Hunk #[0-9]+ FAILED|[0-9]+ out of [0-9]+ hunks FAILED|saving rejects to file|0 errors|0 failures|without errors}"

TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-${CACHE_DIR}/llvm-mingw}"
export TOOLCHAIN_DIR
export CACHE_DIR
export LLVM_MINGW_TAG

source "${ROOT_DIR}/ci/lib/llvm-mingw.sh"
source "${ROOT_DIR}/ci/lib/winlator-runtime.sh"

log() { printf '[proton10] %s\n' "$*"; }
fail() { printf '[proton10][error] %s\n' "$*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

require_bool_flag() {
  local flag_name="$1" flag_value="$2"
  case "${flag_value}" in
    0|1) ;;
    *)
      fail "${flag_name} must be 0 or 1 (got: ${flag_value})"
      ;;
  esac
}

preflight_runtime_profile() {
  [[ -n "${WCP_TARGET_RUNTIME}" ]] || fail "WCP_TARGET_RUNTIME must not be empty"
  require_bool_flag WCP_PRUNE_EXTERNAL_COMPONENTS "${WCP_PRUNE_EXTERNAL_COMPONENTS}"
  require_bool_flag WCP_ENABLE_SDL2_RUNTIME "${WCP_ENABLE_SDL2_RUNTIME}"
}

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

fix_winebus_sdl_stub() {
  local bus_sdl_c
  bus_sdl_c="${WINE_SRC_DIR}/dlls/winebus.sys/bus_sdl.c"
  [[ -f "${bus_sdl_c}" ]] || fail "Missing ${bus_sdl_c}"

  # Some Proton patchsets call is_sdl_ignored_device() from bus_udev.c even when
  # SDL support is compiled out. Provide a fallback symbol in the #else stubs.
  perl -0pi -e 's/#else\n\nNTSTATUS sdl_bus_init\(void \*args\)/#else\n\nBOOL is_sdl_ignored_device(WORD vid, WORD pid)\n{\n    return FALSE;\n}\n\nNTSTATUS sdl_bus_init(void *args)/' "${bus_sdl_c}"
}

ensure_sdl2_tooling() {
  if [[ "${WCP_ENABLE_SDL2_RUNTIME}" != "1" ]]; then
    return
  fi

  require_cmd pkg-config
  pkg-config --exists sdl2 || fail "SDL2 development files are missing (pkg-config sdl2 failed)"
}

validate_sdl2_runtime_payload() {
  local winebus_module
  if [[ "${WCP_ENABLE_SDL2_RUNTIME}" != "1" ]]; then
    return
  fi

  winebus_module="${STAGE_DIR}/usr/lib/wine/aarch64-unix/winebus.sys.so"
  [[ -f "${winebus_module}" ]] || fail "SDL2 runtime check failed: missing ${winebus_module}"

  if ! readelf -d "${winebus_module}" | grep -Eiq 'NEEDED.*SDL2'; then
    fail "SDL2 runtime check failed: winebus.sys.so is not linked against SDL2"
  fi
  log "SDL2 runtime check passed (winebus.sys.so links against SDL2)"
}

build_wine() {
  local make_vulkan_log vk_xml video_xml

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
  validate_sdl2_runtime_payload
  [[ -f "config.log" ]] && cp -f "config.log" "${LOG_DIR}/wine-config.log"
  popd >/dev/null
}

prune_external_runtime_components() {
  local prune_log hit path
  if [[ "${WCP_PRUNE_EXTERNAL_COMPONENTS}" != "1" ]]; then
    : > "${LOG_DIR}/pruned-components.txt"
    log "External component pruning is disabled (WCP_PRUNE_EXTERNAL_COMPONENTS=0)"
    return
  fi

  prune_log="${LOG_DIR}/pruned-components.txt"
  : > "${prune_log}"

  # Winlator bionic typically provisions these as separate WCP content packages.
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

  hit=0
  for path in "${prune_paths[@]}"; do
    if [[ -e "${WCP_ROOT}/${path}" ]]; then
      rm -rf "${WCP_ROOT:?}/${path}"
      printf '%s\n' "${path}" >> "${prune_log}"
      hit=1
    fi
  done

  if [[ "${hit}" == "1" ]]; then
    log "Pruned external runtime payloads (see ${prune_log})"
  else
    log "No external runtime payloads matched prune list"
  fi
}

emit_runtime_diagnostics() {
  local report_txt report_json fex_ec fex_wow64

  report_txt="${LOG_DIR}/runtime-report.txt"
  report_json="${LOG_DIR}/runtime-report.json"
  fex_ec="${WCP_ROOT}/lib/wine/aarch64-windows/libarm64ecfex.dll"
  fex_wow64="${WCP_ROOT}/lib/wine/aarch64-windows/libwow64fex.dll"

  {
    echo "runtime_target=${WCP_TARGET_RUNTIME}"
    echo "prune_external_components=${WCP_PRUNE_EXTERNAL_COMPONENTS}"
    echo "enable_sdl2_runtime=${WCP_ENABLE_SDL2_RUNTIME}"
    echo "has_fex_arm64ec_dll=$([[ -f "${fex_ec}" ]] && echo 1 || echo 0)"
    echo "has_fex_wow64_dll=$([[ -f "${fex_wow64}" ]] && echo 1 || echo 0)"
    echo
    echo "container_startup_checklist:"
    echo "- use ARM64EC wine build in Winlator container settings"
    echo "- for ARM64EC containers set emulator to FEXCore (not Box64)"
    echo "- if startup still hangs, collect logs from docs/winlator-container-hang-debug.md"
    echo
    echo "pruned_entries:"
    if [[ -s "${LOG_DIR}/pruned-components.txt" ]]; then
      sed 's/^/- /' "${LOG_DIR}/pruned-components.txt"
    else
      echo "- none"
    fi
  } > "${report_txt}"

  cat > "${report_json}" <<EOF_REPORT
{
  "runtimeTarget": "${WCP_TARGET_RUNTIME}",
  "pruneExternalComponents": ${WCP_PRUNE_EXTERNAL_COMPONENTS},
  "enableSdl2Runtime": ${WCP_ENABLE_SDL2_RUNTIME},
  "hasFexArm64ecDll": $([[ -f "${fex_ec}" ]] && echo true || echo false),
  "hasFexWow64Dll": $([[ -f "${fex_wow64}" ]] && echo true || echo false),
  "diagnosticsDoc": "docs/winlator-container-hang-debug.md",
  "prunedListFile": "out/logs/pruned-components.txt"
}
EOF_REPORT
}

compose_wcp_tree() {
  local utc_now out_wcp

  rsync -a "${STAGE_DIR}/usr/" "${WCP_ROOT}/"
  [[ -f "${ROOT_DIR}/prefixPack.txz" ]] || fail "prefixPack.txz is required but missing in repository root"
  cp -f "${ROOT_DIR}/prefixPack.txz" "${WCP_ROOT}/prefixPack.txz"

  prune_external_runtime_components
  winlator_wrap_glibc_launchers

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
    for f in \
      "${WCP_ROOT}/bin/wine" \
      "${WCP_ROOT}/bin/wineserver" \
      "${WCP_ROOT}/bin/wine.glibc-real" \
      "${WCP_ROOT}/bin/wineserver.glibc-real"; do
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
  "runtime": {
    "target": "${WCP_TARGET_RUNTIME}",
    "sdl2Required": $([[ "${WCP_ENABLE_SDL2_RUNTIME}" == "1" ]] && echo true || echo false),
    "externalPayloadsManagedByHost": $([[ "${WCP_PRUNE_EXTERNAL_COMPONENTS}" == "1" ]] && echo true || echo false)
  },
  "built": "${utc_now}"
}
EOF_PROFILE

  [[ -f "${WCP_ROOT}/bin/wine" ]] || fail "Missing bin/wine after staging"
  [[ -f "${WCP_ROOT}/bin/wineserver" ]] || fail "Missing bin/wineserver after staging"
  [[ -d "${WCP_ROOT}/lib/wine" ]] || fail "Missing lib/wine after staging"
  [[ -d "${WCP_ROOT}/share" ]] || fail "Missing share after staging"

  if [[ "${WCP_ENABLE_SDL2_RUNTIME}" == "1" ]]; then
    [[ -f "${WCP_ROOT}/lib/wine/aarch64-unix/winebus.sys.so" ]] || fail "Missing lib/wine/aarch64-unix/winebus.sys.so in WCP root"
  fi

  winlator_validate_launchers
  emit_runtime_diagnostics

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
  require_cmd perl
  require_cmd pkg-config
  [[ -n "${TARGET_HOST}" ]] || fail "TARGET_HOST must be set"

  preflight_runtime_profile
  check_host_arch
  prepare_layout
  ensure_llvm_mingw
  run_arm64ec_flow
  apply_proton_ge_patches
  fix_winnt_interlocked_types
  fix_winebus_sdl_stub
  build_wine
  compose_wcp_tree
  bash "${ROOT_DIR}/ci/proton10/smoke-check-wcp.sh" "${OUT_DIR}/${WCP_NAME}.wcp" "${WCP_COMPRESS}"

  cp -f "${ROOT_DIR}/docs/ARM64EC_PATCH_REVIEW.md" "${LOG_DIR}/ARM64EC_PATCH_REVIEW.md"
  log "Build completed: ${OUT_DIR}/${WCP_NAME}.wcp"
}

main "$@"
