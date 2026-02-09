#!/usr/bin/env bash
set -euxo pipefail

ROOT="$PWD"
SRC="$ROOT/wine-src"
TKG="$ROOT/wine-tkg-git"
BUILD_OUT="$TKG/non-makepkg-builds"
INSTALL_DIR="$ROOT/install"

# === STEP 1: LLVM‑Mingw toolchain setup ===
LLVM_BASE="/opt"
LLVM_VERSION="llvm-mingw-${LLVM_MINGW_VER}-ucrt-x86_64"
LLVM_DIR="${LLVM_BASE}/${LLVM_VERSION}"

echo "--- LLVM‑Mingw dir = $LLVM_DIR"
if [ ! -d "$LLVM_DIR" ]; then
    echo "LLVM mingw toolchain not found!"
    exit 1
fi

# Add to PATH so wine‑tkg finds it
export PATH="${LLVM_DIR}/bin:$PATH"
echo "Using LLVM clang = $(which clang)"

# === STEP 2: Prepare wine‑tkg environment ===
rm -rf "$TKG/wine"
cp -r "$SRC" "$TKG/wine"

cd "$TKG"

# Optional: customize wine‑tkg config (wine‑tkg-config.txt)
# Example: enable fsync/proton patches in configs

# === STEP 3: Run the wine‑tkg build script ===
echo "--- Starting wine‑tkg build"
./non-makepkg-build.sh \
  --enable-win64 \
  --host=arm64ec-w64-mingw32 \
  --enable-archs=arm64ec,aarch64,i386 \
  --with-mingw=clang

# wine‑tkg build outputs in "non-makepkg-builds"

cd "$BUILD_OUT"

# === STEP 4: Manual install of build output ===
echo "--- Installing built Wine to prefix"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# If wine‑tkg build produced bin/lib/share in root of non‑makepkg-builds:
cp -a bin "$INSTALL_DIR/"
cp -a lib "$INSTALL_DIR/"
cp -a share "$INSTALL_DIR/"

# Ensure main runner is accessible
mkdir -p "$INSTALL_DIR/bin"
ln -sf "$INSTALL_DIR/bin64/wine64" "$INSTALL_DIR/bin/wine"

# === STEP 5: Prepare .wcp packaging ===
echo "--- Packaging .wcp format"
mkdir -p wcp/{bin,lib,share}

cp -a "$INSTALL_DIR/bin"/* wcp/bin/
cp -a "$INSTALL_DIR/lib"/* wcp/lib/
cp -a "$INSTALL_DIR/share"/* wcp/share/

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