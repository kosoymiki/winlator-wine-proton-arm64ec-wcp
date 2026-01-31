#!/usr/bin/env bash
set -euxo pipefail

#####################################
# Check deps prefix
#####################################
if [ -z "${PREFIX_DEPS}" ]; then
  PREFIX_DEPS="${PWD}/deps/install"
fi

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
# Configure & compile Wine
#####################################

cd wine

mkdir -p wine-tools-build
cd wine-tools-build

../configure \
  --enable-tools \
  --disable-tests \
  --disable-win16 \
  --enable-archs=aarch64

make -j"$(nproc)"
cd ..

mkdir -p build
cd build

export BUILD=aarch64-linux-gnu
export HOST=aarch64-w64-mingw32
export CC=aarch64-w64-mingw32-clang
export CXX=aarch64-w64-mingw32-clang++
export AR=aarch64-w64-mingw32-ar
export LD=aarch64-w64-mingw32-lld
export WINDRES=aarch64-w64-mingw32-windres
export RANLIB=aarch64-w64-mingw32-ranlib

export PKG_CONFIG_PATH="$PREFIX_DEPS/lib/pkgconfig:$PKG_CONFIG_PATH"
export PKG_CONFIG_SYSROOT_DIR="$PREFIX_DEPS"
export CFLAGS="-I$PREFIX_DEPS/include $CFLAGS"
export LDFLAGS="-L$PREFIX_DEPS/lib $LDFLAGS"

../configure \
  --build="$BUILD" \
  --host="$HOST" \
  --with-mingw=clang \
  --with-wine-tools="../wine-tools-build" \
  --prefix=/usr \
  --enable-win64 \
  --enable-wow64 \
  --enable-archs=arm64ec,aarch64 \
  --disable-tests \
  --without-mono \
  --without-gecko \
  --with-freetype \
  --with-fontconfig \
  --with-alsa \
  --with-pulse \
  --with-sdl2 \
  --with-dbus \
  --with-vulkan \
  --with-lcms2 \
  --with-libtiff \
  --with-libusb

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
