#!/usr/bin/env bash
set -Eeuo pipefail

echo
echo "======================================================="
echo " Starting Wine ARM64EC build @ $(date)"
echo "======================================================="
echo

#########################################################################
# 1) Set up LLVM ‑ MinGW cross toolchain
#########################################################################

LLVM_VER="${LLVM_MINGW_VER:-20251216}"
LLVM_ARCHIVE="llvm-mingw-${LLVM_VER}-ucrt-ubuntu-22.04-x86_64.tar.xz"
LLVM_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_VER}/${LLVM_ARCHIVE}"

LLVM_PREFIX="/opt/llvm-mingw"
LLVM_BIN="${LLVM_PREFIX}/bin"

echo "--- Ensuring LLVM‑MinGW cross toolchain exists"
if [[ ! -d "${LLVM_PREFIX}" ]]; then
    echo "Downloading LLVM‑MinGW toolchain: ${LLVM_ARCHIVE}"
    wget -q "${LLVM_URL}" -O "/tmp/${LLVM_ARCHIVE}"
    mkdir -p "${LLVM_PREFIX}"
    tar -xJf "/tmp/${LLVM_ARCHIVE}" -C "${LLVM_PREFIX}" --strip-components=1
fi

echo "LLVM‑MinGW bin => ${LLVM_BIN}"
export PATH="${LLVM_BIN}:${PATH}"

echo "--- Verify toolchain"
clang --version || true
clang --target=arm64ec-w64-windows-gnu --version || true
lld --version || true
lld-link --version || true
echo

#########################################################################
# 2) Clone upstream build system and sources
#########################################################################

WORKDIR="${PWD}"

echo "--- Cloning wine‑tkg‑git"
git clone https://github.com/Frogging-Family/wine-tkg-git.git wine-tkg-git

echo "--- Cloning Wine ARM64EC source"
git clone --branch arm64ec https://github.com/AndreRH/wine.git wine

echo "--- Cloning Wine‑staging patches"
git clone https://github.com/wine-staging/wine-staging.git wine-staging

#########################################################################
# 3) Move sources into expected wine‑tkg structure
#########################################################################

echo "--- Copying Wine into wine‑tkg"
cp -r wine wine-tkg-git/wine

echo "--- Copying staging into wine‑tkg"
cp -r wine-staging wine-tkg-git/wine-staging

if [[ -d "${WORKDIR}/wine-tkg-patches" ]]; then
    echo "--- Copying custom tkg patches"
    cp -r "${WORKDIR}/wine-tkg-patches" wine-tkg-git/
fi

#########################################################################
# 4) Create customization.cfg
#########################################################################

cat > wine-tkg-git/customization.cfg <<EOF
_wine_git_repo="https://github.com/AndreRH/wine.git"
_wine_git_branch="arm64ec"
_use_staging="yes"
_staging_level="default"
# disable unnecessary wrapper compilers
_ccache=""
# sysroot and flags injected by environment
EOF

echo "--- customization.cfg"
cat wine-tkg-git/customization.cfg
echo

#########################################################################
# 5) Build with wine‑tkg
#########################################################################

echo "--- Starting wine‑tkg build"
cd wine-tkg-git

export CC="clang --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link"
export CXX="clang++ --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link"
export LD="lld-link"
export AR="llvm-ar"
export RANLIB="llvm-ranlib"

echo "CC=${CC}"
echo "CXX=${CXX}"
echo "LD=${LD}"
echo "AR=${AR}"

chmod +x non-makepkg-build.sh

./non-makepkg-build.sh \
    --enable-win64 \
    --host=arm64ec-w64-mingw32 \
    --enable-archs=arm64ec,aarch64,i386 \
    --with-mingw=clang

echo
echo "======================================================="
echo " Build complete @ $(date)"
echo "======================================================="