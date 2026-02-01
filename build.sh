#!/usr/bin/env bash
set -euxo pipefail

####################################
# System host deps (Ubuntu)
####################################
if command -v apt &>/dev/null && command -v sudo &>/dev/null; then
  sudo apt update
sudo apt install -y --no-install-recommends \
  build-essential autoconf automake libtool gettext gperf \
  flex bison ninja-build cmake meson pkg-config \
  python3 python3-pip git wget unzip \
  intltool gtk-doc-tools \
  libasound2-dev libpulse-dev libv4l-dev \
  libx11-dev libxext-dev libxfixes-dev libxinerama-dev \
  libxi-dev libxrandr-dev libxrender-dev \
  libfontconfig-dev \
  libdbus-1-dev libsdl2-dev \
  libjpeg-dev libpng-dev libxml2-dev \
  libudev-dev libusb-1.0-0-dev libldap2-dev \
  libxkbcommon-dev libxv-dev libxxf86vm-dev \
  libxcursor-dev libxss-dev \
  libvulkan-dev llvm clang lld \
  gettext autopoint autoconf automake libtool \
  
fi

####################################
# Prepare prefix & environment
####################################
PREFIX_DEPS="${PWD}/deps/install"
mkdir -p "$PREFIX_DEPS"/{bin,include,lib/pkgconfig}
mkdir -p deps/build
cd deps/build

####################################
# Build cross pkgconf (pkg-config for target)
####################################
echo ">>> Build cross pkgconf"
wget -q https://distfiles.dereferenced.org/pkgconf/pkgconf-2.5.1.tar.xz
tar xf pkgconf-2.5.1.tar.xz
cd pkgconf-2.5.1

./configure \
  --host=aarch64-w64-mingw32 \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static
make -j"$(nproc)" && make install
cd ..

# Create target pkg-config
(
  cd "$PREFIX_DEPS/bin"
  ln -sf pkgconf aarch64-w64-mingw32-pkg-config
  ln -sf pkgconf pkg-config
)

export PATH="$PREFIX_DEPS/bin:$PATH"
export PKG_CONFIG_PATH="$PREFIX_DEPS/lib/pkgconfig${PKG_CONFIG_PATH+:}${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_SYSROOT_DIR="$PREFIX_DEPS"

####################################
# Compiler / toolchain
####################################
export TOOLCHAIN=aarch64-w64-mingw32

export CC="${TOOLCHAIN}-clang"
export CXX="${TOOLCHAIN}-clang++"
export AR="${TOOLCHAIN}-ar"
export RANLIB="${TOOLCHAIN}-ranlib"
export WINDRES="${TOOLCHAIN}-windres"

export CFLAGS="-I$PREFIX_DEPS/include${CFLAGS+: }${CFLAGS:-}"
export LDFLAGS="-L$PREFIX_DEPS/lib${LDFLAGS+: }${LDFLAGS:-}"

####################################
# Helper: build autotools deps
####################################
build_autotools_dep() {
  local url="$1"
  local name="$2"
  wget -q "$url"
  tar xf "${url##*/}"
  cd "$name"
  ./configure \
    --host="$TOOLCHAIN" \
    --prefix="$PREFIX_DEPS" \
    --disable-shared --enable-static \
    CPPFLAGS="-I$PREFIX_DEPS/include" \
    LDFLAGS="-L$PREFIX_DEPS/lib"
  make -j"$(nproc)" && make install
  cd ..
}

####################################
# 1) zlib
####################################
git clone --depth=1 https://github.com/madler/zlib.git zlib
cd zlib
./configure --host="$TOOLCHAIN" --prefix="$PREFIX_DEPS" --static
make -j"$(nproc)" && make install
cd ..


make -j"$(nproc)" && make install
cd ..
####################################
# 2) libpng
####################################
build_autotools_dep \
  https://download.sourceforge.net/libpng/libpng-1.6.40.tar.xz \
  libpng-1.6.40

####################################
# 3) libjpeg
####################################
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


####################################
# Build expat
####################################

echo ">>> Build expat"
wget -q https://github.com/libexpat/libexpat/releases/download/R_2_7_4/expat-2.7.4.tar.xz
tar xf expat-2.7.4.tar.xz
cd expat-2.7.4

./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static \
  --with-pkgconfigdir="$PREFIX_DEPS/lib/pkgconfig" \
  CPPFLAGS="-I$PREFIX_DEPS/include" \
  LDFLAGS="-L$PREFIX_DEPS/lib"

make -j"$(nproc)" && make install
cd ..

# Make sure pkg-config sees expat
export PKG_CONFIG_PATH="$PREFIX_DEPS/lib/pkgconfig${PKG_CONFIG_PATH+:}${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_LIBDIR="$PREFIX_DEPS/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$PREFIX_DEPS"

echo ">>> Check expat pkg-config"
pkg-config --modversion expat
pkg-config --cflags expat
pkg-config --libs expat

####################################
# Build fontconfig
####################################

echo ">>> Build fontconfig 2.16.0"
wget -q https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.16.0.tar.xz
tar xf fontconfig-2.16.0.tar.xz
cd fontconfig-2.16.0

# Provide include paths so freetype and expat can be found
export CPPFLAGS="-I$PREFIX_DEPS/include -I$PREFIX_DEPS/include/freetype2"
export LDFLAGS="-L$PREFIX_DEPS/lib"

./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static \
  CPPFLAGS="$CPPFLAGS" \
  LDFLAGS="$LDFLAGS"

make -j"$(nproc)" && make install
cd ..

####################################
# 4) freetype2
####################################
build_autotools_dep \
  https://download.savannah.gnu.org/releases/freetype/freetype-2.14.1.tar.xz \
  freetype-2.14.1

####################################
# 5) GMP
####################################
build_autotools_dep \
  https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz \
  gmp-6.3.0

####################################
# 6) nettle + hogweed
####################################
build_autotools_dep \
  https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz \
  nettle-3.10.2

####################################
# 7) libtasn1
####################################
build_autotools_dep \
  https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.21.0.tar.gz \
  libtasn1-4.21.0

####################################
# 8) libunistring
####################################
wget -q https://ftp.gnu.org/gnu/libunistring/libunistring-1.1.tar.xz
tar xf libunistring-1.1.tar.xz
cd libunistring-1.1
./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static \
  --disable-tests \
  CPPFLAGS="-I$PREFIX_DEPS/include" \
  LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ..

####################################
# 9) libev 4.33
####################################
echo ">>> Build libev 4.33"
wget -q https://dist.schmorp.de/libev/libev-4.33.tar.gz
tar xf libev-4.33.tar.gz
cd libev-4.33
./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static \
  CPPFLAGS="-I$PREFIX_DEPS/include" \
  LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ..


####################################
# 12) harfbuzz
####################################
git clone --depth=1 https://github.com/harfbuzz/harfbuzz.git harfbuzz
cd harfbuzz

meson setup build \
  --cross-file=<(cat <<EOF
[binaries]
c = '$CC'
cxx = '$CXX'
ar = '$AR'
pkgconfig = 'pkg-config'
[host_machine]
system = 'windows'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF
  ) \
  --prefix="$PREFIX_DEPS" \
  -Dfreetype=true \
  -Dglib=false \
  -Dgobject=false \
  -Dcairo=false \
  -Dicu=false \
  -Dgraphite2=false \
  -Dfontations=false \
  -Ddirectwrite=false \
  -Dcoretext=false \
  -Dtests=false \
  -Dutilities=true

meson compile -C build --parallel "$(nproc)"
meson install -C build
cd ..

####################################
# 13+) Remaining deps
####################################
# SDL2
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
