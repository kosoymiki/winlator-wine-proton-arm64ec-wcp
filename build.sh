#!/usr/bin/env bash
set -euxo pipefail

ROOT="$PWD"
TKG="$ROOT/wine-tkg-git"
INSTALL_PREFIX="$ROOT/install"
LLVM_TOOLCHAIN="/opt/llvm-mingw-${LLVM_MINGW_VER}-ucrt-x86_64"

echo "=== Starting build $(date)"

# --- verify toolchain ---
if ! command -v clang >/dev/null; then
  echo "Error: clang not found in PATH"
  exit 1
fi

if ! command -v lld >/dev/null; then
  echo "Error: lld not found in PATH"
  exit 1
fi

export PATH="$LLVM_TOOLCHAIN/bin:$PATH"
echo "clang => $(which clang)"
echo "lld => $(which lld)"

# --- prepare wine-tkg config ---
cd "$TKG"

cat > customization.cfg <<EOF
_wine_git_repo="https://github.com/AndreRH/wine.git"
_wine_git_branch="arm64ec"
_use_staging="yes"
_staging_level="default"
EOF

# show applied config
grep "_wine_git" customization.cfg || true

# --- run tkg build ---
./non-makepkg-build.sh \
  --enable-win64 \
  --host=arm64ec-w64-mingw32 \
  --enable-archs=arm64ec,aarch64,i386 \
  --with-mingw=clang

# --- install to prefix ---
BUILD_OUT="$(find . -type d -name '*-build' | head -n1 || true)"
if [ -z "$BUILD_OUT" ]; then
  BUILD_OUT="$TKG/non-makepkg-builds"
fi

rm -rf "$INSTALL_PREFIX"
mkdir -p "$INSTALL_PREFIX"

cp -a "$BUILD_OUT/bin" "$INSTALL_PREFIX/"
cp -a "$BUILD_OUT/lib" "$INSTALL_PREFIX/"
cp -a "$BUILD_OUT/share" "$INSTALL_PREFIX/" || true

# --- package .wcp ---
mkdir -p wcp/{bin,lib,share}
cp -a "$INSTALL_PREFIX/bin/." wcp/bin/
cp -a "$INSTALL_PREFIX/lib/." wcp/lib/
cp -a "$INSTALL_PREFIX/share/." wcp/share/

cat > wcp/info.json <<EOF
{
  "name": "${WCP_NAME}",
  "version": "arm64ec-staging-tkg",
  "arch": "arm64ec",
  "variant": "tkg"
}
EOF

tar -cJf "${ROOT}/${WCP_NAME}.wcp" -C wcp .