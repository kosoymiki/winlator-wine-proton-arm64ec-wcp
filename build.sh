#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

: "${LLVM_MINGW_VER:=20251216}"
: "${LLVM_VER:=22.1.0-rc3}"
: "${WCP_NAME:=wine-11.1-arm64ec}"
: "${WCP_OUTPUT_DIR:=$ROOT/dist}"
: "${TOOLCHAIN_DIR:=$ROOT/.cache}"
: "${WINE_SRC_DIR:=$ROOT/wine-src}"
: "${WINE_GIT_URL:=https://github.com/AndreRH/wine.git}"
: "${WINE_GIT_REF:=arm64ec}"
: "${WINE_JOBS:=$(nproc)}"
: "${BUILD_TRIPLE:=x86_64-linux-gnu}"
: "${CROSS_PREFIX_ARM64EC:=arm64ec-w64-windows-gnu}"
: "${CROSS_PREFIX_AARCH64:=aarch64-w64-mingw32}"
: "${CROSS_PREFIX_I386:=i686-w64-mingw32}"
: "${PREFIX_PACK_PATH:=$ROOT/prefixPack.txz}"
: "${PROFILE_PATH:=$ROOT/profile.json}"
: "${FEX_ARM64_DIR:=}"
: "${FEX_WOW64_DIR:=}"
: "${SKIP_FEX_BUILD:=1}"

mkdir -p "$WCP_OUTPUT_DIR" "$TOOLCHAIN_DIR"

LLVM_MINGW_DIR="$TOOLCHAIN_DIR/llvm-mingw-${LLVM_MINGW_VER}"
LLVM_MINGW_BIN="$LLVM_MINGW_DIR/bin"
LLVM22_DIR="$TOOLCHAIN_DIR/LLVM-${LLVM_VER}-Linux-X64"
LLVM22_BIN="$LLVM22_DIR/bin"

install_llvm_mingw() {
  local tar_name="llvm-mingw-${LLVM_MINGW_VER}-ucrt-ubuntu-22.04-x86_64.tar.xz"
  local url="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW_VER}/${tar_name}"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  wget --https-only --tries=3 --timeout=60 -O "$tmpdir/$tar_name" "$url"
  tar -xf "$tmpdir/$tar_name" -C "$tmpdir"

  rm -rf "$LLVM_MINGW_DIR"
  mv "$tmpdir/llvm-mingw-${LLVM_MINGW_VER}-ucrt-ubuntu-22.04-x86_64" "$LLVM_MINGW_DIR"
}

install_llvm22() {
  local tar_name="LLVM-${LLVM_VER}-Linux-X64.tar.xz"
  local url="https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/${tar_name}"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  wget --https-only --tries=3 --timeout=60 -O "$tmpdir/$tar_name" "$url"
  tar -xf "$tmpdir/$tar_name" -C "$TOOLCHAIN_DIR"
}

if [[ ! -x "$LLVM_MINGW_BIN/clang" ]]; then
  install_llvm_mingw
fi
if [[ ! -x "$LLVM22_BIN/clang" ]]; then
  install_llvm22
fi

export PATH="$LLVM22_BIN:$LLVM_MINGW_BIN:$PATH"

if [[ ! -d "$WINE_SRC_DIR/.git" ]]; then
  git clone --depth=1 --branch "$WINE_GIT_REF" "$WINE_GIT_URL" "$WINE_SRC_DIR"
fi

pushd "$WINE_SRC_DIR" >/dev/null
git fetch --depth=1 origin "$WINE_GIT_REF" || true
git checkout "$WINE_GIT_REF" || git checkout -B "$WINE_GIT_REF" "origin/$WINE_GIT_REF"
popd >/dev/null

export CC="clang"
export CXX="clang++"
export AR="llvm-ar"
export RANLIB="llvm-ranlib"
export STRIP="llvm-strip"
export CFLAGS="-O2 -march=armv9-a -mcpu=cortex-x2 -pipe"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-fuse-ld=lld"

BUILD_TOOLS="$ROOT/build-tools"
BUILD_WINE="$ROOT/build-arm64ec"
BUILD_FEX_ARM64="$ROOT/build-fex-arm64ec"
BUILD_FEX_WOW64="$ROOT/build-fex-wow64"
STAGE="$ROOT/stage-arm64ec"
TOOLS_INSTALL="$ROOT/wine-tools-install"
WCP_ROOT="$ROOT/wcp"

rm -rf "$BUILD_TOOLS" "$BUILD_WINE" "$STAGE" "$TOOLS_INSTALL" "$WCP_ROOT"
mkdir -p "$BUILD_TOOLS" "$BUILD_WINE" "$STAGE" "$WCP_ROOT"

pushd "$BUILD_TOOLS" >/dev/null
"$WINE_SRC_DIR/configure" \
  --build="$BUILD_TRIPLE" \
  --enable-win64 \
  --disable-tests \
  --prefix="$TOOLS_INSTALL"
make -j"$WINE_JOBS"
make install
popd >/dev/null

pushd "$BUILD_WINE" >/dev/null
"$WINE_SRC_DIR/configure" \
  --build="$BUILD_TRIPLE" \
  --host="$CROSS_PREFIX_ARM64EC" \
  --with-wine-tools="$TOOLS_INSTALL" \
  --with-mingw=clang \
  --enable-archs=arm64ec,aarch64,i386 \
  --disable-tests \
  --prefix=/usr
make -j"$WINE_JOBS"
make install DESTDIR="$STAGE"
popd >/dev/null

if [[ "$SKIP_FEX_BUILD" != "1" ]]; then
  if [[ -z "$FEX_ARM64_DIR" || -z "$FEX_WOW64_DIR" ]]; then
    echo "SKIP_FEX_BUILD=0 requires FEX_ARM64_DIR and FEX_WOW64_DIR" >&2
    exit 1
  fi
fi

install -d "$WCP_ROOT"
cp -a "$STAGE/usr/." "$WCP_ROOT/"

if [[ -x "$WCP_ROOT/bin/wine" && ! -e "$WCP_ROOT/bin/wine64" ]]; then
  ln -s wine "$WCP_ROOT/bin/wine64"
fi

install -d "$WCP_ROOT/share/winetools" "$WCP_ROOT/info"

cat > "$WCP_ROOT/bin/winetools" <<'EOF_WINETOOLS'
#!/usr/bin/env bash
set -Eeuo pipefail
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SELF_DIR}/../share/winetools/manifest.txt"

cmd="${1:-list}"
case "$cmd" in
  list)
    cat "$MANIFEST"
    ;;
  run)
    tool="${2:-}"
    shift 2 || true
    exec "${SELF_DIR}/${tool}" "$@"
    ;;
  info)
    printf 'manifest=%s\n' "${SELF_DIR}/../share/winetools/manifest.txt"
    printf 'linking=%s\n' "${SELF_DIR}/../share/winetools/linking-report.txt"
    ;;
  *)
    echo "Usage: winetools {list|run <tool>|info}" >&2
    exit 2
    ;;
esac
EOF_WINETOOLS
chmod +x "$WCP_ROOT/bin/winetools"

manifest="$WCP_ROOT/share/winetools/manifest.txt"
: > "$manifest"
for tool in wine wineserver winecfg regedit explorer msiexec notepad; do
  [[ -x "$WCP_ROOT/bin/$tool" ]] && echo "$tool" >> "$manifest"
done

report="$WCP_ROOT/share/winetools/linking-report.txt"
{
  echo "# winetools linking report"
  echo "generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  for f in "$WCP_ROOT/bin/wine" "$WCP_ROOT/bin/wineserver"; do
    [[ -e "$f" ]] || continue
    echo "## $f"
    file "$f" || true
    if command -v readelf >/dev/null 2>&1; then
      readelf -d "$f" 2>/dev/null | sed -n '1,60p' || true
    fi
    echo
  done
} > "$report"

cat > "$WCP_ROOT/info/info.json" <<EOF_INFO
{
  "name": "Wine 11.1 ARM64EC",
  "os": "windows",
  "arch": "arm64",
  "version": "11.1-arm64ec",
  "features": ["ntsync", "wow64", "vulkan1.4", "egl"],
  "built": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF_INFO

cat > "$WCP_ROOT/bin/env.sh" <<'EOF_ENV'
#!/bin/sh
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
exec "$(dirname "$0")/wine" "$@"
EOF_ENV
chmod +x "$WCP_ROOT/bin/env.sh"

archive_inputs=(-C "$WCP_ROOT" .)
if [[ -f "$PREFIX_PACK_PATH" ]]; then
  archive_inputs+=(-C "$(dirname "$PREFIX_PACK_PATH")" "$(basename "$PREFIX_PACK_PATH")")
else
  echo "WARN: prefixPack.txz not found at $PREFIX_PACK_PATH" >&2
fi
if [[ -f "$PROFILE_PATH" ]]; then
  archive_inputs+=(-C "$(dirname "$PROFILE_PATH")" "$(basename "$PROFILE_PATH")")
else
  echo "WARN: profile.json not found at $PROFILE_PATH" >&2
fi

WCP_PATH="$WCP_OUTPUT_DIR/$WCP_NAME.wcp"
tar -cJf "$WCP_PATH" "${archive_inputs[@]}"
echo "Created $WCP_PATH"
