#!/usr/bin/env bash
set -euxo pipefail

####################################
# Install system dependencies (Ubuntu)
####################################
if command -v apt &>/dev/null && command -v sudo &>/dev/null; then
  sudo apt update
  sudo apt install -y --no-install-recommends \
    build-essential autoconf automake libtool pkg-config \
    gettext gperf gtk-doc-tools autopoint \
    flex bison ninja-build cmake meson \
    python3 python3-pip git wget \
    libasound2-dev libpulse-dev libv4l-dev \
    libx11-dev libxext-dev libxfixes-dev libxinerama-dev \
    libxi-dev libxrandr-dev libxrender-dev \
    libfontconfig-dev \
    libdbus-1-dev libsdl2-dev \
    libjpeg-dev libpng-dev libxml2-dev \
    libudev-dev libusb-1.0-0-dev libldap2-dev \
    libxkbcommon-dev libxv-dev libxxf86vm-dev \
    libxcursor-dev libxss-dev \
    libvulkan-dev llvm clang lld
fi

#####################################
# Prepare prefix & environment
#####################################
PREFIX_DEPS="${PWD}/deps/install"
mkdir -p "$PREFIX_DEPS"/{bin,include,lib/pkgconfig}
mkdir -p deps/build
cd deps/build

export TOOLCHAIN=aarch64-w64-mingw32
export CC=${TOOLCHAIN}-clang
export CXX=${TOOLCHAIN}-clang++
export AR=${TOOLCHAIN}-ar
export RANLIB=${TOOLCHAIN}-ranlib
export WINDRES=${TOOLCHAIN}-windres

export PKG_CONFIG_PATH="$PREFIX_DEPS/lib/pkgconfig${PKG_CONFIG_PATH+:}${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_SYSROOT_DIR="$PREFIX_DEPS"
export CFLAGS="-I$PREFIX_DEPS/include${CFLAGS+: }${CFLAGS:-}"
export LDFLAGS="-L$PREFIX_DEPS/lib${LDFLAGS+: }${LDFLAGS:-}"

#####################################
# 1) zlib
#####################################
git clone --depth=1 https://github.com/madler/zlib.git zlib
cd zlib
./configure --prefix="$PREFIX_DEPS" --static
make -j"$(nproc)" && make install
cd ..

#####################################
# 2) libpng
#####################################
wget -q https://download.sourceforge.net/libpng/libpng-1.6.40.tar.xz
tar xf libpng-1.6.40.tar.xz
cd libpng-1.6.40
./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static \
  CPPFLAGS="-I$PREFIX_DEPS/include" \
  LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ..

#####################################
# 3) libjpeg
#####################################
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

#####################################
# 4) freetype2
#####################################
wget -q https://download.savannah.gnu.org/releases/freetype/freetype-2.14.1.tar.xz
tar xf freetype-2.14.1.tar.xz
cd freetype-2.14.1
./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static \
  --without-brotli \
  CPPFLAGS="-I$PREFIX_DEPS/include" \
  LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ..

#####################################
# 5) GMP (for nettle hogweed)
#####################################
wget -q https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz -O gmp-6.3.0.tar.xz
tar xf gmp-6.3.0.tar.xz
cd gmp-6.3.0
./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared \
  --enable-static \
  --enable-cxx
make -j"$(nproc)" && make install
cd ..

#####################################
# 6) nettle + hogweed
#####################################
wget -q https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz -O nettle-3.10.2.tar.gz
tar xf nettle-3.10.2.tar.gz
cd nettle-3.10.2
./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static \
  --with-gmp \
  CPPFLAGS="-I$PREFIX_DEPS/include" \
  LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ..

#####################################
# libtasn1 (required for GnuTLS)
#####################################
echo ">>> Cross‑compile libtasn1 (ASN.1 library)"

wget -q https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.21.0.tar.gz \
    -O libtasn1-4.21.0.tar.gz
tar xf libtasn1-4.21.0.tar.gz
cd libtasn1-4.21.0

./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static \
  CPPFLAGS="-I$PREFIX_DEPS/include" \
  LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ..

#####################################
# 8) libunistring
#####################################
wget -q https://ftp.gnu.org/gnu/libunistring/libunistring-1.1.tar.xz \
    -O libunistring-1.1.tar.xz
tar xf libunistring-1.1.tar.xz
cd libunistring-1.1
./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static
make -j"$(nproc)" && make install
cd ..

#####################################
# 9) GnuTLS
#####################################
git clone --depth=1 https://gitlab.com/gnutls/gnutls.git gnutls
cd gnutls
git submodule update --init --recursive
./bootstrap
./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared \
  --enable-static \
  --with-included-unistring \
  --with-included-libtasn1 \
  CPPFLAGS="-I$PREFIX_DEPS/include" \
  LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ..

#####################################
# 10) fontconfig
#####################################
git clone --depth=1 https://gitlab.freedesktop.org/fontconfig/fontconfig.git fontconfig
cd fontconfig
autoreconf -fi
./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  CPPFLAGS="-I$PREFIX_DEPS/include" \
  LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ..

#####################################
# 11) harfbuzz
#####################################
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

#####################################
# 12) libxml2
#####################################
git clone --depth=1 https://gitlab.gnome.org/GNOME/libxml2.git libxml2
cd libxml2
mkdir -p build && cd build
cat > xml.toolchain.cmake << 'EOF'
...
EOF
cmake -DCMAKE_TOOLCHAIN_FILE="../xml.toolchain.cmake" \
      -DLIBXML2_WITH_PIC=ON \
      -DLIBXML2_BUILD_TESTS=OFF ..
cmake --build . --parallel "$(nproc)" && cmake --install .
cd ../..

#####################################
# 13+) remaining deps (SDL2, libusb, libtiff, lcms2, libgphoto2)
#####################################

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

echo "=== All deps built at $PREFIX_DEPS ==="
