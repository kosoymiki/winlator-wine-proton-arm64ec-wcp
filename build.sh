#!/usr/bin/env bash
set -Eeuo pipefail

echo
echo "======================================================="
echo " Wine ARM64EC TKG + Staging WCP build"
echo "======================================================="

#########################################################################
# 1) Install LLVM‑MinGW cross toolchain
#########################################################################

LLVM_VER="${LLVM_MINGW_VER:-20251216}"
LLVM_ARCHIVE="llvm-mingw-${LLVM_VER}-ucrt-ubuntu-22.04-x86_64.tar.xz"
LLVM_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_VER}/${LLVM_ARCHIVE}"
LLVM_PREFIX="/opt/llvm-mingw"
LLVM_BIN="${LLVM_PREFIX}/bin"

echo "--- Getting LLVM‑MinGW"
mkdir -p "${LLVM_PREFIX}"
wget -q "${LLVM_URL}" -O "/tmp/${LLVM_ARCHIVE}"
tar -xJf "/tmp/${LLVM_ARCHIVE}" -C "${LLVM_PREFIX}" --strip-components=1

export PATH="${LLVM_BIN}:${PATH}"

#########################################################################
# 2) Clone wine‑tkg and wine‑staging
#########################################################################

echo "--- Cloning wine‑tkg"
[[ -d wine-tkg-git ]] || git clone https://github.com/Frogging-Family/wine-tkg-git.git

echo "--- Cloning wine‑staging"
[[ -d wine-staging ]] || git clone https://gitlab.winehq.org/wine/wine-staging.git

#########################################################################
# 3) Pull AndreRH Wine arm64ec
#########################################################################

echo "--- Cloning AndreRH Wine arm64ec"
rm -rf wine-src
git clone --depth=1 https://github.com/AndreRH/wine.git wine-src
(
  cd wine-src
  git fetch --depth=1 origin arm64ec
  git checkout arm64ec
)

# Replace TKG wine source
rm -rf wine-tkg-git/wine
cp -a wine-src wine-tkg-git/wine

#########################################################################
# 4) Enable patch groups
#########################################################################

CFG="wine-tkg-git/customization.cfg"
echo "--- Enabling patch groups in TKG config"

for flag in staging esync fsync pba GE_WAYLAND; do
    sed -i "s/_use_${flag}=\"false\"/_use_${flag}=\"true\"/g" "$CFG" || true
done

for flag in proton_battleye_support proton_eac_support proton_winevulkan proton_mf_patches proton_rawinput protonify; do
    sed -i "s/_${flag}=\"false\"/_${flag}=\"true\"/g" "$CFG" || true
done

for flag in mk11_fix re4_fix mwo_fix use_josh_flat_theme; do
    sed -i "s/_${flag}=\"false\"/_${flag}=\"true\"/g" "$CFG" || true
done

#########################################################################
# 5) Setup cross compilation environment
#########################################################################

export CC="clang --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link -O3 -march=native"
export CXX="clang++ --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link -O3 -march=native"
export LD="lld-link"
export AR="llvm-ar"
export RANLIB="llvm-ranlib"

#########################################################################
# 6) Build via wine‑tkg with non‑makepkg‑build.sh
#########################################################################

cd wine-tkg-git

echo "--- Running TKG non-makepkg build"

# запускаем единственный правильный скрипт
chmod +x non-makepkg-build.sh
./non-makepkg-build.sh \
  --host=arm64ec-w64-mingw32 \
  --enable-win64 \
  --with-mingw=clang

#########################################################################
# 7) Install build to staging area
#########################################################################

STAGING="$(pwd)/../wcp/install"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"

echo "--- Installing compiled wine"
make -C non-makepkg-builds install DESTDIR="${STAGING}"

#########################################################################
# 8) Create wcp structure
#########################################################################

echo "--- Assembling WCP directory"
cd "${STAGING}"

mkdir -p wcp/{bin,lib/wine,share}

echo "Copying binaries"
cp -a usr/local/bin/* wcp/bin/ 2>/dev/null || cp -a usr/bin/* wcp/bin/

# Symlink wine => wine64
cd wcp/bin && ln -sf wine64 wine && cd ../..

echo "Copying libs"
cp -a usr/local/lib/wine/* wcp/lib/wine/ 2>/dev/null || cp -a usr/lib/wine/* wcp/lib/wine/

echo "Copying share files"
cp -a usr/local/share/* wcp/share/ 2>/dev/null || cp -a usr/share/* wcp/share/

echo "Fixing permissions"
find wcp/bin -type f -exec chmod +x {} +
find wcp/lib -name "*.so*" -exec chmod +x {} +

#########################################################################
# 9) Write info.json & env.sh
#########################################################################

echo "--- Writing info.json and env.sh"

cat > wcp/info.json << 'EOF'
{
  "name": "Wine-11.1-Staging-S8G1",
  "version": "11.1",
  "arch": "arm64",
  "variant": "staging",
  "features": ["staging","fsr","fsync","esync","vulkan"]
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

echo "--- Creating final .wcp: ${WCP}"
tar -cJf "${WCP}" -C wcp .

echo "=== .wcp created ==="
echo "=== Build finished ==="