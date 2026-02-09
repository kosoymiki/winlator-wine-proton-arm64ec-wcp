#!/bin/bash
set -euxo pipefail

ROOT="$PWD"
SRC="$ROOT/wine-src"
TKG="$ROOT/wine-tkg"
BUILD="$ROOT/wine-tkg/non-makepkg-builds"
INSTALL="$BUILD/install"

LLVM_MINGW_PATH="/opt/llvm-mingw-${LLVM_MINGW_VER}-ucrt/bin"
export PATH="$LLVM_MINGW_PATH:$PATH"

# Copy our branch into tkg builder
cp -r "$SRC" "$TKG/wine"

cd "$TKG"

# Optional: customize tkg config (edit wine-tkg-config.txt)
# You can enable custom patches, disable, etc.

echo "--- Start tkg build"
# Run tkg build script
./non-makepkg-build.sh  \
  --enable-win64 \
  --host=arm64ec-w64-mingw32 \
  --build=$(./config.guess) \
  --enable-archs=arm64ec,aarch64,i386 \
  --with-mingw=clang

# After tkg build completes, we will package

cd "$BUILD"

# Make install path
mkdir -p "$INSTALL"

# Install
make install DESTDIR="$INSTALL"

# Package into .wcp
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

echo "--- Done"