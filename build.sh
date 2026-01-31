#!/usr/bin/env bash
set -euxo pipefail

#####################################
# Install host deps (optional)
#####################################
if command -v sudo &>/dev/null && command -v apt &>/dev/null; then
    sudo apt update
    sudo apt install -y --no-install-recommends \
      build-essential autoconf automake libtool pkg-config \
      python3 python3-pip git gettext flex bison \
      ninja-build cmake meson \
      libasound2-dev libpulse-dev libv4l-dev \
      libx11-dev libxext-dev libxfixes-dev libxinerama-dev \
      libxi-dev libxrandr-dev libxrender-dev \
      libfontconfig-dev \
      libgnutls28-dev libdbus-1-dev libsdl2-dev \
      libjpeg-dev libpng-dev libxml2-dev \
      libudev-dev libusb-1.0-0-dev libldap2-dev \
      libxkbcommon-dev libxv-dev libxxf86vm-dev \
      libxcursor-dev libxss-dev \
      libvulkan-dev lld llvm clang
fi

#####################################
# Configure env
#####################################
PREFIX_DEPS="${PWD}/deps/install"
mkdir -p "$PREFIX_DEPS"/{lib/pkgconfig,include,bin}
mkdir -p deps/build

export TOOLCHAIN=aarch64-w64-mingw32
export CC=${TOOLCHAIN}-clang
export CXX=${TOOLCHAIN}-clang++
export AR=${TOOLCHAIN}-ar
export RANLIB=${TOOLCHAIN}-ranlib
export WINDRES=${TOOLCHAIN}-windres

# Ensure variables exist for 'set -u'
export PKG_CONFIG_PATH="${PREFIX_DEPS}/lib/pkgconfig${PKG_CONFIG_PATH:+:}$PKG_CONFIG_PATH"
export PKG_CONFIG_SYSROOT_DIR="$PREFIX_DEPS"
export CFLAGS="-I$PREFIX_DEPS/include${CFLAGS:+ }$CFLAGS"
export LDFLAGS="-L$PREFIX_DEPS/lib${LDFLAGS:+ }$LDFLAGS"

#####################################
# 1) Core deps
#####################################
cd deps/build

git clone --depth=1 https://github.com/madler/zlib.git zlib
cd zlib
./configure --prefix="$PREFIX_DEPS" --static
make -j"$(nproc)" && make install
cd ..

git clone --depth=1 https://github.com/glennrp/libpng.git libpng
cd libpng
./configure --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" --disable-shared --enable-static \
  CPPFLAGS="-I$PREFIX_DEPS/include" LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ..

git clone --depth=1 https://github.com/libjpeg-turbo/libjpeg-turbo.git libjpeg
cd libjpeg
cmake -S . -B build \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_SYSTEM_PROCESSOR=ARM64 \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX_DEPS" \
  -DENABLE_SHARED=OFF -DENABLE_STATIC=ON
cmake --build build --parallel "$(nproc)"
cmake --install build
cd ..

git clone --depth=1 https://git.savannah.gnu.org/git/freetype/freetype2.git freetype2
cd freetype2
mkdir -p build && cd build
../configure --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static \
  CPPFLAGS="-I$PREFIX_DEPS/include" \
  LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ../..

git clone --depth=1 https://gitlab.com/gnutls/gnutls.git gnutls
cd gnutls
./bootstrap.sh
./configure --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static --disable-doc \
  CPPFLAGS="-I$PREFIX_DEPS/include" \
  LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ..

#####################################
# 2) Extended deps
#####################################

git clone --depth=1 https://gitlab.freedesktop.org/fontconfig/fontconfig.git fontconfig
cd fontconfig
autoreconf -fi
./configure --host="$TOOLCHAIN" --prefix="$PREFIX_DEPS" \
  CPPFLAGS="-I$PREFIX_DEPS/include" LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ..

git clone --depth=1 https://github.com/harfbuzz/harfbuzz.git harfbuzz
cd harfbuzz
cat > cross.ini << 'EOF'
[binaries]
c = '${CC}'
cxx = '${CXX}'
ar = '${AR}'
ranlib = '${RANLIB}'
pkgconfig = 'pkg-config'

[host_machine]
system = 'windows'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF
meson setup build --cross-file=cross.ini \
  -Dfontconfig=enabled -Dfreetype=enabled \
  --prefix="$PREFIX_DEPS"
ninja -C build install
cd ..

git clone --depth=1 https://gitlab.gnome.org/GNOME/libxml2.git libxml2
cd libxml2
mkdir -p build && cd build
cat > cross_file.xml << 'EOF'
<toolchain>
  <c compiler='${CC}' />
  <cxx compiler='${CXX}' />
  <ar program='${AR}' />
  <ranlib program='${RANLIB}' />
</toolchain>
EOF
cmake -DCMAKE_TOOLCHAIN_FILE=cross_file.xml \
  -DCMAKE_INSTALL_PREFIX="$PREFIX_DEPS" \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DLIBXML2_WITH_PIC=ON \
  -DLIBXML2_BUILD_TESTS=OFF ..
cmake --build . --parallel "$(nproc)" && cmake --install .
cd ../..

git clone --depth=1 https://github.com/libsdl-org/SDL.git SDL2
cd SDL2
mkdir -p build && cd build
cmake -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_SYSTEM_PROCESSOR=ARM64 \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX_DEPS" \
  -DSDL_SHARED=OFF -DSDL_STATIC=ON ..
cmake --build . --parallel "$(nproc)" && cmake --install .
cd ../..

git clone --depth=1 https://github.com/libusb/libusb.git libusb
cd libusb
mkdir -p build && cd build
cmake -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_SYSTEM_PROCESSOR=ARM64 \
  -DCMAKE_INSTALL_PREFIX="$PREFIX_DEPS" \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DENABLE_SHARED=OFF -DENABLE_STATIC=ON ..
cmake --build . --parallel "$(nproc)" && cmake --install .
cd ../..

git clone --depth=1 https://gitlab.com/libtiff/libtiff.git libtiff
cd libtiff
mkdir -p build && cd build
cmake -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_SYSTEM_PROCESSOR=ARM64 \
  -DCMAKE_INSTALL_PREFIX="$PREFIX_DEPS" \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DBUILD_SHARED_LIBS=OFF ..
cmake --build . --parallel "$(nproc)" && cmake --install .
cd ../..

git clone --depth=1 https://github.com/mm2/Little-CMS.git lcms2
cd lcms2
mkdir -p build && cd build
cmake -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_SYSTEM_PROCESSOR=ARM64 \
  -DCMAKE_INSTALL_PREFIX="$PREFIX_DEPS" \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DBUILD_SHARED_LIBS=OFF ..
cmake --build . --parallel "$(nproc)" && cmake --install .
cd ../..

git clone --depth=1 https://github.com/gphoto/libgphoto2.git libgphoto2
cd libgphoto2
mkdir -p build && cd build
cmake -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_SYSTEM_PROCESSOR=ARM64 \
  -DCMAKE_INSTALL_PREFIX="$PREFIX_DEPS" \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DENABLE_SHARED=OFF -DENABLE_STATIC=ON ..
cmake --build . --parallel "$(nproc)" && cmake --install .
cd ../..

echo "=== All deps built to $PREFIX_DEPS ==="
