#!/usr/bin/env bash
set -euxo pipefail

######################################
# Build Wine‑tkg ARM64EC on Arch Linux
######################################

WORK="$PWD/work"
SRC="$WORK/src"
HOST="$WORK/host"
INSTALL="$WORK/install"
LLVM_MINGW="$WORK/llvm-mingw"
WCP_OUT="$PWD"

# Clean everything
rm -rf "$WORK"
mkdir -p "$WORK" "$SRC" "$HOST" "$INSTALL" "$LLVM_MINGW"

echo "=== Starting Wine‑tkg ARM64EC build ==="

# === 1) LLVM‑Mingw toolchain ===

echo ">>> Downloading llvm‑mingw"
wget -q -O "$WORK/llvm-mingw.zip" \
     https://github.com/mstorsjo/llvm-mingw/releases/download/20251216/llvm-mingw-20251216-ucrt-x86_64.zip

echo ">>> Extracting llvm‑mingw"
unzip -q "$WORK/llvm-mingw.zip" -d "$LLVM_MINGW"

export PATH="$LLVM_MINGW/bin:$PATH"
echo ">>> Using llvm‑mingw from: $LLVM_MINGW"
clang --version | head -n1

# === 2) Clone sources ===

echo ">>> Cloning Wine 11.1"
git clone https://gitlab.winehq.org/wine/wine.git "$SRC/wine-git"
(
  cd "$SRC/wine-git"
  git fetch --tags
  git checkout wine-11.1
)

echo ">>> Cloning Wine‑Staging"
git clone https://gitlab.winehq.org/wine/wine-staging.git "$SRC/wine-staging-git"

echo ">>> Cloning wine‑tkg‑git"
git clone https://github.com/Frogging-Family/wine-tkg-git.git "$SRC/wine-tkg-git"

# === 3) Prepare Wine‑tkg ===

echo ">>> Preparing wine‑tkg"

cd "$SRC/wine-tkg-git"

# Copy example customization
cp wine-tkg-profiles/advanced-customization.cfg customization.cfg

# Turn on staging + various patches
sed -i 's/^_use_staging=.*/_use_staging="true"/' customization.cfg
sed -i 's/^_use_esync=.*/_use_esync="true"/' customization.cfg
sed -i 's/^_use_fsync=.*/_use_fsync="true"/' customization.cfg
sed -i 's/^_use_GE_patches=.*/_use_GE_patches="true"/' customization.cfg
sed -i 's/^_protonify=.*/_protonify="true"/' customization.cfg
sed -i 's/^_proton_rawinput=.*/_proton_rawinput="true"/' customization.cfg
sed -i 's/^_proton_fs_hack=.*/_proton_fs_hack="true"/' customization.cfg

# Make sure scripts are executable
chmod +x wine-tkg-scripts/*.sh

# Prepare sources (wine–staging + tkg patches)
yes "" | ./wine-tkg-scripts/prepare.sh

cd "$WORK"

# === 4) Build host tools ===

echo ">>> Building host tools"

mkdir -p "$HOST"
cd "$HOST"

"$SRC/wine-git/configure" --disable-tests --enable-win64
make __tooldeps__ -j$(nproc)

# === 5) Build Wine ARM64EC ===

echo ">>> Building Wine ARM64EC"

mkdir -p "$WORK/build-arm64ec"
cd "$WORK/build-arm64ec"

# Set cross compilers
export CC=aarch64-w64-mingw32-clang
export CXX=aarch64-w64-mingw32-clang++
export WINDRES=aarch64-w64-mingw32-windres

# Optimization flags
export CFLAGS="-O3 -march=armv8.2-a+fp16+dotprod"
export CXXFLAGS="$CFLAGS"
export CROSSCFLAGS="$CFLAGS -mstrict-align"

# Configure Wine build
"$SRC/wine-git/configure" \
  --host=aarch64-w64-mingw32 \
  --enable-win64 \
  --with-wine-tools="$HOST" \
  --with-mingw=clang \
  --enable-archs=i386,arm64ec,aarch64 \
  --disable-tests \
  --with-x \
  --with-vulkan \
  --with-freetype \
  --with-pulse \
  --without-wayland \
  --without-gstreamer \
  --without-cups \
  --without-sane \
  --without-oss

# Build
make -j$(nproc)

# === 6) Install to DESTDIR ===

echo ">>> Installing build to DESTDIR"

rm -rf "$INSTALL"
make DESTDIR="$INSTALL" install

# === 7) Package into .wcp ===

echo ">>> Packaging WCP archive"

WCPDIR="$WORK/wcp"
rm -rf "$WCPDIR"
mkdir -p "$WCPDIR/bin" "$WCPDIR/lib/wine" "$WCPDIR/share"

# Copy binaries and libs
cp -a "$INSTALL"/usr/bin/* "$WCPDIR/bin/" 2>/dev/null || true
cp -a "$INSTALL"/usr/lib/wine* "$WCPDIR/lib/wine/" 2>/dev/null || true
cp -a "$INSTALL"/usr/share/* "$WCPDIR/share/" 2>/dev/null || true

# Symlink wine
(
  cd "$WCPDIR/bin"
  ln -sf wine64 wine || true
)

# Fix permissions
find "$WCPDIR/bin" -type f -exec chmod +x {} \;
find "$WCPDIR/lib/wine" -name "*.so*" -exec chmod +x {} \;

# Produce info.json
cat > "$WCPDIR/info.json" << 'EOF'
{
  "name": "Wine-11.1-Staging-TKG-ARM64EC",
  "version": "11.1",
  "arch": "arm64",
  "variant": "staging+tkg",
  "features": ["staging","esync","fsync","vulkan","proton"]
}
EOF

# Produce env.sh
cat > "$WCPDIR/env.sh" << 'EOF'
#!/usr/bin/env sh
export WINEDEBUG=-all
export WINEESYNC=1
export WINEFSYNC=1
EOF
chmod +x "$WCPDIR/env.sh"

# Create final archive
tar -cJf "$WCP_OUT/${WCP_NAME:-wine-tkg-arm64ec.wcp}" -C "$WCPDIR" .

echo "=== Build finished: $WCP_OUT/${WCP_NAME:-wine-tkg-arm64ec.wcp}"