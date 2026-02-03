#!/usr/bin/env bash
set -euxo pipefail

####################################
# System host deps (Ubuntu ARM)
####################################
if command -v apt &>/dev/null && command -v sudo &>/dev/null; then
  sudo apt update

  # Core build tools
  sudo apt install -y --no-install-recommends \
    build-essential autoconf automake libtool gettext gettext‑tools \
    gperf gawk m4 patch \
    bison flex

  # Meson, Ninja, CMake, pkg‑config for host builds
  sudo apt install -y --no-install-recommends \
    meson ninja-build cmake pkg-config

  # Python3 tooling
  sudo apt install -y --no-install-recommends \
    python3 python3-pip python3-setuptools python3-venv python3-docutils

  # Dev headers for libraries used in Wine + your deps
  sudo apt install -y --no-install-recommends \
    libfreetype6-dev libfontconfig1-dev libexpat1-dev \
    libjpeg-dev libpng-dev libxml2-dev liblzma-dev zlib1g-dev \
    liblcms2-dev libbsd-dev

  # X11 / windowing libs (needed for Wine X11 support)
  sudo apt install -y --no-install-recommends \
    libx11-dev libxext-dev libxfixes-dev libxi-dev \
    libxrandr-dev libxcursor-dev libxinerama-dev \
    libxxf86vm-dev libxss-dev libxv-dev \
    libdbus-1-dev

  # Sound, input and multimedia
  sudo apt install -y --no-install-recommends \
    libasound2-dev libpulse-dev libsdl2-dev \
    libudev-dev libusb-1.0-0-dev libldap2-dev

  # LLVM/Clang suite (optional, but needed for your clang use)
  sudo apt install -y --no-install-recommends \
    clang lld llvm

  echo ">>> apt dependencies installed successfully"
fi

####################################
# Prepare
####################################

PREFIX_DEPS="${PWD}/deps/install"

mkdir -p "$PREFIX_DEPS"/{bin,include,lib/pkgconfig}
mkdir -p deps/build
cd deps/build

####################################
# Cross Compiler
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
# 4) libtiff
####################################
echo "=== Building libtiff ==="
build_autotools_dep \
  "https://download.osgeo.org/libtiff/tiff-4.5.0.tar.gz" \
  "tiff-4.5.0"

####################################
# 5) brotli
####################################
echo "=== Building brotli from source (static) ==="
git clone --depth=1 https://github.com/google/brotli.git brotli
cd brotli

cat > brotli-toolchain.cmake <<EOF
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER ${CC})
set(CMAKE_CXX_COMPILER ${CXX})
set(CMAKE_RC_COMPILER ${WINDRES})
set(CMAKE_FIND_ROOT_PATH ${PREFIX_DEPS})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(BROTLI_DISABLE_TESTS ON)
set(BROTLI_DISABLE_TOOLS ON)
EOF

mkdir -p build-brotli && cd build-brotli
cmake -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=../brotli-toolchain.cmake \
  -DCMAKE_INSTALL_PREFIX=${PREFIX_DEPS} \
  -DBROTLI_BUILD_SHARED_LIBS=OFF \
  -DBROTLI_DISABLE_TESTS=ON \
  ..
ninja install
cd ../..

mkdir -p "$PREFIX_DEPS/lib/pkgconfig"
cat > "$PREFIX_DEPS/lib/pkgconfig/brotli.pc" <<EOF
prefix=${PREFIX_DEPS}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: brotli
Description: brotli static libs (common + decode + encode)
Version: 1.0
Libs: -L\${libdir} -lbrotlicommon -lbrotlidec -lbrotlienc
Cflags: -I\${includedir}
EOF

echo ">>> brotli static build completed."

####################################
# 6) freetype2
####################################
echo ">>> Building freetype2 (cross target)"
wget -q https://download-mirror.savannah.gnu.org/releases/freetype/freetype-2.14.1.tar.xz -O freetype-2.14.1.tar.xz
if [ ! -s freetype-2.14.1.tar.xz ]; then
  wget -q https://downloads.sourceforge.net/freetype/freetype-2.14.1.tar.xz -O freetype-2.14.1.tar.xz
fi
tar xf freetype-2.14.1.tar.xz
cd freetype-2.14.1
./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared \
  --enable-static \
  CPPFLAGS="-I${PREFIX_DEPS}/include" \
  LDFLAGS="-L${PREFIX_DEPS}/lib"
make -j"$(nproc)"
make install
cd ..

cat > "$PREFIX_DEPS/lib/pkgconfig/freetype2.pc" <<EOF
prefix=${PREFIX_DEPS}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include/freetype2

Name: freetype2
Description: FreeType 2 font rendering library
Version: 2.14.1
Libs: -L\${libdir} -lfreetype
Cflags: -I\${includedir}
EOF

####################################
# 7) libxml2
####################################
echo "=== Building libxml2 ==="
wget -q https://download.gnome.org/sources/libxml2/2.9/libxml2-2.9.14.tar.xz -O libxml2-2.9.14.tar.xz
tar xf libxml2-2.9.14.tar.xz
cd libxml2-2.9.14
./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static \
  --with-sax1 \
  CPPFLAGS="-I$PREFIX_DEPS/include" \
  LDFLAGS="-L$PREFIX_DEPS/lib"
make -j"$(nproc)" && make install
cd ..

####################################
# 8) expat
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

export PKG_CONFIG_PATH="$PREFIX_DEPS/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_LIBDIR="$PREFIX_DEPS/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$PREFIX_DEPS"

####################################
# Build native pkgconf & create cross wrapper
####################################
echo ">>> Building host pkgconf"
wget -q https://github.com/pkgconf/pkgconf/releases/download/pkgconf-1.8.0/pkgconf-1.8.0.tar.xz
tar xf pkgconf-1.8.0.tar.xz
cd pkgconf-1.8.0
./configure \
  --prefix="$PREFIX_DEPS/pkgconf-native" \
  --disable-shared \
  --enable-static
make -j"$(nproc)" && make install
cd ..

echo ">>> Creating cross pkg-config wrapper"
mkdir -p "$PREFIX_DEPS/bin"

cat > "$PREFIX_DEPS/bin/aarch64-w64-mingw32-pkg-config" << 'EOF'
#!/usr/bin/env bash
export PKG_CONFIG_SYSROOT_DIR="${PREFIX_DEPS}"
export PKG_CONFIG_LIBDIR="${PREFIX_DEPS}/lib/pkgconfig"
export PKG_CONFIG_PATH="${PREFIX_DEPS}/lib/pkgconfig"
exec "${PREFIX_DEPS}/pkgconf-native/bin/pkgconf" "$@"
EOF

chmod +x "$PREFIX_DEPS/bin/aarch64-w64-mingw32-pkg-config"
ln -sf aarch64-w64-mingw32-pkg-config "$PREFIX_DEPS/bin/pkg-config"

echo ">>> pkg-config wrapper ready"

####################################
# Build fontconfig 2.16.0
####################################
echo ">>> Build fontconfig 2.16.0"
wget -q https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.16.0.tar.xz
tar xf fontconfig-2.16.0.tar.xz
cd fontconfig-2.16.0

# Patch configure to accept freetype2 >= 2.14.1
sed -i 's/freetype2 >= 21.0.15/freetype2 >= 2.14.1/' configure

export CPPFLAGS="-I$PREFIX_DEPS/include -I$PREFIX_DEPS/include/freetype2"
export LDFLAGS="-L$PREFIX_DEPS/lib"

./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static
make -j"$(nproc)" && make install
cd ..

####################################
# Build HarfBuzz with brotli support
####################################
echo "=== Building HarfBuzz with brotli support ==="
git clone --depth=1 https://github.com/harfbuzz/harfbuzz.git harfbuzz
cd harfbuzz

sed -i "/harfbuzz_deps += \\[freetype_dep\\]/a \\
# --- Brotli static libs ---\\
brotli_libs = [\\
  files(join_paths(get_option('libdir'), 'libbrotlicommon.a')),\\
  files(join_paths(get_option('libdir'), 'libbrotlidec.a')),\\
  files(join_paths(get_option('libdir'), 'libbrotlienc.a'))\\
]\\
harfbuzz_lib = meson.get_target('harfbuzz')\\
harfbuzz_lib.link_with += brotli_libs\\
# --- End brotli ---" meson.build

# Meson cross file
MESON_CROSS="$PWD/meson_cross.ini"
cat > "$MESON_CROSS" <<EOF
[binaries]
c = '$CC'
cxx = '$CXX'
ar = '$AR'
pkgconfig = '$PREFIX_DEPS/bin/aarch64-w64-mingw32-pkg-config'

[host_machine]
system = 'windows'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'

[properties]
root_prefix = '$PREFIX_DEPS'
EOF

meson setup build --cross-file="$MESON_CROSS" \
  --prefix="$PREFIX_DEPS" \
  -Dfreetype=enabled -Dtests=disabled \
  | tee meson-harfbuzz-config.log

ninja -C build -j"$(nproc)" && ninja -C build install
cd ..

echo ">>> HarfBuzz build with brotli support complete"

####################################
# SDL2
####################################
echo "=== Building SDL2 ==="
git clone --depth=1 --branch SDL2 https://github.com/libsdl-org/SDL.git SDL2
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

####################################
# libusb via libusb-cmake
####################################
echo "=== Building libusb via libusb-cmake ==="
git clone --depth=1 https://github.com/libusb/libusb-cmake.git libusb-cmake
cd libusb-cmake
mkdir -p build && cd build
cmake \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_SYSTEM_PROCESSOR=ARM64 \
  -DCMAKE_C_COMPILER="${CC}" \
  -DCMAKE_CXX_COMPILER="${CXX}" \
  -DCMAKE_FIND_ROOT_PATH="${PREFIX_DEPS}" \
  -DCMAKE_INSTALL_PREFIX="${PREFIX_DEPS}" \
  -DBUILD_SHARED_LIBS=OFF \
  -DENABLE_STATIC=ON \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY ..
cmake --build . --parallel "$(nproc)" --target install
cd ../..

cat > "${PREFIX_DEPS}/lib/pkgconfig/libusb-1.0.pc" <<EOF
prefix=${PREFIX_DEPS}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libusb-1.0
Description: libusb library for USB device access
Version: 1.0
Libs: -L\${libdir} -lusb-1.0
Cflags: -I\${includedir}
EOF

####################################
# lcms2
####################################
echo "=== Building lcms2 ==="
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

####################################
# libtool + libltdl
####################################
echo "=== Building full libtool + libltdl ==="
LIBTOOL_VER=2.5.4
wget -q "https://ftp.gnu.org/gnu/libtool/libtool-${LIBTOOL_VER}.tar.gz"
tar xf "libtool-${LIBTOOL_VER}.tar.gz"
cd "libtool-${LIBTOOL_VER}"
./configure \
  --host="$TOOLCHAIN" \
  --prefix="${PREFIX_DEPS}" \
  --disable-shared --enable-static \
  CC="${CC}" AR="${AR}" RANLIB="${RANLIB}" \
  CFLAGS="-I${PREFIX_DEPS}/include ${CFLAGS}" \
  LDFLAGS="-L${PREFIX_DEPS}/lib ${LDFLAGS}"
make -j"$(nproc)" && make install
cd ..

####################################
# libgphoto2 (cross)
####################################
echo "=== Building libgphoto2 (cross) ==="
git clone --depth=1 https://github.com/gphoto/libgphoto2.git libgphoto2
cd libgphoto2
autoreconf --install --force --verbose
export PKG_CONFIG_PATH="${PREFIX_DEPS}/lib/pkgconfig:${PKG_CONFIG_PATH}"

./configure \
  --host="$TOOLCHAIN" \
  --prefix="${PREFIX_DEPS}" \
  --disable-shared --enable-static \
  --without-curl --without-exif --disable-nls \
  CC="${CC}" \
  CFLAGS="-I${PREFIX_DEPS}/include ${CFLAGS}" \
  CPPFLAGS="-I${PREFIX_DEPS}/include ${CPPFLAGS}" \
  LDFLAGS="-L${PREFIX_DEPS}/lib ${LDFLAGS}"
make -j"$(nproc)"
make install
cd ..

cat > "${PREFIX_DEPS}/lib/pkgconfig/libgphoto2.pc" <<EOF
prefix=${PREFIX_DEPS}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libgphoto2
Description: gPhoto2 digital camera library
Version: 2.5.32
Libs: -L\${libdir} -lgphoto2
Cflags: -I\${includedir}
EOF

cat > "${PREFIX_DEPS}/lib/pkgconfig/libgphoto2_port.pc" <<EOF
prefix=${PREFIX_DEPS}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libgphoto2_port
Description: gPhoto2 port support library
Version: 2.5.32
Libs: -L\${libdir} -lgphoto2_port
Cflags: -I\${includedir}
EOF

echo "=== build.sh complete! ==="