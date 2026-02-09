#!/usr/bin/env bash
set -euxo pipefail

ROOT="$PWD"
TKG="$ROOT/wine-tkg-git"
INSTALL_PREFIX="$ROOT/install"
LLVM_DIR="/opt/llvm-mingw-${LLVM_MINGW_VER}-ucrt-x86_64"

echo "=== Build start $(date)"

# 1) Ensure LLVM‑MinGW toolchain
if [ ! -d "$LLVM_DIR" ]; then
    echo "LLVM Mingw toolchain missing"
    exit 1
fi

export PATH="$LLVM_DIR/bin:$PATH"
echo "clang => $(which clang)"
echo "lld => $(which lld-link || which lld)"

# 2) Prepare wine‑tkg config
cd "$TKG"

if [ ! -f customization.cfg ]; then
  cat > customization.cfg <<EOF
# Config for Wine ARM64EC
_wine_git_repo="https://github.com/AndreRH/wine.git"
_wine_git_branch="arm64ec"
_use_staging="yes"
_staging_level="default"
# add additional tkg patches if needed
EOF
fi

# show effective config
echo "--- custom config"
grep -E "_wine_git|_use_staging" customization.cfg || true

# 3) Run wine‑tkg build
./non-makepkg-build.sh \
  --enable-win64 \
  --host=arm64ec-w64-mingw32 \
  --enable-archs=arm64ec,aarch64,i386 \
  --with-mingw=clang

# 4) Install and package
BUILD_OUT="$(find . -type d -name "*-build" | head -n1 || true)"
if [ -z "$BUILD_OUT" ]; then
  BUILD_OUT="./non-makepkg-builds"
fi

rm -rf "$INSTALL_PREFIX"
mkdir -p "$INSTALL_PREFIX"

cp -a "$BUILD_OUT/bin" "$INSTALL_PREFIX/"
cp -a "$BUILD_OUT/lib" "$INSTALL_PREFIX/"
cp -a "$BUILD_OUT/share" "$INSTALL_PREFIX/" || true

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

echo "=== Build complete $(date)"