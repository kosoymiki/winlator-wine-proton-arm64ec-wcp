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
  meson ninja-build \
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
# 4) libtiff
####################################
echo "=== Building libtiff ==="
build_autotools_dep \
  "https://download.osgeo.org/libtiff/tiff-4.5.0.tar.gz" \
  "tiff-4.5.0"

####################################
# BROTLI: Build from source for HarfBuzz
####################################
echo "=== Building brotli from source (static) ==="

git clone --depth=1 https://github.com/google/brotli.git brotli
cd brotli

# Create CMake toolchain for cross compile
cat > brotli-toolchain.cmake << EOF
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER   ${CC})
set(CMAKE_CXX_COMPILER ${CXX})
set(CMAKE_RC_COMPILER  ${WINDRES})

set(CMAKE_FIND_ROOT_PATH ${PREFIX_DEPS})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(BROTLI_DISABLE_TESTS ON)
set(BROTLI_DISABLE_TOOLS ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
EOF

# Build brotli with CMake
mkdir -p build-brotli && cd build-brotli
cmake -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=../brotli-toolchain.cmake \
  -DCMAKE_INSTALL_PREFIX=${PREFIX_DEPS} \
  -DBROTLI_BUILD_SHARED_LIBS=OFF \
  -DBROTLI_DISABLE_TESTS=ON \
  ..
ninja install
cd ../..

# Create pkgconfig for static brotli
mkdir -p "$PREFIX_DEPS/lib/pkgconfig"
cat > "$PREFIX_DEPS/lib/pkgconfig/brotli.pc" << EOF
prefix=${PREFIX_DEPS}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: brotli
Description: Brotli static libs (common + decode + encode)
Version: 1.0
Libs: -L\${libdir} -lbrotlicommon -lbrotlidec -lbrotlienc
Cflags: -I\${includedir}
EOF

echo ">>> brotli static build completed."

####################################
# 4) freetype2
####################################
build_autotools_dep \
  https://sourceforge.net/projects/freetype/files/freetype2/2.14.1/freetype-2.14.1.tar.xz/download \
  freetype-2.14.1

# Explicitly ensure pkgconfig file is in correct place
if [ -f "$PREFIX_DEPS/lib/pkgconfig/freetype2.pc" ]; then
  echo "freetype2 .pc found"
else
  echo "Error: freetype2 .pc not found"
  exit 1
fi

# Ensure pkg-config sees freetype2
export PKG_CONFIG_PATH="$PREFIX_DEPS/lib/pkgconfig${PKG_CONFIG_PATH+:}${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_SYSROOT_DIR="$PREFIX_DEPS"
export PKG_CONFIG_LIBDIR="$PREFIX_DEPS/lib/pkgconfig"

echo ">>> pkg-config freetype2 info:"
pkg-config --modversion freetype2
pkg-config --cflags freetype2
pkg-config --libs freetype2

####################################
# 7) libxml2 (с SAX1)
####################################
echo "=== Building libxml2 ==="

# Ensure CPPFLAGS and LDFLAGS exist
export CPPFLAGS="-I$PREFIX_DEPS/include${CPPFLAGS:+ $CPPFLAGS}"
export LDFLAGS="-L$PREFIX_DEPS/lib${LDFLAGS:+ $LDFLAGS}"

wget -q https://download.gnome.org/sources/libxml2/2.9/libxml2-2.9.14.tar.xz \
  -O libxml2-2.9.14.tar.xz

tar xf libxml2-2.9.14.tar.xz
cd libxml2-2.9.14

./configure \
  --host="$TOOLCHAIN" \
  --prefix="$PREFIX_DEPS" \
  --disable-shared --enable-static \
  --with-sax1 \
  CPPFLAGS="$CPPFLAGS" \
  LDFLAGS="$LDFLAGS"

make -j"$(nproc)" && make install
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
# HARFBUZZ
####################################
echo "=== Building HarfBuzz with brotli support ==="
git clone --depth=1 https://github.com/harfbuzz/harfbuzz.git harfbuzz
cd harfbuzz

# Patch meson.build for explicit brotli .a linking
sed -i "/harfbuzz_deps += \\[freetype_dep\\]/a \\
# --- Brotli static libs ---\\
brotli_libs = [\\
  files(join_paths(get_option('libdir'), 'libbrotlicommon.a')),\\
  files(join_paths(get_option('libdir'), 'libbrotlidec.a')),\\
  files(join_paths(get_option('libdir'), 'libbrotlienc.a'))\\
]\\
harfbuzz_lib = meson.get_target('harfbuzz')\\
harfbuzz_lib.link_with += brotli_libs\\
# --- End brotli ---" \
  meson.build

# Meson cross file
MESON_CROSS="$PWD/meson_cross.ini"
cat > "$MESON_CROSS" <<EOF
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

[properties]
root_prefix = '$PREFIX_DEPS'
pkg_config_path = '$PKG_CONFIG_PATH'
EOF

meson setup build --cross-file="$MESON_CROSS" --prefix="$PREFIX_DEPS" \
  -Dfreetype=enabled -Dtests=disabled \
  | tee meson-harfbuzz-config.log

ninja -C build -j"$(nproc)" | tee ninja-harfbuzz-build.log
ninja -C build install
cd ..
echo ">>> HarfBuzz build with brotli support complete"

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


####################################
# libusb (CMake cross compile via libusb‑cmake)
####################################
echo "=== Building libusb via libusb-cmake ==="

git clone --depth=1 https://github.com/libusb/libusb-cmake.git libusb-cmake
cd libusb-cmake

# Create build dir
mkdir -p build && cd build

# Run CMake with cross settings
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
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  ..

# Build and install
cmake --build . --parallel "$(nproc)" --target install

cd ../..
echo "=== libusb CMake build complete ==="

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

####################################
# Install pkg-config and CMake module for libusb
####################################
echo "=== Installing libusb pkg-config and CMake module ==="

# Generate pkg-config if not already
mkdir -p "${PREFIX_DEPS}/lib/pkgconfig"
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
echo "Installed ${PREFIX_DEPS}/lib/pkgconfig/libusb-1.0.pc"

# Install FindLibUSB.cmake
mkdir -p "${PREFIX_DEPS}/cmake/modules"
cat > "${PREFIX_DEPS}/cmake/modules/FindLibUSB.cmake" << 'EOF'
# FindLibUSB.cmake
include(FindPackageHandleStandardArgs)

find_package(PkgConfig QUIET)

if(PKG_CONFIG_FOUND)
    pkg_check_modules(PC_LibUSB libusb-1.0)
endif()

find_path(LibUSB_INCLUDE_DIR
    NAMES libusb.h
    HINTS ${PC_LibUSB_INCLUDE_DIRS}
)

find_library(LibUSB_LIBRARY
    NAMES usb-1.0 libusb-1.0
    HINTS ${PC_LibUSB_LIBRARY_DIRS}
)

set(LibUSB_LIBRARIES ${LibUSB_LIBRARY})
set(LibUSB_INCLUDE_DIRS ${LibUSB_INCLUDE_DIR})

if(PC_LibUSB_FOUND)
    set(LibUSB_VERSION ${PC_LibUSB_VERSION})
endif()

find_package_handle_standard_args(LibUSB DEFAULT_MSG
    LibUSB_LIBRARY LibUSB_INCLUDE_DIRS
)

if(LibUSB_FOUND AND NOT TARGET LibUSB::LibUSB)
    add_library(LibUSB::LibUSB UNKNOWN IMPORTED)
    set_target_properties(LibUSB::LibUSB PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${LibUSB_INCLUDE_DIRS}"
        IMPORTED_LOCATION "${LibUSB_LIBRARY}"
    )
endif()
EOF
echo "Installed FindLibUSB.cmake to ${PREFIX_DEPS}/cmake/modules"
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

####################################
# Build full libtool + libltdl (cross compile)
####################################
echo "=== Building full libtool + libltdl (cross compile) ==="

LIBTOOL_VER=2.5.4

# Download official GNU libtool release
wget -q "https://ftp.gnu.org/gnu/libtool/libtool-${LIBTOOL_VER}.tar.gz"
tar xf "libtool-${LIBTOOL_VER}.tar.gz"
cd "libtool-${LIBTOOL_VER}"

# Configure for cross compile
./configure \
  --host=aarch64-w64-mingw32 \
  --prefix="${PREFIX_DEPS}" \
  --enable-static \
  --disable-shared \
  --disable-dependency-tracking \
  CC="${CC}" \
  AR="${AR}" \
  RANLIB="${RANLIB}" \
  CFLAGS="-I${PREFIX_DEPS}/include ${CFLAGS}" \
  LDFLAGS="-L${PREFIX_DEPS}/lib ${LDFLAGS}"

# Build and install
make -j"$(nproc)"
make install

cd ..
echo "=== full libtool + libltdl installed ==="

####################################
# Build libgphoto2 (cross compile)
####################################
echo "=== Building libgphoto2 (cross compile) ==="

# Clone libgphoto2
git clone --depth=1 https://github.com/gphoto/libgphoto2.git libgphoto2
cd libgphoto2

# Regenerate autotools scripts (needed in git)
autoreconf --install --force --verbose

# Ensure pkg-config can find previously built libltdl
export PKG_CONFIG_PATH="${PREFIX_DEPS}/lib/pkgconfig:${PKG_CONFIG_PATH}"

# Explicitly give libltdl include & lib paths
export LTDLINCL="-I${PREFIX_DEPS}/include"
export LIBLTDL="-L${PREFIX_DEPS}/lib -lltdl"

# Configure with correct cross settings
./configure \
  --host=aarch64-w64-mingw32 \
  --prefix="${PREFIX_DEPS}" \
  --disable-shared \
  --enable-static \
  --without-curl \
  --without-exif \
  --disable-nls \
  CC="${CC}" \
  CFLAGS="-I${PREFIX_DEPS}/include ${CFLAGS}" \
  CPPFLAGS="-I${PREFIX_DEPS}/include ${CPPFLAGS}" \
  LDFLAGS="-L${PREFIX_DEPS}/lib ${LDFLAGS}" \
  LTDLINCL="${LTDLINCL}" \
  LIBLTDL="${LIBLTDL}"

# Build & install
make -j"$(nproc)"
make install

cd ..

####################################
# Install pkg‑config files for libgphoto2
####################################
echo "=== Installing libgphoto2 pkg-config files ==="
mkdir -p "${PREFIX_DEPS}/lib/pkgconfig"

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

echo "=== libgphoto2 pkg-config installed ==="

####################################
# Install FindGphoto2.cmake module
####################################
echo "=== Installing FindGphoto2.cmake module ==="
mkdir -p "${PREFIX_DEPS}/cmake/modules"
cat > "${PREFIX_DEPS}/cmake/modules/FindGphoto2.cmake" << 'EOF'
include(FindPackageHandleStandardArgs)
find_package(PkgConfig QUIET)

# Try pkg-config first
if(PKG_CONFIG_FOUND)
    pkg_check_modules(PC_GPHOTO2 libgphoto2)
endif()

# Look for include dir
find_path(GPHOTO2_INCLUDE_DIR
    NAMES gphoto2/gphoto2.h
    HINTS ${PC_GPHOTO2_INCLUDE_DIRS}
)

# Look for libgphoto2
find_library(GPHOTO2_LIBRARY
    NAMES gphoto2 libgphoto2
    HINTS ${PC_GPHOTO2_LIBRARY_DIRS}
)

# Set variables
set(GPHOTO2_LIBRARIES ${GPHOTO2_LIBRARY})
if(PC_GPHOTO2_FOUND)
    set(GPHOTO2_VERSION ${PC_GPHOTO2_VERSION})
endif()

# Report results
find_package_handle_standard_args(Gphoto2 DEFAULT_MSG
    GPHOTO2_LIBRARY GPHOTO2_INCLUDE_DIR
)

# Provide imported target for CMake
if(Gphoto2_FOUND AND NOT TARGET Gphoto2::Gphoto2)
    add_library(Gphoto2::Gphoto2 UNKNOWN IMPORTED)
    set_target_properties(Gphoto2::Gphoto2 PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${GPHOTO2_INCLUDE_DIR}"
        IMPORTED_LOCATION "${GPHOTO2_LIBRARY}"
    )
endif()
EOF

echo "=== FindGphoto2.cmake module installed ==="