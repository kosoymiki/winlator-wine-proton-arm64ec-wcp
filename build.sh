#!/usr/bin/env bash
set -Eeuo pipefail

echo
echo "======================================================="
echo " Wine ARM64EC TKG + Staging WCP build"
echo "======================================================="

#########################################################################
# 0) Sparse‑checkout wine-tkg sources
#########################################################################

echo "--- Sparse‑checkout only needed TKG files ---"
rm -rf wine-tkg-sparse
git init wine-tkg-sparse
cd wine-tkg-sparse

git remote add origin https://github.com/Frogging-Family/wine-tkg-git.git
git config core.sparseCheckout true

# Only paths we need
cat <<EOF > .git/info/sparse-checkout
customization.cfg
non-makepkg-build.sh
wine-tkg-patches/
wine-tkg-profiles/
wine-tkg-scripts/
wine-tkg-userpatches/
EOF

# Pull just those files
git pull --depth=1 origin master

cd ..

#########################################################################
# 1) Install LLVM‑MinGW cross toolchain
#########################################################################

LLVM_VER="${LLVM_MINGW_VER:-20251216}"
LLVM_ARCHIVE="llvm-mingw-${LLVM_VER}-ucrt-ubuntu-22.04-x86_64.tar.xz"
LLVM_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_VER}/${LLVM_ARCHIVE}"
LLVM_PREFIX="/opt/llvm-mingw"
LLVM_BIN="${LLVM_PREFIX}/bin"

echo "--- Getting LLVM‑MinGW ---"
mkdir -p "${LLVM_PREFIX}"
wget -q "${LLVM_URL}" -O "/tmp/${LLVM_ARCHIVE}"
tar -xJf "/tmp/${LLVM_ARCHIVE}" -C "${LLVM_PREFIX}" --strip-components=1

export PATH="${LLVM_BIN}:${PATH}"

#########################################################################
# 2) Clone wine‑staging and AndreRH Wine arm64ec
#########################################################################

echo "--- Cloning wine-staging ---"
git clone --depth=1 https://gitlab.winehq.org/wine/wine-staging.git

echo "--- Cloning AndreRH Wine arm64ec ---"
rm -rf wine-src
git clone --depth=1 https://github.com/AndreRH/wine.git wine-src
(
  cd wine-src
  git fetch --depth=1 origin arm64ec
  git checkout arm64ec
)

#########################################################################
# 3) Copy Wine source into sparse‑checked TKG folder
#########################################################################

rm -rf wine-tkg-sparse/wine
cp -a wine-src wine-tkg-sparse/wine

#########################################################################
# 4) Enable TKG patch groups
#########################################################################

echo "--- Enabling patch groups in customization.cfg ---"
CFG="wine-tkg-sparse/customization.cfg"

# Core TKG options
for flag in staging esync fsync; do
  sed -i "s/_use_${flag}=\"false\"/_use_${flag}=\"true\"/g" "$CFG" || true
done

# Proton/protonify support
for flag in proton_battleye_support proton_eac_support proton_winevulkan proton_mf_patches proton_rawinput protonify; do
  sed -i "s/_${flag}=\"false\"/_${flag}=\"true\"/g" "$CFG" || true
done

# Misc game fixes
for flag in mk11_fix re4_fix mwo_fix use_josh_flat_theme; do
  sed -i "s/_${flag}=\"false\"/_${flag}=\"true\"/g" "$CFG" || true
done

#########################################################################
# 5) Setup cross compile environment
#########################################################################

export CC="clang --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link -O2"
export CXX="clang++ --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link -O2"
export LD="lld-link"
export AR="llvm-ar"
export RANLIB="llvm-ranlib"

#########################################################################
# 6) Run non‑makepkg TKG build
#########################################################################

cd wine-tkg-sparse
echo "--- Running TKG non‑makepkg build ---"
chmod +x non-makepkg-build.sh
./non-makepkg-build.sh --cross

#########################################################################
# 7) Install into staging
#########################################################################

STAGING="$(pwd)/../wcp/install"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"
make -C non-makepkg-builds install DESTDIR="${STAGING}"

#########################################################################
# 8) Arrange final .wcp structure
#########################################################################

cd "${STAGING}"
mkdir -p wcp/{bin,lib/wine,share}

cp -a usr/local/bin/* wcp/bin/ 2>/dev/null || cp -a usr/bin/* wcp/bin/
cd wcp/bin && ln -sf wine64 wine && cd ../..

cp -a usr/local/lib/wine/* wcp/lib/wine/ 2>/dev/null || cp -a usr/lib/wine/* wcp/lib/wine/
cp -a usr/local/share/* wcp/share/ 2>/dev/null || cp -a usr/share/* wcp/share/

find wcp/bin -type f -exec chmod +x {} +
find wcp/lib -name "*.so*" -exec chmod +x {} +

#########################################################################
# 9) Write info.json & env.sh
#########################################################################

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
# 10) Package into .wcp
#########################################################################

WCP="${GITHUB_WORKSPACE:-$(pwd)}/wine-11.1-staging-s8g1.wcp"
echo "--- Creating final .wcp: ${WCP} ---"
tar -cJf "${WCP}" -C wcp .

echo "=== .wcp created ==="