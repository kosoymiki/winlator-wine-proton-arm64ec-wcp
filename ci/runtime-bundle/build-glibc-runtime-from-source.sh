#!/usr/bin/env bash
set -euo pipefail

# Build a reusable glibc runtime tree for Winlator glibc-wrapped launchers.
# Output layout is a flat runtime dir suitable for lib/wine/wcp-glibc-runtime/.

usage() {
  cat <<'EOF'
Usage: build-glibc-runtime-from-source.sh --out-dir DIR [options]

Required:
  --out-dir DIR                 Runtime output dir (will be created/overwritten)

Source selection (one of):
  --src-tarball FILE            Existing glibc source tarball
  --src-url URL                 glibc source tarball URL (downloaded if missing)

Optional:
  --src-sha256 HEX              Verify source tarball sha256
  --version VER                 Version label (metadata only, default: unknown)
  --cache-dir DIR               Build/download cache dir (default: /tmp/wcp-glibc-build)
  --enable-kernel VER           glibc --enable-kernel (default: 4.14)
  --jobs N                      make -jN (default: nproc)
  --strip                       Strip installed libs if strip available
  --host-triplet TRIPLET        Explicit triplet (default: gcc -dumpmachine)
  --keep-workdir                Keep glibc source/build/dest workdir cache (disabled by default)
EOF
}

log() { printf '[glibc-build] %s\n' "$*"; }
fail() { printf '[glibc-build][error] %s\n' "$*" >&2; exit 1; }

print_log_tail() {
  local f="$1"
  [[ -f "${f}" ]] || return 0
  printf '[glibc-build][tail] %s\n' "${f}" >&2
  tail -n 80 "${f}" >&2 || true
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

find_one() {
  local base="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -e "${base}/${candidate}" ]]; then
      printf '%s' "${base}/${candidate}"
      return 0
    fi
  done
  return 1
}

copy_if_exists() {
  local src="$1" dst="$2"
  [[ -e "${src}" ]] || return 1
  mkdir -p "$(dirname -- "${dst}")"
  cp -a "${src}" "${dst}"
}

OUT_DIR=""
SRC_TARBALL=""
SRC_URL=""
SRC_SHA256=""
VERSION_LABEL="unknown"
CACHE_DIR="/tmp/wcp-glibc-build"
ENABLE_KERNEL="4.14"
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
DO_STRIP=0
HOST_TRIPLET=""
KEEP_WORKDIR=0

while (($#)); do
  case "$1" in
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --src-tarball) SRC_TARBALL="${2:-}"; shift 2 ;;
    --src-url) SRC_URL="${2:-}"; shift 2 ;;
    --src-sha256) SRC_SHA256="${2:-}"; shift 2 ;;
    --version) VERSION_LABEL="${2:-}"; shift 2 ;;
    --cache-dir) CACHE_DIR="${2:-}"; shift 2 ;;
    --enable-kernel) ENABLE_KERNEL="${2:-}"; shift 2 ;;
    --jobs) JOBS="${2:-}"; shift 2 ;;
    --strip) DO_STRIP=1; shift ;;
    --host-triplet) HOST_TRIPLET="${2:-}"; shift 2 ;;
    --keep-workdir) KEEP_WORKDIR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

[[ -n "${OUT_DIR}" ]] || { usage >&2; fail "--out-dir is required"; }
if [[ -z "${SRC_TARBALL}" && -z "${SRC_URL}" ]]; then
  usage >&2
  fail "Provide --src-tarball or --src-url"
fi

command -v tar >/dev/null 2>&1 || fail "tar is required"
command -v make >/dev/null 2>&1 || fail "make is required"
command -v gcc >/dev/null 2>&1 || fail "gcc is required"
command -v g++ >/dev/null 2>&1 || fail "g++ is required"
command -v gawk >/dev/null 2>&1 || fail "gawk is required for glibc build"
command -v bison >/dev/null 2>&1 || fail "bison is required for glibc build"
command -v msgfmt >/dev/null 2>&1 || log "msgfmt not found (gettext optional; glibc may still build)"

if [[ -z "${HOST_TRIPLET}" ]]; then
  HOST_TRIPLET="$(gcc -dumpmachine)"
fi

mkdir -p "${CACHE_DIR}"

if [[ -z "${SRC_TARBALL}" ]]; then
  local_name="${SRC_URL##*/}"
  SRC_TARBALL="${CACHE_DIR}/${local_name}"
  if [[ ! -f "${SRC_TARBALL}" ]]; then
    log "Downloading glibc source tarball: ${SRC_URL}"
    curl -fsSL "${SRC_URL}" -o "${SRC_TARBALL}.tmp"
    mv -f "${SRC_TARBALL}.tmp" "${SRC_TARBALL}"
  else
    log "Using cached glibc source tarball: ${SRC_TARBALL}"
  fi
fi

[[ -f "${SRC_TARBALL}" ]] || fail "Source tarball not found: ${SRC_TARBALL}"
if [[ -n "${SRC_SHA256}" ]]; then
  actual_sha="$(sha256_file "${SRC_TARBALL}")"
  [[ "${actual_sha}" == "${SRC_SHA256}" ]] || fail "glibc source sha256 mismatch: expected ${SRC_SHA256}, got ${actual_sha}"
fi

WORK_DIR="${CACHE_DIR}/build-${VERSION_LABEL}-${HOST_TRIPLET}"
SRC_DIR="${WORK_DIR}/src"
BLD_DIR="${WORK_DIR}/build"
DST_DIR="${WORK_DIR}/dest"
REPORT_DIR="${WORK_DIR}/reports"
STAMP_FILE="${WORK_DIR}/.stamp-${VERSION_LABEL}"

if [[ ! -f "${STAMP_FILE}" ]]; then
  log "Preparing build dirs: ${WORK_DIR}"
  rm -rf "${WORK_DIR}"
  mkdir -p "${SRC_DIR}" "${BLD_DIR}" "${DST_DIR}" "${REPORT_DIR}"
  tar -xf "${SRC_TARBALL}" -C "${SRC_DIR}" --strip-components=1

  {
    echo "version=${VERSION_LABEL}"
    echo "host_triplet=${HOST_TRIPLET}"
    echo "enable_kernel=${ENABLE_KERNEL}"
    echo "jobs=${JOBS}"
    echo "src_tarball=${SRC_TARBALL}"
    echo "src_sha256=${SRC_SHA256}"
    echo "caller_CC=${CC:-}"
    echo "caller_CXX=${CXX:-}"
    echo "caller_LD=${LD:-}"
    echo "caller_AR=${AR:-}"
    echo "caller_RANLIB=${RANLIB:-}"
    echo "caller_CFLAGS=${CFLAGS:-}"
    echo "caller_LDFLAGS=${LDFLAGS:-}"
  } > "${REPORT_DIR}/toolchain-env.txt"

  if ! command -v makeinfo >/dev/null 2>&1; then
    log "makeinfo not found, glibc docs generation will be disabled (MAKEINFO=true)"
  fi

  export GLIBC_HOST_CC="${GLIBC_HOST_CC:-gcc}"
  export GLIBC_HOST_CXX="${GLIBC_HOST_CXX:-g++}"
  export GLIBC_HOST_LD="${GLIBC_HOST_LD:-ld}"
  export GLIBC_HOST_AR="${GLIBC_HOST_AR:-ar}"
  export GLIBC_HOST_RANLIB="${GLIBC_HOST_RANLIB:-ranlib}"
  export GLIBC_HOST_NM="${GLIBC_HOST_NM:-nm}"
  export GLIBC_HOST_STRIP="${GLIBC_HOST_STRIP:-strip}"

  log "Configuring glibc ${VERSION_LABEL} (${HOST_TRIPLET})"
  if ! (
    cd "${BLD_DIR}"
    env -u CC -u CXX -u LD -u AR -u RANLIB -u NM -u STRIP \
        -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS -u PKG_CONFIG_PATH -u PKG_CONFIG_LIBDIR \
        CC="${GLIBC_HOST_CC}" \
        CXX="${GLIBC_HOST_CXX}" \
        LD="${GLIBC_HOST_LD}" \
        AR="${GLIBC_HOST_AR}" \
        RANLIB="${GLIBC_HOST_RANLIB}" \
        NM="${GLIBC_HOST_NM}" \
        STRIP="${GLIBC_HOST_STRIP}" \
        MAKEINFO="${MAKEINFO:-true}" \
        "${SRC_DIR}/configure" \
      --prefix=/usr \
      --disable-werror \
      --enable-kernel="${ENABLE_KERNEL}" \
      --host="${HOST_TRIPLET}" \
      --build="${HOST_TRIPLET}"
  ) > "${REPORT_DIR}/configure.log" 2>&1; then
    print_log_tail "${REPORT_DIR}/configure.log"
    fail "glibc configure failed (see ${REPORT_DIR}/configure.log)"
  fi

  log "Building glibc (make -j${JOBS})"
  if ! env -u CC -u CXX -u LD -u AR -u RANLIB -u NM -u STRIP \
      -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS \
      CC="${GLIBC_HOST_CC}" \
      CXX="${GLIBC_HOST_CXX}" \
      LD="${GLIBC_HOST_LD}" \
      AR="${GLIBC_HOST_AR}" \
      RANLIB="${GLIBC_HOST_RANLIB}" \
      NM="${GLIBC_HOST_NM}" \
      STRIP="${GLIBC_HOST_STRIP}" \
      MAKEINFO="${MAKEINFO:-true}" \
      make -C "${BLD_DIR}" -j"${JOBS}" > "${REPORT_DIR}/build.log" 2>&1; then
    print_log_tail "${REPORT_DIR}/build.log"
    fail "glibc make failed (see ${REPORT_DIR}/build.log)"
  fi

  log "Installing glibc into staging destdir"
  if ! env -u CC -u CXX -u LD -u AR -u RANLIB -u NM -u STRIP \
      -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS \
      CC="${GLIBC_HOST_CC}" \
      CXX="${GLIBC_HOST_CXX}" \
      LD="${GLIBC_HOST_LD}" \
      AR="${GLIBC_HOST_AR}" \
      RANLIB="${GLIBC_HOST_RANLIB}" \
      NM="${GLIBC_HOST_NM}" \
      STRIP="${GLIBC_HOST_STRIP}" \
      MAKEINFO="${MAKEINFO:-true}" \
      make -C "${BLD_DIR}" install DESTDIR="${DST_DIR}" > "${REPORT_DIR}/install.log" 2>&1; then
    print_log_tail "${REPORT_DIR}/install.log"
    fail "glibc make install failed (see ${REPORT_DIR}/install.log)"
  fi

  date -u +"%Y-%m-%dT%H:%M:%SZ" > "${STAMP_FILE}"
else
  log "Using cached built glibc runtime staging: ${WORK_DIR}"
  mkdir -p "${REPORT_DIR}"
fi

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

LIB_ROOT="$(find_one "${DST_DIR}" usr/lib lib lib64 usr/lib64 || true)"
[[ -n "${LIB_ROOT}" ]] || fail "Unable to locate installed glibc lib root in ${DST_DIR}"

loader_src="$(find_one "${DST_DIR}" usr/lib/ld-linux-aarch64.so.1 lib/ld-linux-aarch64.so.1 usr/lib64/ld-linux-aarch64.so.1 lib64/ld-linux-aarch64.so.1 || true)"
[[ -n "${loader_src}" ]] || fail "Installed glibc loader not found in ${DST_DIR}"

copy_if_exists "${loader_src}" "${OUT_DIR}/$(basename -- "${loader_src}")" || fail "Failed to copy loader"
if [[ "$(basename -- "${loader_src}")" != "ld-linux-aarch64.so.1" ]]; then
  ln -sfn "$(basename -- "${loader_src}")" "${OUT_DIR}/ld-linux-aarch64.so.1"
fi

# Core glibc libs and common runtime group produced by glibc itself.
for soname in \
  libc.so.6 libdl.so.2 libm.so.6 libpthread.so.0 librt.so.1 \
  libresolv.so.2 libutil.so.1 libnss_files.so.2 libnss_dns.so.2; do
  src="$(find_one "${DST_DIR}" "usr/lib/${soname}" "lib/${soname}" "usr/lib64/${soname}" "lib64/${soname}" || true)"
  [[ -n "${src}" ]] || continue
  copy_if_exists "${src}" "${OUT_DIR}/${soname}" || true
done

# Copy symlink targets recursively for any symlink copied above.
while IFS= read -r entry; do
  [[ -L "${OUT_DIR}/${entry}" ]] || continue
  target="$(readlink "${OUT_DIR}/${entry}")"
  if [[ "${target}" != /* && -e "${LIB_ROOT}/${target}" && ! -e "${OUT_DIR}/${target}" ]]; then
    copy_if_exists "${LIB_ROOT}/${target}" "${OUT_DIR}/${target}" || true
  fi
done < <(find "${OUT_DIR}" -maxdepth 1 -mindepth 1 -printf '%f\n' | LC_ALL=C sort)

# Adjacent non-glibc libs remain sourced from host for now (locked/audited separately).
for soname in libgcc_s.so.1 libstdc++.so.6 libz.so.1 libnsl.so.1 libSDL2-2.0.so.0 libSDL2-2.0.so; do
  host_path=""
  for dir in /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu /lib /usr/lib; do
    if [[ -e "${dir}/${soname}" ]]; then
      host_path="$(readlink -f "${dir}/${soname}")"
      break
    fi
  done
  [[ -n "${host_path}" ]] || continue
  base="$(basename -- "${host_path}")"
  cp -an "${host_path}" "${OUT_DIR}/${base}" || true
  if [[ "${base}" != "${soname}" ]]; then
    ln -sfn "${base}" "${OUT_DIR}/${soname}"
  fi
done

if [[ "${DO_STRIP}" == "1" ]] && command -v strip >/dev/null 2>&1; then
  find "${OUT_DIR}" -maxdepth 1 -type f -name '*.so*' -exec strip --strip-unneeded {} + >/dev/null 2>&1 || true
fi

find "${OUT_DIR}" -maxdepth 1 -mindepth 1 -printf '%f\t%s\n' | LC_ALL=C sort > "${REPORT_DIR}/runtime-tree-manifest.tsv"
mkdir -p "${OUT_DIR}/.build-reports"
cp -a "${REPORT_DIR}/." "${OUT_DIR}/.build-reports/"

cat > "${OUT_DIR}/.runtime-bundle-meta" <<EOF_META
version=${VERSION_LABEL}
source_tarball=${SRC_TARBALL}
source_sha256=${SRC_SHA256}
host_triplet=${HOST_TRIPLET}
enable_kernel=${ENABLE_KERNEL}
built_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF_META

log "glibc runtime bundle prepared: ${OUT_DIR}"

if [[ "${KEEP_WORKDIR}" != "1" ]]; then
  if command -v du >/dev/null 2>&1; then
    log "glibc build staging size before prune: $(du -sh "${WORK_DIR}" 2>/dev/null | awk '{print $1}' || echo unknown)"
  fi
  log "Pruning glibc build staging workdir to reduce CI disk usage: ${WORK_DIR}"
  rm -rf "${SRC_DIR}" "${BLD_DIR}" "${DST_DIR}"
fi
