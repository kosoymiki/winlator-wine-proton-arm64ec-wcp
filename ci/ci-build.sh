#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OUT_DIR="${ROOT}/out"
CACHE_DIR="${ROOT}/.cache"
LLVM_MINGW_DIR="${CACHE_DIR}/llvm-mingw"
STAGE_DIR="${ROOT}/stage"
WCP_ROOT="${ROOT}/wcp_root"

: "${WINE_REF:=wine-11.1}"
: "${LLVM_MINGW_TAG:=20260210}"
: "${WCP_NAME:=Wine-11.1-arm64ec}"
: "${WCP_COMPRESS:=zstd}"

mkdir -p "${OUT_DIR}" "${CACHE_DIR}"

ARCH="$(uname -m)"
if [[ "${ARCH}" != "aarch64" && "${ARCH}" != "arm64" ]]; then
  echo "ERROR: Этот пайплайн рассчитан на ARM64 runner (ubuntu-24.04-arm). Текущая arch: ${ARCH}" >&2
  exit 1
fi

download_release_asset() {
  local repo="$1" tag="$2" regex="$3" out="$4"
  local api="https://api.github.com/repos/${repo}/releases/tags/${tag}"

  echo "[dl] ${repo}@${tag}  (pattern: ${regex})"
  local url
  url="$(
    curl -fsSL "${api}" | python3 -c '
import json, re, sys
pat = re.compile(sys.argv[1])
j = json.load(sys.stdin)
for a in j.get("assets", []):
    name = a.get("name", "")
    if pat.search(name):
        print(a["browser_download_url"])
        sys.exit(0)
raise SystemExit("No asset matched")
' "${regex}"
  )"

  curl -fL --retry 5 --retry-delay 2 -o "${out}" "${url}"
}

if [[ ! -d "${LLVM_MINGW_DIR}/bin" ]]; then
  mkdir -p "${LLVM_MINGW_DIR}"
  TMP_TAR="${CACHE_DIR}/llvm-mingw.tar.xz"

  download_release_asset \
    "mstorsjo/llvm-mingw" \
    "${LLVM_MINGW_TAG}" \
    "llvm-mingw-.*-ucrt-ubuntu-.*-(aarch64|arm64)\\.tar\\.xz$" \
    "${TMP_TAR}"

  tar -xJf "${TMP_TAR}" -C "${CACHE_DIR}"
  EXTRACTED="$(find "${CACHE_DIR}" -maxdepth 1 -type d -name 'llvm-mingw-*-ucrt-ubuntu-*' | head -n1)"
  if [[ -z "${EXTRACTED}" ]]; then
    echo "ERROR: не нашёл распакованную директорию llvm-mingw" >&2
    exit 1
  fi
  rm -rf "${LLVM_MINGW_DIR}"
  mv "${EXTRACTED}" "${LLVM_MINGW_DIR}"
fi

export PATH="${LLVM_MINGW_DIR}/bin:${PATH}"

echo "[env] clang: $(command -v clang)"
echo "[env] lld:   $(command -v ld.lld || true)"

rm -rf wine-src
git clone --filter=blob:none https://github.com/AndreRH/wine.git wine-src
cd wine-src
git checkout arm64ec
git fetch --tags --force
git checkout "${WINE_REF}"
cd "${ROOT}"

rm -rf build-wine "${STAGE_DIR}"
mkdir -p build-wine "${STAGE_DIR}"
cd build-wine

../wine-src/configure \
  --prefix=/usr \
  --disable-tests \
  --with-mingw=clang \
  --enable-archs=arm64ec,aarch64,i386

make -j"$(nproc)"
make install DESTDIR="${STAGE_DIR}"

cd "${ROOT}"

rm -rf hangover-src
git clone --recursive --filter=blob:none https://github.com/AndreRH/hangover.git hangover-src

mkdir -p hangover-src/fex/build_ec
pushd hangover-src/fex/build_ec >/dev/null
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_TOOLCHAIN_FILE=../Data/CMake/toolchain_mingw.cmake \
  -DENABLE_LTO=False \
  -DMINGW_TRIPLE=arm64ec-w64-mingw32 \
  -DBUILD_TESTS=False \
  ..
make -j"$(nproc)" arm64ecfex
popd >/dev/null

mkdir -p hangover-src/fex/build_pe
pushd hangover-src/fex/build_pe >/dev/null
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_TOOLCHAIN_FILE=../Data/CMake/toolchain_mingw.cmake \
  -DENABLE_LTO=False \
  -DMINGW_TRIPLE=aarch64-w64-mingw32 \
  -DBUILD_TESTS=False \
  ..
make -j"$(nproc)" wow64fex
popd >/dev/null

mkdir -p "${STAGE_DIR}/usr/lib/wine/aarch64-windows"
cp -f hangover-src/fex/build_ec/Bin/libarm64ecfex.dll "${STAGE_DIR}/usr/lib/wine/aarch64-windows/"
cp -f hangover-src/fex/build_pe/Bin/libwow64fex.dll "${STAGE_DIR}/usr/lib/wine/aarch64-windows/"

rm -rf "${WCP_ROOT}"
mkdir -p "${WCP_ROOT}"

rsync -a "${STAGE_DIR}/usr/" "${WCP_ROOT}/"

if [[ -f "${WCP_ROOT}/bin/wine" && ! -e "${WCP_ROOT}/bin/wine64" ]]; then
  ln -s wine "${WCP_ROOT}/bin/wine64"
fi

mkdir -p "${WCP_ROOT}/winetools"
cat > "${WCP_ROOT}/winetools/manifest.txt" <<'EOF'
bin/wine
bin/wineserver
bin/winecfg
bin/regedit
bin/explorer
bin/msiexec
bin/notepad
EOF

cat > "${WCP_ROOT}/winetools/winetools.sh" <<'EOF'
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
EOF
chmod +x "${WCP_ROOT}/winetools/winetools.sh"

mkdir -p "${WCP_ROOT}/share/winetools"
{
  echo "== ELF (Unix launchers) =="
  for f in "${WCP_ROOT}/bin/wine" "${WCP_ROOT}/bin/wineserver"; do
    [ -e "$f" ] || continue
    echo "--- $f"
    file "$f" || true
    readelf -d "$f" 2>/dev/null | sed -n '1,120p' || true
  done
  echo
  echo "== PE (FEX WoA DLL) =="
  for f in "${WCP_ROOT}/lib/wine/aarch64-windows/libarm64ecfex.dll" "${WCP_ROOT}/lib/wine/aarch64-windows/libwow64fex.dll"; do
    [ -e "$f" ] || continue
    echo "--- $f"
    file "$f" || true
  done
} > "${WCP_ROOT}/share/winetools/linking-report.txt"

if [[ -f "${ROOT}/prefixPack.txz" ]]; then
  cp -f "${ROOT}/prefixPack.txz" "${WCP_ROOT}/prefixPack.txz"
  echo "[ok] included prefixPack.txz"
else
  echo "[warn] prefixPack.txz not found in repository root; building WCP without bundled prefix pack" >&2
fi

UTC_NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > "${WCP_ROOT}/profile.json" <<EOF
{
  "name": "Wine 11.1 ARM64EC",
  "version": "11.1-arm64ec",
  "built_utc": "${UTC_NOW}",
  "features": ["wow64", "arm64ec", "fex"],
  "notes": "profile.json is required by WCP. Adjust runtime settings for your Winlator fork here."
}
EOF

mkdir -p "${WCP_ROOT}/info"
cat > "${WCP_ROOT}/info/info.json" <<EOF
{
  "name": "Wine 11.1 ARM64EC",
  "os": "windows",
  "arch": "arm64",
  "version": "11.1-arm64ec",
  "features": ["wow64", "arm64ec", "fex"],
  "built": "${UTC_NOW}"
}
EOF

cd "${WCP_ROOT}"
OUT_WCP="${OUT_DIR}/${WCP_NAME}.wcp"

if [[ "${WCP_COMPRESS}" == "xz" ]]; then
  tar -cJf "${OUT_WCP}" .
elif [[ "${WCP_COMPRESS}" == "zstd" ]]; then
  tar -cf - . | zstd -T0 -19 -o "${OUT_WCP}"
else
  echo "ERROR: WCP_COMPRESS must be xz or zstd" >&2
  exit 2
fi

echo "[ok] built: ${OUT_WCP}"
ls -lh "${OUT_WCP}"
