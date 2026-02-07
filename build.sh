#!/usr/bin/env bash
set -euo pipefail

#########################################
# Build Wine‑TKG ARM64EC on Arch Linux
#########################################

echo ">>> Starting build"

# Working directories
WORK="$PWD/work"
SRC="$WORK/src"
LLVM_MINGW="$WORK/llvm-mingw"
INSTALL="$WORK/install"
WCP_OUT="$PWD"

rm -rf "$WORK"
mkdir -p "$WORK" "$SRC" "$LLVM_MINGW" "$INSTALL"

# === 1) Install dependencies ===

echo ">>> Installing dependencies"

# Enable multilib for pacman
sed -Ei '/^#\[multilib\]/{s/^#//;n;s/^#//;}' /etc/pacman.conf
pacman -Syy --noconfirm

pacman -Sy --noconfirm \
  base-devel git wget unzip \
  clang lld mingw-w64-gcc \
  cmake ninja pkgconf python \
  vulkan-icd-loader \
  freetype2 lib32-freetype2 \
  libx11 lib32-libx11 \
  libpulse lib32-libpulse \
  gtk3 lib32-gtk3 \
  libpng lib32-libpng \
  giflib lib32-giflib \
  openal lib32-openal \
  gnutls lib32-gnutls \
  libxslt lib32-libxslt \
  sqlite lib32-sqlite \
  libjpeg-turbo lib32-libjpeg-turbo \
  opencl-icd-loader lib32-opencl-icd-loader \
  v4l-utils lib32-v4l-utils \
  libxrandr lib32-libxrandr \
  libxcursor lib32-libxcursor \
  libxinerama lib32-libxinerama \
  alsa-lib lib32-alsa-lib \
  alsa-plugins lib32-alsa-plugins \
  gst-plugins-base-libs lib32-gst-plugins-base-libs

echo ">>> Dependencies installed"

# === 2) Download llvm‑mingw toolchain ===

echo ">>> Downloading llvm‑mingw"

wget -q -O "$WORK/llvm-mingw.zip" \
     https://github.com/mstorsjo/llvm-mingw/releases/download/20251216/llvm-mingw-20251216-ucrt-x86_64.zip

unzip -q "$WORK/llvm-mingw.zip" -d "$LLVM_MINGW"

export PATH="$LLVM_MINGW/bin:$PATH"

echo "llvm‑mingw path: $(which clang)"

# === 3) Clone repositories ===

echo ">>> Cloning sources"

git clone https://gitlab.winehq.org/wine/wine.git "$SRC/wine-git"
(
  cd "$SRC/wine-git"
  git fetch --tags
  git checkout wine-11.1
)

git clone https://gitlab.winehq.org/wine/wine-staging.git "$SRC/wine-staging-git"
git clone https://github.com/Frogging-Family/wine-tkg-git.git "$SRC/wine-tkg-git"

# === 4) Prepare wine‑tkg ===

echo ">>> Preparing wine‑tkg"

cd "$SRC/wine-tkg-git"

# copy default config
cp wine-tkg-profiles/advanced-customization.cfg customization.cfg

# enable staging, esync, fsync, proton options
sed -i 's/^_use_staging=.*/_use_staging="true"/' customization.cfg
sed -i 's/^_use_esync=.*/_use_esync="true"/' customization.cfg
sed -i 's/^_use_fsync=.*/_use_fsync="true"/' customization.cfg
sed -i 's/^_protonify=.*/_protonify="true"/' customization.cfg
sed -i 's/^_proton_rawinput=.*/_proton_rawinput="true"/' customization.cfg

chmod +x wine-tkg-scripts/*.sh
yes "" | ./wine-tkg-scripts/prepare.sh

cd "$WORK"

# === 5) Build host tools ===

echo ">>> Building wine host tools"

mkdir -p "$WORK/host-build"
cd "$WORK/host-build"

"$SRC/wine-git/configure" --disable-tests --enable-win64
make __tooldeps__ -j$(nproc)

# === 6) Build Wine for ARM64EC ===

echo ">>> Building Wine ARM64EC"

mkdir -p "$WORK/arm64ec"
cd "$WORK/arm64ec"

export CC=aarch64-w64-mingw32-clang
export CXX=aarch64-w64-mingw32-clang++
export WINDRES=aarch64-w64-mingw32-windres

export CFLAGS="-O3 -march=armv8.2-a+fp16+dotprod"
export CXXFLAGS="$CFLAGS"
export CROSSCFLAGS="$CFLAGS -mstrict-align"

"$SRC/wine-git/configure" \
  --host=aarch64-w64-mingw32 \
  --enable-win64 \
  --with-wine-tools="$WORK/host-build" \
  --with-mingw=clang \
  --disable-tests \
  --with-x \
  --with-vulkan \
  --with-freetype \
  --with-pulse \
  --without-wayland \
  --without-gstreamer \
  --without-cups \
  --without-sane \
  --without-oss \
  --enable-archs=i386,arm64ec,aarch64

make -j$(nproc)

echo ">>> Installing build"

rm -rf "$INSTALL"
make DESTDIR="$INSTALL" install

# === 7) Package .wcp ===

echo ">>> Packaging Wine to WCP"

WCPDIR="$WORK/wcp"
rm -rf "$WCPDIR"
mkdir -p "$WCPDIR/bin" "$WCPDIR/lib/wine" "$WCPDIR/share"

cp -a "$INSTALL"/usr/bin/* "$WCPDIR/bin/" 2>/dev/null || true
cp -a "$INSTALL"/usr/lib/wine* "$WCPDIR/lib/wine/" 2>/dev/null || true
cp -a "$INSTALL"/usr/share/* "$WCPDIR/share/" 2>/dev/null || true

(
  cd "$WCPDIR/bin"
  ln -sf wine64 wine || true
)

find "$WCPDIR/bin" -type f -exec chmod +x {} \;
find "$WCPDIR/lib/wine" -name '*.so*' -exec chmod +x {} \;

cat > "$WCPDIR/info.json" << 'EOF'
{
  "name": "Wine-11.1-Staging-TKG-ARM64EC",
  "version": "11.1",
  "arch": "arm64",
  "variant": "staging+tkg",
  "features": ["staging","fsync","esync","vulkan"]
}
EOF

cat > "$WCPDIR/env.sh" << 'EOF'
#!/bin/sh
export WINEDEBUG=-all
export WINEESYNC=1
export WINEFSYNC=1
EOF

chmod +x "$WCPDIR/env.sh"

tar -cJf "$WCP_OUT/${WCP_NAME:-wine-tkg-arm64ec.wcp}" -C "$WCPDIR" .

echo ">>> Build complete: $WCP_OUT/${WCP_NAME:-wine-tkg-arm64ec.wcp}"