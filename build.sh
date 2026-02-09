#!/usr/bin/env bash
set -Eeuo pipefail

echo
echo "======================================================="
echo " Wine ARM64EC TKG + Staging WCP build"
echo "======================================================="

#########################################################################
# 0) Install dependencies
#########################################################################

echo "=== Installing dependencies systemwide ==="
pacman -Sy --noconfirm git wget unzip tar base-devel \
  freetype2 libpng libjpeg-turbo zlib libx11 libxext \
  libxrandr libxinerama libxi libxcursor gstreamer \
  gst-plugins-base gnutls

#########################################################################
# 1) Sparse checkout of required TKG folders
#########################################################################

echo "=== Sparse‑checkout of wine‑tkg required folders ==="
rm -rf wine‑tkg‑src
mkdir wine‑tkg‑src
cd wine‑tkg‑src

git init
git remote add origin https://github.com/Frogging-Family/wine-tkg-git.git
git config core.sparseCheckout true

# List of required subpaths:
cat > .git/info/sparse-checkout <<EOF
wine-tkg-git/non-makepkg-build.sh
wine-tkg-git/wine-tkg-scripts/
wine-tkg-git/wine-tkg-patches/
wine-tkg-git/wine-tkg-profiles/
wine-tkg-git/wine-tkg-userpatches/
wine-tkg-git/customization.cfg
EOF

git pull --depth=1 origin master
cd ..

#########################################################################
# 2) Install LLVM‑MinGW cross toolchain
#########################################################################

LLVM_VER="${LLVM_MINGW_VER:-20251216}"
LLVM_ARCHIVE="llvm-mingw-${LLVM_VER}-ucrt-ubuntu-22.04-x86_64.tar.xz"
LLVM_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_VER}/${LLVM_ARCHIVE}"
LLVM_PREFIX="/opt/llvm-mingw"
echo "--- Downloading LLVM‑MinGW"
mkdir -p "${LLVM_PREFIX}"
wget -q "${LLVM_URL}" -O "/tmp/${LLVM_ARCHIVE}"
tar -xJf "/tmp/${LLVM_ARCHIVE}" -C "${LLVM_PREFIX}" --strip-components=1
export PATH="${LLVM_PREFIX}/bin:${PATH}"

#########################################################################
# 3) Clone Wine staging + AndreRH Wine arm64ec
#########################################################################

echo "=== Cloning Wine staging and Wine sources ==="
git clone --depth=1 https://gitlab.winehq.org/wine/wine-staging.git
rm -rf wine-src
git clone --depth=1 https://github.com/AndreRH/wine.git wine-src
(
  cd wine-src
  git fetch --depth=1 origin arm64ec
  git checkout arm64ec
)

#########################################################################
# 4) Prepare TKG build directory
#########################################################################

echo "=== Copying Wine sources to TKG folder ==="
rm -rf wine‑tkg‑src/wine
cp -a wine-src wine‑tkg‑src/wine

#########################################################################
# 5) Enable patch groups
#########################################################################

CFG="wine‑tkg‑src/wine‑tkg‑git/customization.cfg"
echo "=== Enabling patch flags in customization.cfg ==="

# Core patchgroups
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
# 6) Set up cross‑compile environment
#########################################################################

export CC="clang --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link -O2"
export CXX="clang++ --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link -O2"
export LD="lld-link"
export AR="llvm-ar"
export RANLIB="llvm-ranlib"

#########################################################################
# 7) Run TKG build
#########################################################################

cd wine‑tkg‑src

echo "=== Running TKG non‑makepkg build ==="
chmod +x wine‑tkg‑git/non-makepkg-build.sh
./wine‑tkg‑git/non-makepkg-build.sh --cross

#########################################################################
# 8) Install build to staging
#########################################################################

STAGING="$(pwd)/../wcp/install"
echo "=== Installing build into staging ==="
rm -rf "$STAGING"
mkdir -p "$STAGING"
make -C non-makepkg-builds install DESTDIR="$STAGING"

#########################################################################
# 9) Create WCP structure
#########################################################################

echo "=== Creating WCP layout ==="
cd "$STAGING"
mkdir -p wcp/{bin,lib/wine,share}
cp -a usr/local/bin/* wcp/bin/ 2>/dev/null || cp -a usr/bin/* wcp/bin/
cd wcp/bin && ln -sf wine64 wine && cd ../..
cp -a usr/local/lib/wine/* wcp/lib/wine/ 2>/dev/null || cp -a usr/lib/wine/* wcp/lib/wine/
cp -a usr/local/share/* wcp/share/ 2>/dev/null || cp -a usr/share/* wcp/share/

find wcp/bin -type f -exec chmod +x {} +
find wcp/lib -name "*.so*" -exec chmod +x {} +

#########################################################################
# 10) Write info.json and env.sh
#########################################################################

echo "=== Writing WCP metadata ==="
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
# 11) Package into .wcp
#########################################################################

WCP="${GITHUB_WORKSPACE:-$(pwd)}/wine-11.1-staging-s8g1.wcp"
echo "=== Packaging .wcp: $WCP ==="
tar -cJf "$WCP" -C wcp .

echo "=== Build complete! ==="
