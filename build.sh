#!/usr/bin/env bash
set -Eeuox pipefail

echo
echo "======================================================="
echo " Wine ARM64EC TKG + Staging WCP build"
echo "======================================================="

#########################################################################
# 1) Install dependencies (needed for SVN and build)
#########################################################################

echo "=== Installing dependencies ==="
pacman -Sy --noconfirm subversion git wget unzip tar base-devel \
  freetype2 libpng libjpeg-turbo zlib libx11 libxext libxrandr \
  libxinerama libxi libxcursor gstreamer gst-plugins-base gnutls

#########################################################################
# 2) Install LLVM‑MinGW cross toolchain
#########################################################################

LLVM_VER="${LLVM_MINGW_VER:-20251216}"
LLVM_ARCHIVE="llvm-mingw-${LLVM_VER}-ucrt-ubuntu-22.04-x86_64.tar.xz"
LLVM_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_VER}/${LLVM_ARCHIVE}"
LLVM_PREFIX="/opt/llvm-mingw"

echo "--- Getting LLVM‑MinGW"
mkdir -p "${LLVM_PREFIX}"
wget -q "${LLVM_URL}" -O "/tmp/${LLVM_ARCHIVE}"
tar -xJf "/tmp/${LLVM_ARCHIVE}" -C "${LLVM_PREFIX}" --strip-components=1
export PATH="${LLVM_PREFIX}/bin:${PATH}"

#########################################################################
# 3) Download exactly needed TKG directory via SVN export
#########################################################################

echo "=== Downloading TKG sources via SVN ==="

# Make sure target exists
rm -rf wine-tkg
mkdir wine-tkg
cd wine-tkg

svn export --force \
  https://github.com/Frogging-Family/wine-tkg-git/trunk/wine-tkg-git || \
  { echo "SVN export failed"; exit 1; }

cd ..

#########################################################################
# 4) Clone wine‑staging and AndreRH Wine arm64ec
#########################################################################

echo "=== Cloning wine‑staging and Wine sources ==="
git clone --depth=1 https://gitlab.winehq.org/wine/wine-staging.git
rm -rf wine-src
git clone --depth=1 https://github.com/AndreRH/wine.git wine-src
(
  cd wine-src
  git fetch --depth=1 origin arm64ec
  git checkout arm64ec
)

#########################################################################
# 5) Copy Wine into TKG folder
#########################################################################

echo "=== Copying Wine sources into TKG folder ==="
rm -rf wine-tkg/wine
cp -a wine-src wine-tkg/wine

#########################################################################
# 6) Enable patchgroups in TKG config (customization.cfg)
#########################################################################

CFG="wine-tkg/wine-tkg-git/customization.cfg"
echo "=== Enabling patch groups ==="

# Core TKG patchgroups
for flag in staging esync fsync; do
  sed -i "s/_use_${flag}=\"false\"/_use_${flag}=\"true\"/g" "$CFG" || true
done

# Proton‑like options
for flag in proton_battleye_support proton_eac_support proton_winevulkan \
            proton_mf_patches proton_rawinput protonify; do
  sed -i "s/_${flag}=\"false\"/_${flag}=\"true\"/g" "$CFG" || true
done

# Extra fixes
for flag in mk11_fix re4_fix mwo_fix use_josh_flat_theme; do
  sed -i "s/_${flag}=\"false\"/_${flag}=\"true\"/g" "$CFG" || true
done

#########################################################################
# 7) Setup cross compile environment
#########################################################################

export CC="clang --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link -O2"
export CXX="clang++ --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link -O2"
export LD="lld-link"
export AR="llvm-ar"
export RANLIB="llvm-ranlib"

#########################################################################
# 8) Run non‑makepkg TKG build
#########################################################################

cd wine-tkg
echo "=== Running TKG non‑makepkg build ==="
chmod +x wine-tkg-git/non-makepkg-build.sh
./wine-tkg-git/non-makepkg-build.sh --cross

#########################################################################
# 9) Install into staging
#########################################################################

STAGING="$(pwd)/../wcp/install"
echo "=== Installing build to staging ==="
rm -rf "${STAGING}"
mkdir -p "${STAGING}"
make -C non-makepkg-builds install DESTDIR="${STAGING}"

#########################################################################
# 10) Create final WCP layout
#########################################################################

echo "=== Creating WCP structure ==="
cd "${STAGING}"
mkdir -p wcp/{bin,lib/wine,share}

cp -a usr/local/bin/* wcp/bin/ 2>/dev/null || cp -a usr/bin/* wcp/bin/
cd wcp/bin && ln -sf wine64 wine && cd ../..

cp -a usr/local/lib/wine/* wcp/lib/wine/ 2>/dev/null || cp -a usr/lib/wine/* wcp/lib/wine/
cp -a usr/local/share/* wcp/share/ 2>/dev/null || cp -a usr/share/* wcp/share/

find wcp/bin -type f -exec chmod +x {} +
find wcp/lib -name "*.so*" -exec chmod +x {} +

#########################################################################
# 11) Write info.json & env.sh
#########################################################################

echo "=== Writing info.json and env.sh ==="
cat > wcp/info.json << 'EOF'
{
  "name": "Wine-11.1-Staging-S8G1",
  "version": "11.1",
  "arch": "arm64",
  "variant": "staging",
  "features": ["staging","fsync","esync","vulkan"]
}
EOF

cat > wcp/env.sh << 'EOF'
#!/bin/sh
export WINEDEBUG=-all
export WINEESYNC=1
export WINEFSYNC=1
export WINE_FULLSCREEN_FSR=1
EOF

chmod +x wcp/env.sh

#########################################################################
# 12) Package into .wcp (tar.xz)
#########################################################################

WCP="${GITHUB_WORKSPACE:-$(pwd)}/wine-11.1-staging-s8g1.wcp"
echo "=== Creating final .wcp: ${WCP} ==="
tar -cJf "${WCP}" -C wcp .

echo "=== Build finished successfully ==="