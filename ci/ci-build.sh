#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${WCP_OUTPUT_DIR:-${ROOT_DIR}/out}"
CACHE_DIR="${ROOT_DIR}/.cache"
LLVM_MINGW_DIR="${TOOLCHAIN_DIR:-${CACHE_DIR}/llvm-mingw}"
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
: "${WCP_NAME:=Wine-11.1-arm64ec}"
: "${WCP_COMPRESS:=zstd}"
: "${WCP_VERSION_NAME:=10-arm64ec}"
: "${WCP_VERSION_CODE:=0}"
: "${WCP_DESCRIPTION:=Proton 10 arm64ec for newer cmod versions}"
: "${FEX_SOURCE_MODE:=auto}"
: "${FEX_WCP_URL:=https://github.com/Arihany/WinlatorWCPHub/releases/download/FEXCore-Nightly/FEXCore-2601-260217-49a37c7.wcp}"

log() { printf '[ci] %s\n' "$*"; }
fail() { printf '[ci][error] %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

check_host_arch() {
  local arch
  arch="$(uname -m)"
  if [[ "${arch}" != "aarch64" && "${arch}" != "arm64" ]]; then
    fail "ARM64 host is required (aarch64/arm64). Current arch: ${arch}"
  fi
}

download_release_asset() {
  local repo="$1" tag="$2" regex="$3" output_file="$4"
  local api_url="https://api.github.com/repos/${repo}/releases/tags/${tag}"
  local asset_url

  log "Resolving asset from ${repo}@${tag} (${regex})"
  asset_url="$({
    curl -fsSL "${api_url}" | python3 -c '
import json, re, sys
pattern = re.compile(sys.argv[1])
release = json.load(sys.stdin)
for asset in release.get("assets", []):
    name = asset.get("name", "")
    if pattern.search(name):
        print(asset["browser_download_url"])
        raise SystemExit(0)
raise SystemExit("no matching release asset")
' "${regex}"
  })"

  curl -fL --retry 5 --retry-delay 2 -o "${output_file}" "${asset_url}"
}

ensure_llvm_mingw() {
  if [[ -d "${LLVM_MINGW_DIR}/bin" ]]; then
    log "Using cached llvm-mingw at ${LLVM_MINGW_DIR}"
    return
  fi

  local tmp_archive extracted
  mkdir -p "${CACHE_DIR}"
  tmp_archive="${CACHE_DIR}/llvm-mingw-${LLVM_MINGW_TAG}.tar.xz"

  download_release_asset \
    "mstorsjo/llvm-mingw" \
    "${LLVM_MINGW_TAG}" \
    "llvm-mingw-.*-ucrt-ubuntu-.*-(aarch64|arm64)\\.tar\\.xz$" \
    "${tmp_archive}"

  tar -xJf "${tmp_archive}" -C "${CACHE_DIR}"
  extracted="$(find "${CACHE_DIR}" -maxdepth 1 -type d -name 'llvm-mingw-*-ucrt-ubuntu-*' | head -n1)"
  [[ -n "${extracted}" ]] || fail "Unable to locate extracted llvm-mingw directory"

  rm -rf "${LLVM_MINGW_DIR}"
  mv "${extracted}" "${LLVM_MINGW_DIR}"
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
  rm -rf "${BUILD_WINE_DIR}" "${STAGE_DIR}"
  mkdir -p "${BUILD_WINE_DIR}" "${STAGE_DIR}"

  pushd "${BUILD_WINE_DIR}" >/dev/null
  "${WINE_SRC_DIR}/configure" \
    --prefix=/usr \
    --disable-tests \
    --with-mingw=clang \
    --enable-archs=arm64ec,aarch64,i386

  make -j"$(nproc)"
  make install DESTDIR="${STAGE_DIR}"
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
  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_TOOLCHAIN_FILE=../Data/CMake/toolchain_mingw.cmake \
    -DENABLE_LTO=False \
    -DMINGW_TRIPLE=arm64ec-w64-mingw32 \
    -DBUILD_TESTS=False \
    -DENABLE_TESTS=OFF \
    -DUNIT_TESTS=OFF \
    -DCMAKE_SHARED_LINKER_FLAGS="-lkernel32" \
    -DCMAKE_MODULE_LINKER_FLAGS="-lkernel32" \
    ..
  make -j"$(nproc)" arm64ecfex
  popd >/dev/null

  mkdir -p "${HANGOVER_SRC_DIR}/fex/build_pe"
  pushd "${HANGOVER_SRC_DIR}/fex/build_pe" >/dev/null
  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_TOOLCHAIN_FILE=../Data/CMake/toolchain_mingw.cmake \
    -DENABLE_LTO=False \
    -DMINGW_TRIPLE=aarch64-w64-mingw32 \
    -DBUILD_TESTS=False \
    -DENABLE_TESTS=OFF \
    -DUNIT_TESTS=OFF \
    ..
  make -j"$(nproc)" wow64fex
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

compose_wcp_tree() {
  rm -rf "${WCP_ROOT}"
  mkdir -p "${WCP_ROOT}"
  rsync -a "${STAGE_DIR}/usr/" "${WCP_ROOT}/"

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
    for f in "${WCP_ROOT}/bin/wine" "${WCP_ROOT}/bin/wineserver"; do
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

  if [[ -f "${ROOT_DIR}/prefixPack.txz" ]]; then
    cp -f "${ROOT_DIR}/prefixPack.txz" "${WCP_ROOT}/prefixPack.txz"
    log "included prefixPack.txz"
  else
    log "prefixPack.txz is missing, proceeding without bundled prefix"
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
  "files": [],
  "wine": {
    "binPath": "bin",
    "libPath": "lib",
    "prefixPack": "prefixPack.txz"
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

pack_wcp() {
  mkdir -p "${OUT_DIR}"
  local out_wcp
  out_wcp="${OUT_DIR}/${WCP_NAME}.wcp"

  pushd "${WCP_ROOT}" >/dev/null
  case "${WCP_COMPRESS}" in
    xz)
      tar -cJf "${out_wcp}" .
      ;;
    zstd)
      tar -cf - . | zstd -T0 -19 -o "${out_wcp}"
      ;;
    *)
      fail "WCP_COMPRESS must be xz or zstd"
      ;;
  esac
  popd >/dev/null

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
  if [[ "${WCP_COMPRESS}" == "zstd" ]]; then
    require_cmd zstd
  fi
  require_cmd file
  require_cmd readelf

  check_host_arch
  ensure_llvm_mingw
  ensure_arm64ec_api_set_compat

  export PATH="${LLVM_MINGW_DIR}/bin:${PATH}"
  log "clang: $(command -v clang)"
  log "ld.lld: $(command -v ld.lld || true)"

  fetch_wine_sources
  build_wine
  install_fex_dlls
  compose_wcp_tree
  pack_wcp
}

main "$@"
