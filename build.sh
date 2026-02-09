#!/usr/bin/env bash
set -Eeuo pipefail

echo
echo "======================================================="
echo " Wine ARM64EC TKG + Staging WCP build"
echo "======================================================="

#########################################################################
# 0) Установка зависимостей
#########################################################################

echo "=== Installing dependencies ==="
pacman -Sy --noconfirm \
  git wget unzip tar base-devel pkgconf \
  freetype2 libpng libjpeg-turbo zlib \
  libx11 libxext libxrandr libxinerama libxi libxcursor \
  gstreamer gst-plugins-base \
  gnutls

#########################################################################
# 1) Скачиваем полный репо wine-tkg-git
#########################################################################

echo "=== Cloning full wine-tkg-git repository ==="
rm -rf repo-wine-tkg-git
git clone --depth=1 https://github.com/Frogging-Family/wine-tkg-git.git repo-wine-tkg-git

#########################################################################
# 2) Переносим только нужную папку
#########################################################################

echo "=== Preparing wine-tkg-src working folder ==="
rm -rf wine-tkg-src
mkdir -p wine-tkg-src

# Перемещаем только каталог, который содержит скрипты, патчи, профили
mv repo-wine-tkg-git/wine-tkg-git wine-tkg-src/

# Удаляем остальной мусор
rm -rf repo-wine-tkg-git

#########################################################################
# 3) Скачиваем LLVM‑MinGW cross‑toolchain
#########################################################################

LLVM_VER="${LLVM_MINGW_VER:-20251216}"
LLVM_ARCHIVE="llvm-mingw-${LLVM_VER}-ucrt-ubuntu-22.04-x86_64.tar.xz"
LLVM_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_VER}/${LLVM_ARCHIVE}"
LLVM_PREFIX="/opt/llvm-mingw"

echo "=== Downloading MinGW LLVM toolchain ==="
mkdir -p "${LLVM_PREFIX}"
wget -q "${LLVM_URL}" -O "/tmp/${LLVM_ARCHIVE}"
tar -xJf "/tmp/${LLVM_ARCHIVE}" -C "${LLVM_PREFIX}" --strip-components=1

export PATH="${LLVM_PREFIX}/bin:${PATH}"

#########################################################################
# 4) Клонируем исходники Wine
#########################################################################

echo "=== Cloning Wine staging + Wine ARM64EC sources ==="
git clone --depth=1 https://gitlab.winehq.org/wine/wine-staging.git
rm -rf wine-src
git clone --depth=1 https://github.com/AndreRH/wine.git wine-src

(
  cd wine-src
  git fetch --depth=1 origin arm64ec
  git checkout arm64ec
)

#########################################################################
# 5) Копируем Wine в TKG
#########################################################################

echo "=== Copying Wine source into TKG folder ==="
rm -rf wine-tkg-src/wine
cp -a wine-src wine-tkg-src/wine

#########################################################################
# 6) Включаем патчи в customization.cfg
#########################################################################

CFG="wine-tkg-src/wine-tkg-git/customization.cfg"
echo "=== Enabling patch flags in customization.cfg ==="

# Основные флаги
for flag in staging esync fsync; do
  sed -i "s/_use_${flag}=\"false\"/_use_${flag}=\"true\"/g" "$CFG" || true
done

# Proton‑like options
for flag in proton_battleye_support proton_eac_support proton_winevulkan \
            proton_mf_patches proton_rawinput protonify; do
  sed -i "s/_${flag}=\"false\"/_${flag}=\"true\"/g" "$CFG" || true
done

# Дополнительные фикс‑опции
for flag in mk11_fix re4_fix mwo_fix use_josh_flat_theme; do
  sed -i "s/_${flag}=\"false\"/_${flag}=\"true\"/g" "$CFG" || true
done

#########################################################################
# 7) Устанавливаем переменные кросс‑компиляции
#########################################################################

export CC="clang --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link -O2"
export CXX="clang++ --target=arm64ec-w64-windows-gnu -fuse-ld=lld-link -O2"
export LD="lld-link"
export AR="llvm-ar"
export RANLIB="llvm-ranlib"

#########################################################################
# 8) Запускаем сборку TKG
#########################################################################

cd wine-tkg-src

echo "=== Running TKG non‑makepkg build ==="
chmod +x wine-tkg-git/non-makepkg-build.sh
./wine-tkg-git/non-makepkg-build.sh --cross

#########################################################################
# 9) Установка сборки в staging
#########################################################################

STAGING="$(pwd)/../wcp/install"
echo "=== Installing build into staging area ==="
rm -rf "$STAGING"
mkdir -p "$STAGING"
make -C non-makepkg-builds install DESTDIR="$STAGING"

#########################################################################
# 10) Формируем структуру WCP
#########################################################################

echo "=== Creating WCP layout ==="
cd "$STAGING"

mkdir -p wcp/{bin,lib/wine,share}

cp -a usr/local/bin/* wcp/bin/ 2>/dev/null || cp -a usr/bin/* wcp/bin/
cd wcp/bin && ln -sf wine64 wine && cd ../..
cp -a usr/local/lib/wine/* wcp/lib/wine/ 2>/dev/null || cp -a usr/lib/wine/* wcp/lib/wine/
cp -a usr/local/share/* wcp/share/ 2>/dev/null || cp -a usr/share/* wcp/share/

find wcp/bin -type f -exec chmod +x {} +
find wcp/lib -name "*.so*" -exec chmod +x {} +

#########################################################################
# 11) Пишем metadata (info.json + env.sh)
#########################################################################

echo "=== Writing WCP metadata ==="
cat > wcp/info.json << 'EOF'
{
  "name": "Wine-11.1-Staging-S8G1",
  "version": "11.1",
  "arch": "arm64",
  "variant": "staging",
  "features": ["staging","fsync","esync","vulkan"]
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

#########################################################################
# 12) Пакуем в .wcp
#########################################################################

WCP="${GITHUB_WORKSPACE:-$(pwd)}/wine-11.1-staging-s8g1.wcp"
echo "=== Packaging .wcp: $WCP ==="
tar -cJf "$WCP" -C wcp .

echo
echo "=== Build complete! Wine TKG WCP is ready! ==="