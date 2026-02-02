#!/usr/bin/env bash
set -euxo pipefail

#####################################
# Basic defaults (prevent unbound)
#####################################
: "${CFLAGS:=}"
: "${CXXFLAGS:=}"
: "${LDFLAGS:=}"
: "${PKG_CONFIG_PATH:=}"
: "${PKG_CONFIG_LIBDIR:=}"
: "${PKG_CONFIG_SYSROOT_DIR:=}"

#####################################
# PREFIX_DEPS
#####################################
if [ -z "${PREFIX_DEPS:-}" ]; then
    PREFIX_DEPS="${PWD}/deps/install"
fi

#####################################
# Environment (Cross Toolchain)
#####################################
export TOOLCHAIN="aarch64-w64-mingw32"
export CC="${TOOLCHAIN}-clang"
export CXX="${TOOLCHAIN}-clang++"
export AR="${TOOLCHAIN}-ar"
export RANLIB="${TOOLCHAIN}-ranlib"
export WINDRES="${TOOLCHAIN}-windres"

# PKG_CONFIG pointing to built deps
export PKG_CONFIG_PATH="$PREFIX_DEPS/lib/pkgconfig:$PREFIX_DEPS/share/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$PREFIX_DEPS"
export PKG_CONFIG_LIBDIR="$PREFIX_DEPS/lib/pkgconfig"

# Include/Lib flags for deps
export CFLAGS="-I${PREFIX_DEPS}/include ${CFLAGS}"
export CXXFLAGS="-I${PREFIX_DEPS}/include ${CXXFLAGS}"
export LDFLAGS="-L${PREFIX_DEPS}/lib ${LDFLAGS}"

#####################################
# Clone Wine + patches
#####################################
git clone --depth 1 --branch wine-11.1 https://gitlab.winehq.org/wine/wine.git wine
git clone --depth 1 --branch v11.1 https://github.com/wine-staging/wine-staging.git wine-staging
git clone https://github.com/Frogging-Family/wine-tkg-git.git wine-tkg

#####################################
# Apply Wine‑Staging patches
#####################################
cd wine
python3 ../wine-staging/staging/patchinstall.py --all --destdir="$(pwd)"
cd ..

#####################################
# Apply wine‑tkg patches
#####################################
cd wine
mkdir -p rejects logs diffs
> applied-patches.list

BASE_TKG="../wine-tkg/wine-tkg-git/wine-tkg-patches"
PATCH_ROOTS=(
    "${BASE_TKG}/mainline"
    "${BASE_TKG}/staging"
    "${BASE_TKG}/hotfixes"
    "${BASE_TKG}/misc"
    "${BASE_TKG}/proton"
    "${BASE_TKG}/community-patches"
)

for root in "${PATCH_ROOTS[@]}"; do
    if [ -d "$root" ]; then
        find "$root" -type f -name "*.patch" | sort | while read -r patchfile; do
            echo "Applying $patchfile" >> apply-patch.log
            git diff > before.diff || true
            patch -p1 --forward < "$patchfile" > "logs/$(basename "$patchfile").out" 2>&1 || true

            if grep -q -E "Hunk FAILED|fail" "logs/$(basename "$patchfile").out"; then
                if ls *.rej 1> /dev/null 2>&1; then
                    mkdir -p rejects
                    mv *.rej "rejects/$(basename "$patchfile").rej" || true
                fi
            else
                echo "$patchfile" >> applied-patches.list
                git diff > "diffs/$(basename "$patchfile").diff" || true
            fi
        done
    fi
done
cd ..

#####################################
# Build wine‑tools natively (for build)
#####################################
echo "=== Building native wine-tools ==="
cd wine

mkdir -p wine-tools-native
cd wine-tools-native

../configure \
  --build="$(../config.guess)" \
  --host="$(../config.guess)" \
  --prefix="${PREFIX_DEPS}/wine-tools-native" \
  --disable-tests \
  --disable-win16 \
  --enable-tools \
  CC="$(clang)" \
  CXX="$(clang++)" \
  AR="ar" \
  RANLIB="ranlib" \
  PKG_CONFIG_PATH="${PKG_CONFIG_PATH}"

make -j"$(nproc)"
make install

cd ..

#####################################
# Configure & compile Wine proper
#####################################
cd wine
mkdir -p build
cd build

export BUILD=$(../config.guess)
export HOST=aarch64-w64-mingw32

echo ">>> pkg-config deps summary:"
pkg-config --cflags --libs freetype2 fontconfig sdl2 libusb expat harfbuzz brotli || true

../configure \
    --build="$BUILD" \
    --host="$HOST" \
    --with-mingw=clang \
    --with-wine-tools="../wine-tools-native/bin" \
    --prefix=/usr \
    --enable-win64 \
    --enable-wow64 \
    --enable-archs=arm64ec,aarch64 \
    --disable-tests \
    --without-mono \
    --without-gecko \
    --with-freetype \
    --with-fontconfig \
    --with-sdl2 \
    --with-dbus \
    --with-vulkan \
    --with-lcms2 \
    --with-libtiff \
    --with-libusb \
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH"

make -j"$(nproc)"

#####################################
# Build DXVK
#####################################
cd ../..

git clone https://github.com/doitsujin/dxvk.git dxvk
cd dxvk
git submodule update --init --recursive

pip3 install meson ninja
meson setup build --cross-file=../wine/build/config/meson.cross.arm64ec.ini \
    --prefix=/usr -Dbuild_tests=false
ninja -C build install
cd ..

#####################################
# Build VKD3D‑Proton
#####################################
git clone https://github.com/HansKristian-Work/vkd3d-proton.git vkd3d
cd vkd3d
git submodule update --init --recursive

meson setup build --cross-file=../wine/build/config/meson.cross.arm64ec.ini \
    --prefix=/usr -Dbuild_tests=false
ninja -C build install
cd ..

#####################################
# Package .wcp
#####################################
cd wine/build
DESTDIR=$PWD/install make install
cd install

mkdir -p wcp/{bin,lib,share}
cp -a usr/bin/* wcp/bin/ || true
cp -a usr/lib/wine/* wcp/lib/ || true
cp -a usr/share/* wcp/share/ || true

cd wcp/bin && ln -sf wine64 wine

find . -type f -exec chmod +x {} \;

cat > profile.json << 'EOF'
{
    "id": "wine-11.1-staging-tkg-arm64ec",
    "name": "Wine 11.1 Staging-TkG Arm64EC",
    "version": "11.1",
    "arch": "arm64ec",
    "files": {"bin":"bin/","lib":"lib/","share":"share/"}
}
EOF

tar -cJf "$PWD/../../../wine-11.1-staging-tkg-arm64ec.wcp" profile.json wcp

echo "=== Wine build complete ==="
