#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== Wine ARM64EC TKG build start ==="

################################################################################
# 1) Install LLVM‑MinGW cross toolchain
################################################################################

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

################################################################################
# 2) Clone wine‑tkg and wine‑staging
################################################################################

echo "--- Cloning wine‑tkg"
if [[ ! -d wine-tkg-git ]]; then
    git clone https://github.com/Frogging-Family/wine-tkg-git.git
fi

echo "--- Cloning wine‑staging"
if [[ ! -d wine-staging ]]; then
    git clone https://gitlab.winehq.org/wine/wine-staging.git
fi

################################################################################
# 3) Checkout Wine source from AndreRH arm64ec branch
################################################################################

echo "--- Cloning Wine (AndreRH arm64ec)"
if [[ -d wine-tkg-git/wine ]]; then
    rm -rf wine-tkg-git/wine
fi

git clone https://github.com/AndreRH/wine.git wine‑src
cd wine‑src
git fetch --all
git checkout arm64ec
cd ..

cp -r wine‑src wine-tkg-git/wine

################################################################################
# 4) Enable staging + all patch groups in TKG config
################################################################################

CFG="wine-tkg-git/wine-tkg-git/customization.cfg"
echo "--- Modifying tkg patch config"

for flag in staging esync fsync pba GE_WAYLAND; do
    sed -i "s/_use_${flag}=\"false\"/_use_${flag}=\"true\"/g" "$CFG" || true
done

for flag in proton_battleye_support proton_eac_support proton_winevulkan proton_mf_patches proton_rawinput protonify; do
    sed -i "s/_${flag}=\"false\"/_${flag}=\"true\"/g" "$CFG" || true
done

for flag in mk11_fix re4_fix mwo_fix use_josh_flat_theme; do
    sed -i "s/_${flag}=\"false\"/_${flag}=\"true\"/g" "$CFG" || true
done

################################################################################
# 5) Setup cross compiler environment
################################################################################

export CC="clang --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link"
export CXX="clang++ --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link"
export LD="lld-link"
export AR="llvm-ar"
export RANLIB="llvm-ranlib"

################################################################################
# 6) Build via wine‑tkg
################################################################################

cd wine-tkg-git
echo "--- Running tkg build"
./prepare.sh --cross

################################################################################
# 7) Install build to staging
################################################################################

STAGING="$(pwd)/../wcp/install"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"

make -C non-makepkg-builds install DESTDIR="${STAGING}"

################################################################################
# 8) Create wcp structure
################################################################################

cd "${STAGING}"
mkdir -p wcp/bin
mkdir -p wcp/lib/wine
mkdir -p wcp/share

cp -a usr/local/bin/* wcp/bin/ 2>/dev/null || cp -a usr/bin/* wcp/bin/
cd wcp/bin && ln -sf wine64 wine && cd ../..

cp -a usr/local/lib/wine/* wcp/lib/wine/ 2>/dev/null || cp -a usr/lib/wine/* wcp/lib/wine/
cp -a usr/local/share/* wcp/share/ 2>/dev/null || cp -a usr/share/* wcp/share/

find wcp/bin -type f -exec chmod +x {} +
find wcp/lib -name "*.so*" -exec chmod +x {} +

################################################################################
# 9) Write info.json & env.sh
################################################################################

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

################################################################################
# 10) Package into .wcp (tar.xz)
################################################################################

WCP="${GITHUB_WORKSPACE:-$(pwd)}/wine-11.1-staging-s8g1.wcp"

echo "--- Creating WCP"
tar -cJf "${WCP}" -C wcp .

echo "=== Built: ${WCP} ==="
echo "=== Wine ARM64EC WCP done ==="