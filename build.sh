#!/usr/bin/env bash
set -Eeuo pipefail

echo
echo "======================================================="
echo " Starting Wine WCP build @ $(date)"
echo "======================================================="
echo

#########################################################################
# 1) Setup LLVM‑MinGW cross toolchain for Windows
#########################################################################

LLVM_VER="${LLVM_MINGW_VER:-20251216}"
LLVM_ARCHIVE="llvm-mingw-${LLVM_VER}-ucrt-ubuntu-22.04-x86_64.tar.xz"
LLVM_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_VER}/${LLVM_ARCHIVE}"
LLVM_PREFIX="/opt/llvm-mingw"
LLVM_BIN="${LLVM_PREFIX}/bin"

echo "--- Setting up LLVM‑MinGW cross toolchain…"
if [[ ! -d "${LLVM_PREFIX}" ]]; then
    echo "Downloading: ${LLVM_ARCHIVE}"
    wget -q "${LLVM_URL}" -O "/tmp/${LLVM_ARCHIVE}"
    mkdir -p "${LLVM_PREFIX}"
    tar -xJf "/tmp/${LLVM_ARCHIVE}" -C "${LLVM_PREFIX}" --strip-components=1
else
    echo "Toolchain already exists at ${LLVM_PREFIX}"
fi

echo "Adding LLVM‑MinGW to PATH"
export PATH="${LLVM_BIN}:${PATH}"

echo "--- Verify cross toolchain"
clang --version || true
clang --target=arm64ec-w64-windows-gnu --version || true
lld --version || true
lld-link --version || true
echo

#########################################################################
# 2) Apply optimized C/C++ flags
#########################################################################

echo "--- Applying optimization flags"

# Aggressive optimization for modern ARM64EC
OPT_FLAGS_ARM64EC="-O3 \
    -mcpu=arm64-v8-a \
    -march=arm64-v8-a \
    -funroll-loops \
    -fomit-frame-pointer \
    -mllvm -vectorize-loops \
    -mllvm -slp-vectorizer"

# If x86_64 build paths exist, define fallback
OPT_FLAGS_X86_64="-O3 \
    -mcpu=x86-64 \
    -funroll-loops \
    -fomit-frame-pointer \
    -mllvm -vectorize-loops \
    -mllvm -slp-vectorizer"

echo "CFLAGS (ARM64EC) = ${OPT_FLAGS_ARM64EC}"
echo "CXXFLAGS (ARM64EC) = ${OPT_FLAGS_ARM64EC}"

export CFLAGS="${OPT_FLAGS_ARM64EC}"
export CXXFLAGS="${OPT_FLAGS_ARM64EC}"
export CPPFLAGS=""

#########################################################################
# 3) Set cross compilers for Windows
#########################################################################

echo "--- Setting cross compilers"

export CC="clang --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link"
export CXX="clang++ --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link"
export LD="lld-link"
export AR="llvm-ar"
export RANLIB="llvm-ranlib"

echo "CC  = ${CC}"
echo "CXX = ${CXX}"
echo "LD  = ${LD}"
echo "AR  = ${AR}"
echo

#########################################################################
# 4) Run internal Wine build logic
#########################################################################

echo "--- Running internal build logic (build.sh core)"

# Make sure script is executable
chmod +x ./build.sh

# Run the actual build with the cross compilers and flags applied
# Since the repo uses a single script, we re‑invoke it with overrides
exec "${CC}" --version >/dev/null 2>&1 || :

# Now call the in‑repo build actions
./build.sh

#########################################################################
# 5) Final note
#########################################################################

echo
echo "======================================================="
echo " Wine WCP build finished @ $(date)"
echo "======================================================="