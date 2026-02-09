#!/usr/bin/env bash
set -euxo pipefail

ROOT="$PWD"
SRC="$ROOT/wine-src"
TKG="$ROOT/wine-tkg-git"
BUILD_DIR="$TKG/non-makepkg-builds"
INSTALL_DIR="$BUILD_DIR/install"

# LLVM‑Mingw toolchain added to PATH via GitHub $GITHUB_PATH
# Make sure clang/llvm‑mingw is present
export PATH="/opt/llvm-mingw-${LLVM_MINGW_VER}-ucrt/bin:$PATH"
export CC="clang"
export CXX="clang++"
export LD="lld-link"
export NM="llvm-nm"
export AR="llvm-ar"
export STRIP="llvm-strip"

# Copy the AndreRH Wine source into wine‑tkg builder
rm -rf "$TKG/wine"
cp -r "$SRC" "$TKG/wine"

cd "$TKG"

# Optionally you can edit wine‑tkg config files here:
# wine-tkg-config.txt and userpatches if needed

echo "--- Running wine‑tkg build"
# Run wine‑tkg build
# non‑makepkg build script will generate Wine with staging + tkg patches
./non-makepkg-build.sh \
  --enable-win64 \
  --host=arm64ec-w64-mingw32 \
  --enable-archs=arm64ec,aarch64,i386 \
  --with-mingw=clang

# After build, install and package
cd "$BUILD_DIR"

mkdir -p "$INSTALL_DIR"

echo "--- Installing build output"
make install DESTDIR="$INSTALL_DIR"

echo "--- Packaging .wcp artifact"
mkdir -p wcp/{bin,lib/wine,share}

cp -a usr/local/bin/* wcp/bin/
ln -sf wine64 wcp/bin/wine

cp -a usr/local/lib/wine/* wcp/lib/wine/
cp -a usr/local/share/* wcp/share/

cat > wcp/info.json <<EOF
{
  "name": "${WCP_NAME}",
  "version": "arm64ec-tkg",
  "arch": "arm64ec",
  "variant": "tkg"
}
EOF

tar -cJf "${ROOT}/${WCP_NAME}.wcp" -C wcp .

echo "--- Build & package finished"