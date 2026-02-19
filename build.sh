#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

: "${LLVM_MINGW_VER:=20251216}"
: "${WCP_NAME:=wine-11.1-staging-s8g1}"
: "${WCP_OUTPUT_DIR:=$ROOT/dist}"
: "${TOOLCHAIN_DIR:=$ROOT/.cache/llvm-mingw}"

mkdir -p "$WCP_OUTPUT_DIR" "$TOOLCHAIN_DIR"

rm -rf repo-wine-tkg-git wine-tkg-src wcp wine-src

# 1) Clone wine-tkg sources.
git clone --depth=1 https://github.com/Frogging-Family/wine-tkg-git.git repo-wine-tkg-git
mkdir -p wine-tkg-src
mv repo-wine-tkg-git/wine-tkg-git wine-tkg-src/
rm -rf repo-wine-tkg-git

# 2) Download llvm-mingw toolchain into cache directory.
LLVM_TAR="llvm-mingw-${LLVM_MINGW_VER}-ucrt-ubuntu-22.04-x86_64.tar.xz"
LLVM_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW_VER}/${LLVM_TAR}"
LLVM_DST="${TOOLCHAIN_DIR}/${LLVM_MINGW_VER}"
LLVM_BIN="${LLVM_DST}/bin"

if [[ ! -x "${LLVM_BIN}/clang" ]]; then
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  wget --https-only --tries=3 --timeout=30 -O "${tmpdir}/${LLVM_TAR}" "${LLVM_URL}"
  tar -xf "${tmpdir}/${LLVM_TAR}" -C "$tmpdir"

  rm -rf "$LLVM_DST"
  mkdir -p "$LLVM_DST"

  LLVM_EXTRACT_ROOT="${tmpdir}/llvm-mingw-${LLVM_MINGW_VER}-ucrt-ubuntu-22.04-x86_64"
  LLVM_SRC_DIR=""

  if [[ -x "${LLVM_EXTRACT_ROOT}/bin/clang" ]]; then
    LLVM_SRC_DIR="${LLVM_EXTRACT_ROOT}"
  elif [[ -x "${LLVM_EXTRACT_ROOT}/shared/bin/clang" ]]; then
    LLVM_SRC_DIR="${LLVM_EXTRACT_ROOT}/shared"
  else
    LLVM_SRC_DIR="$(find "$tmpdir" -maxdepth 4 -type f -path '*/bin/clang' -print | head -n1 | sed 's#/bin/clang$##')"
  fi

  if [[ -z "$LLVM_SRC_DIR" || ! -x "$LLVM_SRC_DIR/bin/clang" ]]; then
    echo "ERROR: unable to locate llvm-mingw toolchain root after extraction" >&2
    find "$tmpdir" -maxdepth 3 -type d | sed 's/^/  - /' >&2
    exit 1
  fi

  cp -a "${LLVM_SRC_DIR}/." "$LLVM_DST/"
fi

export PATH="${LLVM_BIN}:$PATH"

# 3) Clone Wine sources and checkout arm64ec branch.
git clone --depth=1 https://github.com/AndreRH/wine.git wine-src
pushd wine-src >/dev/null
git fetch --depth=1 origin arm64ec
git checkout -B arm64ec origin/arm64ec
popd >/dev/null

# 4) Configure wine-tkg toggles.
CFG="wine-tkg-src/wine-tkg-git/customization.cfg"
if [[ ! -f "$CFG" ]]; then
  echo "ERROR: customization.cfg not found at $CFG" >&2
  exit 1
fi

set_cfg_bool() {
  local key="$1"
  local val="$2"
  if grep -qE "^${key}=" "$CFG"; then
    sed -i -E "s|^${key}=\"[^\"]*\"|${key}=\"${val}\"|" "$CFG"
  else
    echo "${key}=\"${val}\"" >> "$CFG"
  fi
}

set_cfg_bool "_use_staging" "true"
set_cfg_bool "_use_fsync" "true"
set_cfg_bool "_use_esync" "true"
set_cfg_bool "_use_vulkan" "true"

# 5) Cross-compilation environment.
export CC="clang --target=arm64ec-w64-windows-gnu"
export CXX="clang++ --target=arm64ec-w64-windows-gnu"
export AR="llvm-ar"
export RANLIB="llvm-ranlib"
export STRIP="llvm-strip"
export WINECPU="arm64"
export CFLAGS="-O2 -pipe"
export CXXFLAGS="-O2 -pipe"
export LDFLAGS=""

export _CUSTOM_GIT_URL="file://${ROOT}/wine-src"
export _LOCAL_PRESET="1"

# 6) Build and install.
pushd wine-tkg-src/wine-tkg-git >/dev/null
./non-makepkg-build.sh --cross

STAGING="$(pwd)/../wcp/install"
rm -rf "$STAGING"
mkdir -p "$STAGING"
make -C non-makepkg-builds install DESTDIR="$STAGING"
popd >/dev/null

# 7) Package WCP.
pushd "$STAGING" >/dev/null
rm -rf wcp
mkdir -p wcp/{bin,lib,share,info}

if [[ -d usr/local ]]; then
  cp -a usr/local/* wcp/
else
  cp -a usr/* wcp/
fi

ln -sf wine64 wcp/bin/wine || true

cat > wcp/info/info.json <<EOF
{
  "name": "Wine 11.1 staging (ARM64EC)",
  "os": "windows",
  "arch": "arm64",
  "version": "11.1-staging",
  "features": ["staging", "fsync", "esync", "vulkan"],
  "built": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat > wcp/bin/env.sh <<'EOF'
#!/bin/sh
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
exec "$(dirname "$0")/wine64" "$@"
EOF
chmod +x wcp/bin/env.sh

WCP_PATH="${WCP_OUTPUT_DIR}/${WCP_NAME}.wcp"
tar -cJf "$WCP_PATH" -C wcp .
echo "Created $WCP_PATH"
popd >/dev/null
