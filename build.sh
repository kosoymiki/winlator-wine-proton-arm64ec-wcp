#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

: "${LLVM_MINGW_VER:=20251216}"
: "${WCP_NAME:=wine-11.1-arm64ec}"
: "${WCP_OUTPUT_DIR:=$ROOT/dist}"
: "${TOOLCHAIN_DIR:=$ROOT/.cache/llvm-mingw}"
: "${WINE_SRC_DIR:=$ROOT/wine-src}"
: "${WINE_GIT_URL:=https://github.com/AndreRH/wine.git}"
: "${WINE_GIT_REF:=arm64ec}"
: "${WINE_JOBS:=$(nproc)}"
: "${WINE_HOST_TRIPLE:=aarch64-w64-mingw32}"

mkdir -p "$WCP_OUTPUT_DIR" "$TOOLCHAIN_DIR"

# 1) Download llvm-mingw toolchain into cache directory.
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

  LLVM_EXTRACTED_DIR="${tmpdir}/llvm-mingw-${LLVM_MINGW_VER}-ucrt-ubuntu-22.04-x86_64"
  if [[ ! -d "$LLVM_EXTRACTED_DIR" ]]; then
    echo "ERROR: llvm-mingw extracted directory was not found: $LLVM_EXTRACTED_DIR" >&2
    exit 1
  fi

  # Release layout differs between versions:
  # - some archives place toolchain files under ./shared
  # - others place them directly at the root
  LLVM_CONTENT_DIR="$LLVM_EXTRACTED_DIR"
  if [[ -d "${LLVM_EXTRACTED_DIR}/shared" ]]; then
    LLVM_CONTENT_DIR="${LLVM_EXTRACTED_DIR}/shared"
  fi

  if [[ ! -x "${LLVM_CONTENT_DIR}/bin/clang" ]]; then
    echo "ERROR: clang not found after extraction at ${LLVM_CONTENT_DIR}/bin/clang" >&2
    exit 1
  fi

  cp -a "${LLVM_CONTENT_DIR}/." "$LLVM_DST/"
fi

export PATH="${LLVM_BIN}:$PATH"

# 2) Prepare Wine sources (local first, clone only when missing).
if [[ ! -d "$WINE_SRC_DIR/.git" ]]; then
  echo "Wine source repo not found at $WINE_SRC_DIR, cloning $WINE_GIT_URL"
  git clone --depth=1 --branch "$WINE_GIT_REF" "$WINE_GIT_URL" "$WINE_SRC_DIR"
else
  echo "Using existing wine sources at $WINE_SRC_DIR"
fi

pushd "$WINE_SRC_DIR" >/dev/null
if git show-ref --verify --quiet "refs/remotes/origin/${WINE_GIT_REF}"; then
  git checkout -B "$WINE_GIT_REF" "origin/${WINE_GIT_REF}"
else
  git checkout "$WINE_GIT_REF" 2>/dev/null || true
fi
popd >/dev/null

# 3) Cross-compilation environment.
export CC="clang --target=arm64ec-w64-windows-gnu"
export CXX="clang++ --target=arm64ec-w64-windows-gnu"
export AR="llvm-ar"
export RANLIB="llvm-ranlib"
export STRIP="llvm-strip"
export CFLAGS="-O2 -pipe"
export CXXFLAGS="-O2 -pipe"
export LDFLAGS=""

BUILD_DIR="$ROOT/build-arm64ec"
STAGING="$ROOT/stage"
rm -rf "$BUILD_DIR" "$STAGING"
mkdir -p "$BUILD_DIR" "$STAGING"

# 4) Configure, build and install Wine directly (no wine-tkg).
pushd "$BUILD_DIR" >/dev/null
"$WINE_SRC_DIR/configure" \
  --host="$WINE_HOST_TRIPLE" \
  --prefix=/usr

make -j"$WINE_JOBS"
make install DESTDIR="$STAGING"
popd >/dev/null

# 5) Package WCP.
pushd "$STAGING" >/dev/null
rm -rf wcp
mkdir -p wcp/{bin,lib,share,info}

if [[ -d usr/local ]]; then
  cp -a usr/local/* wcp/
else
  cp -a usr/* wcp/
fi

ln -sf wine64 wcp/bin/wine || true

cat > wcp/info/info.json <<EOF_JSON
{
  "name": "Wine ARM64EC",
  "os": "windows",
  "arch": "arm64",
  "version": "11.1-arm64ec",
  "features": ["direct-build"],
  "built": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF_JSON

cat > wcp/bin/env.sh <<'EOF_ENV'
#!/bin/sh
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
exec "$(dirname "$0")/wine64" "$@"
EOF_ENV
chmod +x wcp/bin/env.sh

WCP_PATH="${WCP_OUTPUT_DIR}/${WCP_NAME}.wcp"
tar -cJf "$WCP_PATH" -C wcp .
echo "Created $WCP_PATH"
popd >/dev/null
