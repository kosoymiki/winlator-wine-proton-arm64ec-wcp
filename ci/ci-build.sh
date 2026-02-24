#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${WCP_OUTPUT_DIR:-${ROOT_DIR}/out/wine}"
CACHE_DIR="${ROOT_DIR}/.cache"
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-${CACHE_DIR}/llvm-mingw}"
LLVM_MINGW_DIR="${TOOLCHAIN_DIR}"
STAGE_DIR="${ROOT_DIR}/stage"
WCP_ROOT="${ROOT_DIR}/wcp_root"
WINE_SRC_DIR="${ROOT_DIR}/wine-src"
HANGOVER_SRC_DIR="${ROOT_DIR}/hangover-src"
BUILD_WINE_DIR="${ROOT_DIR}/build-wine"

: "${WINE_REPO:=https://github.com/AndreRH/wine.git}"
: "${WINE_BRANCH:=arm64ec}"
: "${WINE_REF:=arm64ec}"
: "${HANGOVER_REPO:=https://github.com/AndreRH/hangover.git}"
: "${LLVM_MINGW_TAG:=${LLVM_MINGW_VER:-20260210}}"
: "${WCP_NAME:=wine-11-arm64ec}"
: "${WCP_COMPRESS:=xz}"
: "${WCP_VERSION_NAME:=11-arm64ec}"
: "${WCP_VERSION_CODE:=0}"
: "${WCP_DESCRIPTION:=Wine 11 arm64ec for newer cmod versions}"
: "${WCP_CHANNEL:=stable}"
: "${WCP_DELIVERY:=remote}"
: "${WCP_DISPLAY_CATEGORY:=Wine/Proton}"
: "${WCP_SOURCE_REPO:=${GITHUB_REPOSITORY:-kosoymiki/winlator-wine-proton-arm64ec-wcp}}"
: "${WCP_RELEASE_TAG:=wcp-latest}"
: "${TARGET_HOST:=aarch64-linux-gnu}"
: "${FEX_SOURCE_MODE:=auto}"
: "${FEX_WCP_URL:=https://github.com/Arihany/WinlatorWCPHub/releases/download/FEXCore-Nightly/FEXCore-2601-260217-49a37c7.wcp}"
: "${REQUIRE_PREFIX_PACK:=1}"
: "${FEX_BUILD_TYPE:=Release}"
: "${STRIP_STAGE:=1}"
: "${WCP_ENABLE_SDL2_RUNTIME:=1}"
: "${WCP_TARGET_RUNTIME:=winlator-bionic}"
: "${WCP_GLIBC_SOURCE_MODE:=pinned-source}"
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

log() { printf '[ci] %s\n' "$*"; }
fail() { printf '[ci][error] %s\n' "$*" >&2; exit 1; }

source "${ROOT_DIR}/ci/lib/wcp_common.sh"

wine_make_jobs() {
  printf '%s' "${WCP_WINE_BUILD_JOBS:-${WCP_BUILD_JOBS:-$(nproc)}}"
}

fex_make_jobs() {
  printf '%s' "${WCP_FEX_BUILD_JOBS:-${WCP_BUILD_JOBS:-$(nproc)}}"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_bool_flag() {
  local flag_name="$1" flag_value="$2"
  case "${flag_value}" in
    0|1) ;;
    *)
      fail "${flag_name} must be 0 or 1 (got: ${flag_value})"
      ;;
  esac
}

check_host_arch() {
  local arch
  arch="$(uname -m)"
  if [[ "${arch}" != "aarch64" && "${arch}" != "arm64" ]]; then
    fail "ARM64 host is required (aarch64/arm64). Current arch: ${arch}"
  fi
}

fetch_wine_sources() {
  rm -rf "${WINE_SRC_DIR}"
  git clone --filter=blob:none --branch "${WINE_BRANCH}" --single-branch "${WINE_REPO}" "${WINE_SRC_DIR}"
  pushd "${WINE_SRC_DIR}" >/dev/null
  git fetch --tags --force

  # Strict default: build from arm64ec branch. If WINE_REF is provided, use it only
  # when the ref exists in origin (branch/tag/commit).
  if [[ "${WINE_REF}" == "${WINE_BRANCH}" ]]; then
    git checkout "${WINE_BRANCH}"
  elif git rev-parse --verify --quiet "refs/remotes/origin/${WINE_REF}" >/dev/null; then
    git checkout -B "${WINE_REF}" "refs/remotes/origin/${WINE_REF}"
  elif git rev-parse --verify --quiet "refs/tags/${WINE_REF}" >/dev/null; then
    git checkout "refs/tags/${WINE_REF}"
  elif git rev-parse --verify --quiet "${WINE_REF}^{commit}" >/dev/null; then
    git checkout "${WINE_REF}"
  else
    fail "WINE_REF '${WINE_REF}' not found in ${WINE_REPO}. Use arm64ec branch or a valid ref."
  fi

  popd >/dev/null
}

build_wine() {
  local make_vulkan_log

  ensure_sdl2_tooling
  export TARGET_HOST
  # Guarantee prefixPack is available for downstream packaging/validation.
  ensure_prefix_pack "${ROOT_DIR}/prefixPack.txz"

  wcp_ensure_configure_script "${WINE_SRC_DIR}"
  make_vulkan_log="${OUT_DIR}/logs/make_vulkan.log"
  wcp_try_bootstrap_winevulkan "${WINE_SRC_DIR}" "${make_vulkan_log}"

  rm -rf "${BUILD_WINE_DIR}" "${STAGE_DIR}"
  mkdir -p "${BUILD_WINE_DIR}" "${STAGE_DIR}"

  pushd "${BUILD_WINE_DIR}" >/dev/null
  "${WINE_SRC_DIR}/configure" \
    --prefix=/usr \
    --disable-tests \
    --with-mingw=clang \
    --enable-archs=arm64ec,aarch64,i386

  if [[ -f config.log ]] && ! grep -Eq 'arm64ec' config.log; then
    fail "configure did not include ARM64EC target support"
  fi

  make -j"$(wine_make_jobs)"
  make install DESTDIR="${STAGE_DIR}"
  validate_sdl2_runtime_payload
  popd >/dev/null
}


ensure_arm64ec_api_set_compat() {
  # Some llvm-mingw releases miss libapi-ms-win-core-processthreads-l1-1-3.a,
  # while upstream build files may still request it indirectly.
  local libdir compat target candidate
  for libdir in \
    "${LLVM_MINGW_DIR}/arm64ec-w64-mingw32/lib" \
    "${LLVM_MINGW_DIR}/aarch64-w64-mingw32/lib"; do
    [[ -d "${libdir}" ]] || continue

    compat="${libdir}/libapi-ms-win-core-processthreads-l1-1-3.a"
    [[ -e "${compat}" ]] && continue

    target=""
    for candidate in \
      "${libdir}/libapi-ms-win-core-processthreads-l1-1-4.a" \
      "${libdir}/libapi-ms-win-core-processthreads-l1-1-2.a" \
      "${libdir}/libapi-ms-win-core-processthreads-l1-1-1.a" \
      "${libdir}/libkernel32.a"; do
      if [[ -e "${candidate}" ]]; then
        target="${candidate}"
        break
      fi
    done

    if [[ -n "${target}" ]]; then
      ln -s "$(basename "${target}")" "${compat}" || true
      log "Created API-set compatibility alias: ${compat} -> $(basename "${target}")"
    fi
  done
}

build_fex_dlls() {
  rm -rf "${HANGOVER_SRC_DIR}"
  git clone --recursive --filter=blob:none "${HANGOVER_REPO}" "${HANGOVER_SRC_DIR}"

  mkdir -p "${HANGOVER_SRC_DIR}/fex/build_ec"
  pushd "${HANGOVER_SRC_DIR}/fex/build_ec" >/dev/null
  # Keep ARM64EC link flags minimal; api-ms import lib may be absent in some llvm-mingw builds.
  cmake -DCMAKE_BUILD_TYPE="${FEX_BUILD_TYPE}" \
    -DCMAKE_TOOLCHAIN_FILE=../Data/CMake/toolchain_mingw.cmake \
    -DENABLE_LTO=False \
    -DMINGW_TRIPLE=arm64ec-w64-mingw32 \
    -DBUILD_TESTS=False \
    -DENABLE_TESTS=OFF \
    -DUNIT_TESTS=OFF \
    -DCMAKE_SHARED_LINKER_FLAGS="-lkernel32" \
    -DCMAKE_MODULE_LINKER_FLAGS="-lkernel32" \
    ..
  make -j"$(fex_make_jobs)" arm64ecfex
  popd >/dev/null

  mkdir -p "${HANGOVER_SRC_DIR}/fex/build_pe"
  pushd "${HANGOVER_SRC_DIR}/fex/build_pe" >/dev/null
  cmake -DCMAKE_BUILD_TYPE="${FEX_BUILD_TYPE}" \
    -DCMAKE_TOOLCHAIN_FILE=../Data/CMake/toolchain_mingw.cmake \
    -DENABLE_LTO=False \
    -DMINGW_TRIPLE=aarch64-w64-mingw32 \
    -DBUILD_TESTS=False \
    -DENABLE_TESTS=OFF \
    -DUNIT_TESTS=OFF \
    ..
  make -j"$(fex_make_jobs)" wow64fex
  popd >/dev/null

  mkdir -p "${STAGE_DIR}/usr/lib/wine/aarch64-windows"
  cp -f "${HANGOVER_SRC_DIR}/fex/build_ec/Bin/libarm64ecfex.dll" "${STAGE_DIR}/usr/lib/wine/aarch64-windows/"
  cp -f "${HANGOVER_SRC_DIR}/fex/build_pe/Bin/libwow64fex.dll" "${STAGE_DIR}/usr/lib/wine/aarch64-windows/"
}

extract_fex_dlls_from_prebuilt_wcp() {
  local tmp_root archive dll_ec dll_pe
  tmp_root="${CACHE_DIR}/prebuilt-fex"
  archive="${tmp_root}/fexcore.wcp"

  rm -rf "${tmp_root}"
  mkdir -p "${tmp_root}/extract"
  log "Downloading prebuilt FEX package: ${FEX_WCP_URL}"
  curl -fL --retry 5 --retry-delay 2 -o "${archive}" "${FEX_WCP_URL}"

  if tar --zstd -xf "${archive}" -C "${tmp_root}/extract" >/dev/null 2>&1; then
    :
  elif tar -xJf "${archive}" -C "${tmp_root}/extract" >/dev/null 2>&1; then
    :
  elif tar -xf "${archive}" -C "${tmp_root}/extract" >/dev/null 2>&1; then
    :
  else
    fail "Unable to extract prebuilt FEX package: ${archive}"
  fi

  dll_ec="$(find "${tmp_root}/extract" -type f -name 'libarm64ecfex.dll' | head -n1 || true)"
  dll_pe="$(find "${tmp_root}/extract" -type f -name 'libwow64fex.dll' | head -n1 || true)"

  [[ -n "${dll_ec}" ]] || fail "libarm64ecfex.dll not found in prebuilt FEX package"
  [[ -n "${dll_pe}" ]] || fail "libwow64fex.dll not found in prebuilt FEX package"

  mkdir -p "${STAGE_DIR}/usr/lib/wine/aarch64-windows"
  cp -f "${dll_ec}" "${STAGE_DIR}/usr/lib/wine/aarch64-windows/libarm64ecfex.dll"
  cp -f "${dll_pe}" "${STAGE_DIR}/usr/lib/wine/aarch64-windows/libwow64fex.dll"
  log "Using prebuilt FEX DLLs from ${FEX_WCP_URL}"
}

install_fex_dlls() {
  case "${FEX_SOURCE_MODE}" in
    prebuilt)
      extract_fex_dlls_from_prebuilt_wcp
      ;;
    build)
      build_fex_dlls
      ;;
    auto)
      if ! extract_fex_dlls_from_prebuilt_wcp; then
        log "Prebuilt FEX package failed, falling back to local FEX build"
        build_fex_dlls
      fi
      ;;
    *)
      fail "FEX_SOURCE_MODE must be one of: auto, prebuilt, build"
      ;;
  esac
}

ensure_sdl2_tooling() {
  if [[ "${WCP_ENABLE_SDL2_RUNTIME}" != "1" ]]; then
    return
  fi

  require_cmd pkg-config
  pkg-config --exists sdl2 || fail "SDL2 development files are missing (pkg-config sdl2 failed)"
}

validate_sdl2_runtime_payload() {
  local winebus_module winebus_module_dir strings_cmd
  if [[ "${WCP_ENABLE_SDL2_RUNTIME}" != "1" ]]; then
    return
  fi

  winebus_module_dir="${STAGE_DIR}/usr/lib/wine/aarch64-unix"
  if [[ -f "${winebus_module_dir}/winebus.so" ]]; then
    winebus_module="${winebus_module_dir}/winebus.so"
  elif [[ -f "${winebus_module_dir}/winebus.sys.so" ]]; then
    winebus_module="${winebus_module_dir}/winebus.sys.so"
  else
    fail "SDL2 runtime check failed: missing ${winebus_module_dir}/winebus.so (or winebus.sys.so)"
  fi

  if readelf -d "${winebus_module}" | grep -Eiq 'NEEDED.*SDL2'; then
    log "SDL2 runtime check passed ($(basename "${winebus_module}") links against SDL2)"
    return
  fi

  strings_cmd="$(command -v strings || command -v llvm-strings || true)"
  if [[ -n "${strings_cmd}" ]] && "${strings_cmd}" -a "${winebus_module}" | grep -Eiq 'libSDL2(-2\\.0)?\\.so'; then
    log "SDL2 runtime check passed ($(basename "${winebus_module}") references SDL2 SONAME)"
    return
  fi

  log "SDL2 runtime probe is inconclusive for $(basename "${winebus_module}") (no direct linkage/SONAME); continuing with module-present validation"
}


strip_stage_payload() {
  [[ "${STRIP_STAGE}" == "1" ]] || return

  local strip_cmd
  strip_cmd="$(command -v llvm-strip || command -v strip || true)"
  [[ -n "${strip_cmd}" ]] || { log "No strip tool found, skipping payload stripping"; return; }

  log "Stripping ELF payload to reduce runtime memory/storage footprint (${strip_cmd})"
  while IFS= read -r -d '' f; do
    if file -b "${f}" | grep -q '^ELF '; then
      "${strip_cmd}" --strip-unneeded "${f}" >/dev/null 2>&1 || true
    fi
  done < <(find "${STAGE_DIR}/usr" -type f -print0)
}

compose_wcp_tree() {
  rm -rf "${WCP_ROOT}"
  mkdir -p "${WCP_ROOT}"
  rsync -a "${STAGE_DIR}/usr/" "${WCP_ROOT}/"
  winlator_wrap_glibc_launchers

  if [[ -f "${WCP_ROOT}/bin/wine" && ! -e "${WCP_ROOT}/bin/wine64" ]]; then
    ln -s wine "${WCP_ROOT}/bin/wine64"
  fi

  mkdir -p "${WCP_ROOT}/winetools"
  cat > "${WCP_ROOT}/winetools/manifest.txt" <<'MANIFEST'
bin/wine
bin/wineserver
bin/winecfg
bin/regedit
bin/explorer
bin/msiexec
bin/notepad
MANIFEST

  cat > "${WCP_ROOT}/winetools/winetools.sh" <<'WINETOOLS'
#!/usr/bin/env sh
set -eu

cmd="${1:-info}"
case "$cmd" in
  list)
    sed -n 's/^/ - /p' "$(dirname "$0")/manifest.txt"
    ;;
  run)
    tool="${2:-}"
    [ -n "$tool" ] || { echo "usage: winetools.sh run <tool> [args...]"; exit 2; }
    shift 2
    exec "/usr/bin/${tool}" "$@"
    ;;
  info|*)
    echo "Winlator WCP winetools layer"
    echo "Available tools:"
    sed -n 's|^bin/||p' "$(dirname "$0")/manifest.txt"
    ;;
esac
WINETOOLS
  chmod +x "${WCP_ROOT}/winetools/winetools.sh"

  mkdir -p "${WCP_ROOT}/share/winetools"
  {
    echo "== ELF (Unix launchers) =="
    for f in \
      "${WCP_ROOT}/bin/wine" \
      "${WCP_ROOT}/bin/wineserver" \
      "${WCP_ROOT}/bin/wine.glibc-real" \
      "${WCP_ROOT}/bin/wineserver.glibc-real"; do
      [[ -e "$f" ]] || continue
      echo "--- $f"
      file "$f" || true
      readelf -d "$f" 2>/dev/null | sed -n '1,120p' || true
    done
    echo
    echo "== PE (FEX WoA DLL) =="
    for f in "${WCP_ROOT}/lib/wine/aarch64-windows/libarm64ecfex.dll" "${WCP_ROOT}/lib/wine/aarch64-windows/libwow64fex.dll"; do
      [[ -e "$f" ]] || continue
      echo "--- $f"
      file "$f" || true
    done
  } > "${WCP_ROOT}/share/winetools/linking-report.txt"

  local has_prefix_pack="0"
  # Attempt to download if missing; fallback honors REQUIRE_PREFIX_PACK flag.
  ensure_prefix_pack "${ROOT_DIR}/prefixPack.txz"
  if [[ -f "${ROOT_DIR}/prefixPack.txz" ]]; then
    cp -f "${ROOT_DIR}/prefixPack.txz" "${WCP_ROOT}/prefixPack.txz"
    log "included prefixPack.txz"
    has_prefix_pack="1"
  elif [[ "${REQUIRE_PREFIX_PACK}" == "1" ]]; then
    fail "prefixPack.txz is required but missing in repository root"
  else
    log "prefixPack.txz is missing, proceeding without bundled prefix (REQUIRE_PREFIX_PACK=0)"
  fi

  local utc_now
  utc_now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  mkdir -p "${WCP_ROOT}/info"
  cat > "${WCP_ROOT}/profile.json" <<EOF_PROFILE
{
  "type": "Wine",
  "versionName": "${WCP_VERSION_NAME}",
  "versionCode": ${WCP_VERSION_CODE},
  "description": "${WCP_DESCRIPTION}",
  "channel": "${WCP_CHANNEL}",
  "delivery": "${WCP_DELIVERY}",
  "displayCategory": "${WCP_DISPLAY_CATEGORY}",
  "sourceRepo": "${WCP_SOURCE_REPO}",
  "releaseTag": "${WCP_RELEASE_TAG}",
  "files": [],
  "wine": {
    "binPath": "bin",
    "libPath": "lib"$(
      if [[ "${has_prefix_pack}" == "1" ]]; then
        printf ',\n    "prefixPack": "prefixPack.txz"'
      fi
    )
  },
  "runtime": {
    "target": "$(printf '%s' "${WCP_TARGET_RUNTIME}" | sed 's/"/\\"/g')",
    "fexExpectationMode": "$(printf '%s' "${WCP_FEX_EXPECTATION_MODE}" | sed 's/"/\\"/g')",
    "fexBundledInWcp": ${WCP_INCLUDE_FEX_DLLS}
  }
}
EOF_PROFILE

  cat > "${WCP_ROOT}/info/info.json" <<EOF_INFO
{
  "name": "${WCP_NAME}",
  "type": "Wine",
  "version": "${WCP_VERSION_NAME}",
  "versionCode": ${WCP_VERSION_CODE},
  "description": "${WCP_DESCRIPTION}",
  "built": "${utc_now}"
}
EOF_INFO
}


validate_wcp_tree() {
  local required_paths=(
    "${WCP_ROOT}/bin"
    "${WCP_ROOT}/bin/wine"
    "${WCP_ROOT}/bin/wineserver"
    "${WCP_ROOT}/lib"
    "${WCP_ROOT}/lib/wine"
    "${WCP_ROOT}/lib/wine/aarch64-unix"
    "${WCP_ROOT}/lib/wine/aarch64-windows"
    "${WCP_ROOT}/lib/wine/i386-windows"
    "${WCP_ROOT}/share"
    "${WCP_ROOT}/profile.json"
  )
  if [[ "${WCP_FEX_EXPECTATION_MODE}" == "bundled" ]]; then
    required_paths+=(
      "${WCP_ROOT}/lib/wine/aarch64-windows/libarm64ecfex.dll"
      "${WCP_ROOT}/lib/wine/aarch64-windows/libwow64fex.dll"
    )
  fi

  local p
  for p in "${required_paths[@]}"; do
    [[ -e "${p}" ]] || fail "WCP layout is incomplete, missing: ${p#${WCP_ROOT}/}"
  done

  local required_unix_modules=(
    "ntdll.so"
    "win32u.so"
    "ws2_32.so"
    "opengl32.so"
    "secur32.so"
    "winevulkan.so"
  )

  if [[ "${WCP_ENABLE_SDL2_RUNTIME}" == "1" ]]; then
    if [[ -f "${WCP_ROOT}/lib/wine/aarch64-unix/winebus.so" ]]; then
      required_unix_modules+=("winebus.so")
    elif [[ -f "${WCP_ROOT}/lib/wine/aarch64-unix/winebus.sys.so" ]]; then
      required_unix_modules+=("winebus.sys.so")
    else
      fail "Wine unix module missing: lib/wine/aarch64-unix/winebus.so (or winebus.sys.so)"
    fi
  fi

  local mod
  for mod in "${required_unix_modules[@]}"; do
    [[ -f "${WCP_ROOT}/lib/wine/aarch64-unix/${mod}" ]] || fail "Wine unix module missing: lib/wine/aarch64-unix/${mod}"
  done

  if [[ "${REQUIRE_PREFIX_PACK}" == "1" ]]; then
    [[ -f "${WCP_ROOT}/prefixPack.txz" ]] || fail "WCP layout is incomplete, missing: prefixPack.txz"
  fi

  winlator_validate_launchers
  wcp_validate_forensic_manifest "${WCP_ROOT}"
  log "WCP layout validation passed"
}

pack_wcp() {
  mkdir -p "${OUT_DIR}"
  local out_wcp
  out_wcp="${OUT_DIR}/${WCP_NAME}.wcp"

  pushd "${WCP_ROOT}" >/dev/null
  case "${WCP_COMPRESS}" in
    xz)
      tar -cJf "${out_wcp}" .
      ;;
    zst|zstd)
      tar --zstd -cf "${out_wcp}" .
      ;;
    *)
      fail "WCP_COMPRESS must be xz or zst"
      ;;
  esac
  popd >/dev/null

  case "${WCP_COMPRESS}" in
    xz)
      tar -tJf "${out_wcp}" >/dev/null || fail "Packed WCP is not a valid xz tar archive"
      ;;
    zst|zstd)
      tar --zstd -tf "${out_wcp}" >/dev/null || fail "Packed WCP is not a valid zstd tar archive"
      ;;
  esac

  log "built artifact: ${out_wcp}"
  ls -lh "${out_wcp}"
}

main() {
  cd "${ROOT_DIR}"

  require_cmd curl
  require_cmd git
  require_cmd python3
  require_cmd cmake
  require_cmd make
  require_cmd tar
  require_cmd rsync
  if [[ "${WCP_COMPRESS}" == "zstd" || "${WCP_COMPRESS}" == "zst" ]]; then
    require_cmd zstd
  fi
  require_cmd file
  require_cmd readelf
  require_cmd pkg-config

  require_bool_flag WCP_ENABLE_SDL2_RUNTIME "${WCP_ENABLE_SDL2_RUNTIME}"
  require_bool_flag WCP_INCLUDE_FEX_DLLS "${WCP_INCLUDE_FEX_DLLS}"
  wcp_require_enum WCP_FEX_EXPECTATION_MODE "${WCP_FEX_EXPECTATION_MODE}" external bundled
  wcp_require_enum WCP_RUNTIME_BUNDLE_LOCK_MODE "${WCP_RUNTIME_BUNDLE_LOCK_MODE}" audit enforce relaxed-enforce
  case "${WCP_FEX_EXPECTATION_MODE}" in
    external|bundled) ;;
    *) fail "WCP_FEX_EXPECTATION_MODE must be external or bundled" ;;
  esac
  wcp_validate_winlator_profile_identifier "${WCP_VERSION_NAME}" "${WCP_VERSION_CODE}"

  check_host_arch
  ensure_llvm_mingw
  ensure_arm64ec_api_set_compat

  export PATH="${LLVM_MINGW_DIR}/bin:${PATH}"
  log "clang: $(command -v clang)"
  log "ld.lld: $(command -v ld.lld || true)"
  clang --version | sed -n '1,2p'
  ld.lld --version | sed -n '1,2p'

  fetch_wine_sources
  build_wine
  if [[ "${WCP_INCLUDE_FEX_DLLS}" == "1" ]]; then
    install_fex_dlls
  else
    log "Skipping FEX DLL embedding (WCP_INCLUDE_FEX_DLLS=0, mode=${WCP_FEX_EXPECTATION_MODE})"
  fi
  strip_stage_payload
  compose_wcp_tree
  wcp_write_forensic_manifest "${WCP_ROOT}"
  validate_wcp_tree
  pack_wcp
  smoke_check_wcp "${OUT_DIR}/${WCP_NAME}.wcp" "${WCP_COMPRESS}"
}

main "$@"
