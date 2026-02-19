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
  LLVM_SHARED_DIR="${tmpdir}/llvm-mingw-${LLVM_MINGW_VER}-ucrt-ubuntu-22.04-x86_64/shared"
  if [[ ! -d "$LLVM_SHARED_DIR" ]]; then
    echo "ERROR: llvm-mingw shared directory was not found: $LLVM_SHARED_DIR" >&2
    exit 1
  fi

  mv "${LLVM_SHARED_DIR}/"* "$LLVM_DST/"
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
TOOLS_BUILD_DIR="$ROOT/build-tools"
STAGING="$ROOT/stage"
rm -rf "$BUILD_DIR" "$TOOLS_BUILD_DIR" "$STAGING"
mkdir -p "$BUILD_DIR" "$TOOLS_BUILD_DIR" "$STAGING"

# 4) Build native Wine tools first (required for cross-compilation).
pushd "$TOOLS_BUILD_DIR" >/dev/null
"$WINE_SRC_DIR/configure"
make -j"$WINE_JOBS" tools
popd >/dev/null

# 5) Configure, build and install cross Wine binaries.
pushd "$BUILD_DIR" >/dev/null
"$WINE_SRC_DIR/configure" \
  --host=arm64ec-w64-windows-gnu \
  --with-wine-tools="$TOOLS_BUILD_DIR" \
  --prefix=/usr

make -j"$WINE_JOBS"
make install DESTDIR="$STAGING"
popd >/dev/null

# 6) Package WCP.
pushd "$STAGING" >/dev/null
rm -rf wcp
mkdir -p wcp/{bin,lib,share,info}

if [[ -d usr/local ]]; then
  cp -a usr/local/* wcp/
else
  cp -a usr/* wcp/
fi

ln -sf wine64 wcp/bin/wine || true

mkdir -p wcp/share/winetools

# Build winetools layer: helper launcher + manifest + linking snapshot.
cat > wcp/bin/winetools <<'EOF_WINETOOLS'
#!/usr/bin/env bash
set -Eeuo pipefail
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SELF_DIR}/../share/winetools/manifest.txt"

usage() {
  cat <<'EOF_USAGE'
Usage: winetools <command> [args]
Commands:
  list                List known wine tools from manifest
  run <tool> [args]   Run selected tool from current bin directory
  info                Show winetools metadata files
EOF_USAGE
}

cmd="${1:-}"
case "$cmd" in
  list)
    [[ -f "$MANIFEST" ]] && cat "$MANIFEST" || echo "manifest not found: $MANIFEST"
    ;;
  run)
    tool="${2:-}"
    [[ -n "$tool" ]] || { echo "missing tool name" >&2; usage; exit 2; }
    shift 2
    exec "${SELF_DIR}/${tool}" "$@"
    ;;
  info)
    echo "manifest: ${SELF_DIR}/../share/winetools/manifest.txt"
    echo "linking : ${SELF_DIR}/../share/winetools/linking-report.txt"
    ;;
  *)
    usage
    ;;
esac
EOF_WINETOOLS
chmod +x wcp/bin/winetools

TOOLS_MANIFEST="wcp/share/winetools/manifest.txt"
: > "$TOOLS_MANIFEST"
for tool in wine wine64 wineserver winecfg wineboot regedit winedbg msiexec notepad explorer; do
  if [[ -x "wcp/bin/$tool" ]]; then
    printf '%s\n' "$tool" >> "$TOOLS_MANIFEST"
  fi
done

LINK_REPORT="wcp/share/winetools/linking-report.txt"
{
  echo "# winetools linking report"
  echo "generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  for bin in wcp/bin/wine wcp/bin/wine64 wcp/bin/wineserver; do
    if [[ -e "$bin" ]]; then
      echo "## $bin"
      file "$bin" || true
      if command -v readelf >/dev/null 2>&1; then
        readelf -d "$bin" 2>/dev/null | sed -n '1,40p' || true
      fi
      echo
    fi
  done
} > "$LINK_REPORT"

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
