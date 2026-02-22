#!/usr/bin/env bash
set -euo pipefail

WCP_COMMON_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Re-export llvm-mingw helpers (including ensure_llvm_mingw) through this common entrypoint.
# Keep a stable alias so callers can source only wcp_common.sh.
source "${WCP_COMMON_DIR}/llvm-mingw.sh"
if declare -F ensure_llvm_mingw >/dev/null 2>&1; then
  eval "$(declare -f ensure_llvm_mingw | sed '1s/ensure_llvm_mingw/llvm_mingw_ensure_llvm_mingw/')"
  ensure_llvm_mingw() {
    llvm_mingw_ensure_llvm_mingw "$@"
  }
fi

source "${WCP_COMMON_DIR}/winlator-runtime.sh"

wcp_log() {
  if declare -F log >/dev/null 2>&1; then
    log "$@"
  else
    printf '[wcp] %s\n' "$*"
  fi
}

wcp_fail() {
  if declare -F fail >/dev/null 2>&1; then
    fail "$@"
  else
    printf '[wcp][error] %s\n' "$*" >&2
    exit 1
  fi
}

wcp_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || wcp_fail "Required command not found: $1"
}

wcp_require_bool() {
  local flag_name="$1" flag_value="$2"
  case "${flag_value}" in
    0|1) ;;
    *) wcp_fail "${flag_name} must be 0 or 1 (got: ${flag_value})" ;;
  esac
}

wcp_check_host_arch() {
  local arch
  arch="$(uname -m)"
  if [[ "${arch}" != "aarch64" && "${arch}" != "arm64" ]]; then
    wcp_fail "ARM64 host is required (aarch64/arm64). Current arch: ${arch}"
  fi
}

build_wine_tools_host() {
  local wine_src_dir="$1" build_dir="$2"
  local -a configure_args

  [[ -x "${wine_src_dir}/configure" ]] || wcp_fail "Missing configure script: ${wine_src_dir}/configure"
  mkdir -p "${build_dir}"

  pushd "${build_dir}" >/dev/null
  if [[ ! -f Makefile ]]; then
    configure_args=(
      "${wine_src_dir}/configure"
      --prefix=/usr
      --disable-tests
      --with-mingw=clang
      --enable-archs=arm64ec,aarch64,i386
    )
    "${configure_args[@]}"
  fi

  if ! make -j"$(nproc)" tools; then
    wcp_log "make tools target is unavailable; continuing with full build path"
  fi
  popd >/dev/null
}

build_wine_multiarc_arm64ec() {
  local wine_src_dir="$1" build_dir="$2" stage_dir="$3"
  local -a configure_args

  [[ -x "${wine_src_dir}/configure" ]] || wcp_fail "Missing configure script: ${wine_src_dir}/configure"

  mkdir -p "${build_dir}" "${stage_dir}"
  pushd "${build_dir}" >/dev/null

  configure_args=(
    "${wine_src_dir}/configure"
    --prefix=/usr
    --disable-tests
    --with-mingw=clang
    --enable-archs=arm64ec,aarch64,i386
  )

  # Space-delimited optional extras from caller.
  if [[ -n "${WINE_CONFIGURE_EXTRA_ARGS:-}" ]]; then
    # shellcheck disable=SC2206
    local extra_args=( ${WINE_CONFIGURE_EXTRA_ARGS} )
    configure_args+=("${extra_args[@]}")
  fi

  "${configure_args[@]}"

  if [[ -f config.log ]] && ! grep -Eq 'arm64ec' config.log; then
    wcp_fail "configure did not include ARM64EC target support"
  fi

  make -j"$(nproc)"
  make install DESTDIR="${stage_dir}"
  popd >/dev/null
}

generate_winetools_layer() {
  local wcp_root="$1"

  mkdir -p "${wcp_root}/winetools" "${wcp_root}/share/winetools"

  cat > "${wcp_root}/winetools/manifest.txt" <<'MANIFEST'
bin/wine
bin/wineserver
bin/winecfg
bin/regedit
bin/explorer
bin/msiexec
bin/notepad
MANIFEST

  cat > "${wcp_root}/winetools/winetools.sh" <<'WINETOOLS'
#!/usr/bin/env sh
set -eu

cmd="${1:-info}"
case "$cmd" in
  list)
    sed -n 's/^/ - /p' "$(dirname "$0")/manifest.txt"
    ;;
  run)
    tool="${2:-}"
    [ -n "$tool" ] || { echo "usage: winetools.sh run <tool> [args...]"; exit 2; }
    shift 2
    exec "/usr/bin/${tool}" "$@"
    ;;
  info|*)
    echo "Winlator WCP winetools layer"
    echo "Available tools:"
    sed -n 's|^bin/||p' "$(dirname "$0")/manifest.txt"
    ;;
esac
WINETOOLS
  chmod +x "${wcp_root}/winetools/winetools.sh"

  {
    echo "== ELF (Unix launchers) =="
    for f in \
      "${wcp_root}/bin/wine" \
      "${wcp_root}/bin/wineserver" \
      "${wcp_root}/bin/wine.glibc-real" \
      "${wcp_root}/bin/wineserver.glibc-real"; do
      [[ -e "${f}" ]] || continue
      echo "--- ${f}"
      file "${f}" || true
      readelf -d "${f}" 2>/dev/null | sed -n '1,120p' || true
    done
  } > "${wcp_root}/share/winetools/linking-report.txt"
}

compose_wcp_tree_from_stage() {
  local stage_dir="$1" wcp_root="$2"
  local prefix_pack_path profile_name profile_type utc_now

  : "${ROOT_DIR:=$(cd -- "${WCP_COMMON_DIR}/../.." && pwd)}"
  : "${WCP_TARGET_RUNTIME:=winlator-bionic}"
  : "${WCP_VERSION_NAME:=arm64ec}"
  : "${WCP_VERSION_CODE:=0}"
  : "${WCP_DESCRIPTION:=ARM64EC WCP package}"
  : "${WCP_NAME:=arm64ec-wcp}"
  : "${WCP_PROFILE_NAME:=${WCP_NAME}}"
  : "${WCP_PROFILE_TYPE:=Wine}"

  prefix_pack_path="${PREFIX_PACK_PATH:-${ROOT_DIR}/prefixPack.txz}"
  profile_name="${WCP_PROFILE_NAME}"
  profile_type="${WCP_PROFILE_TYPE}"

  [[ -d "${stage_dir}/usr" ]] || wcp_fail "Stage is missing usr/ payload: ${stage_dir}/usr"
  [[ -f "${prefix_pack_path}" ]] || wcp_fail "prefixPack.txz is required but missing: ${prefix_pack_path}"

  rm -rf "${wcp_root}"
  mkdir -p "${wcp_root}"
  rsync -a "${stage_dir}/usr/" "${wcp_root}/"

  mkdir -p "${wcp_root}/share"
  cp -f "${prefix_pack_path}" "${wcp_root}/prefixPack.txz"

  winlator_wrap_glibc_launchers
  generate_winetools_layer "${wcp_root}"

  utc_now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  cat > "${wcp_root}/profile.json" <<EOF_PROFILE
{
  "type": "${profile_type}",
  "name": "${profile_name}",
  "versionName": "${WCP_VERSION_NAME}",
  "versionCode": ${WCP_VERSION_CODE},
  "description": "${WCP_DESCRIPTION}",
  "files": [],
  "wine": {
    "binPath": "bin",
    "libPath": "lib",
    "prefixPack": "prefixPack.txz"
  },
  "runtime": {
    "target": "${WCP_TARGET_RUNTIME}"
  },
  "built": "${utc_now}"
}
EOF_PROFILE
}

validate_wcp_tree_arm64ec() {
  local wcp_root="$1"
  local -a required_paths required_modules
  local p mod

  required_paths=(
    "${wcp_root}/bin"
    "${wcp_root}/bin/wine"
    "${wcp_root}/bin/wineserver"
    "${wcp_root}/lib"
    "${wcp_root}/lib/wine"
    "${wcp_root}/lib/wine/aarch64-unix"
    "${wcp_root}/lib/wine/aarch64-windows"
    "${wcp_root}/lib/wine/i386-windows"
    "${wcp_root}/share"
    "${wcp_root}/prefixPack.txz"
    "${wcp_root}/profile.json"
  )

  for p in "${required_paths[@]}"; do
    [[ -e "${p}" ]] || wcp_fail "WCP layout is incomplete, missing: ${p#${wcp_root}/}"
  done

  if [[ -d "${wcp_root}/lib/wine/arm64ec-windows" ]]; then
    wcp_log "Detected explicit arm64ec-windows layer"
  fi

  required_modules=(
    "ntdll.so"
    "win32u.so"
    "ws2_32.so"
    "winevulkan.so"
  )

  for mod in "${required_modules[@]}"; do
    [[ -f "${wcp_root}/lib/wine/aarch64-unix/${mod}" ]] || wcp_fail "Wine unix module missing: lib/wine/aarch64-unix/${mod}"
  done

  if [[ "${WCP_ENABLE_SDL2_RUNTIME:-1}" == "1" ]]; then
    if [[ ! -f "${wcp_root}/lib/wine/aarch64-unix/winebus.so" && ! -f "${wcp_root}/lib/wine/aarch64-unix/winebus.sys.so" ]]; then
      wcp_fail "Wine unix module missing: lib/wine/aarch64-unix/winebus.so (or winebus.sys.so)"
    fi
  fi

  winlator_validate_launchers
  wcp_log "ARM64EC WCP tree validation passed"
}

pack_wcp() {
  local wcp_root="$1" out_dir="$2" wcp_name="$3"
  local out_wcp
  : "${WCP_COMPRESS:=xz}"

  mkdir -p "${out_dir}"
  out_wcp="${out_dir}/${wcp_name}.wcp"

  case "${WCP_COMPRESS}" in
    xz)
      tar -cJf "${out_wcp}" -C "${wcp_root}" .
      ;;
    zst|zstd)
      tar --zstd -cf "${out_wcp}" -C "${wcp_root}" .
      ;;
    *)
      wcp_fail "WCP_COMPRESS must be xz or zst"
      ;;
  esac

  printf '%s\n' "${out_wcp}"
}

smoke_check_wcp() {
  local wcp_path="$1"
  local wcp_compress="${2:-${WCP_COMPRESS:-xz}}"
  local list_file normalized_file shebang

  [[ -f "${wcp_path}" ]] || wcp_fail "WCP artifact not found: ${wcp_path}"

  list_file="$(mktemp)"
  normalized_file="$(mktemp)"
  trap 'rm -f "${list_file}" "${normalized_file}"' RETURN

  case "${wcp_compress}" in
    xz)
      tar -tJf "${wcp_path}" > "${list_file}"
      ;;
    zst|zstd)
      tar --zstd -tf "${wcp_path}" > "${list_file}"
      ;;
    *)
      wcp_fail "WCP_COMPRESS must be xz or zst"
      ;;
  esac

  sed 's#^\./##' "${list_file}" > "${normalized_file}"

  grep -qx 'bin/wine' "${normalized_file}" || wcp_fail "Missing bin/wine"
  grep -qx 'bin/wineserver' "${normalized_file}" || wcp_fail "Missing bin/wineserver"
  grep -qx 'prefixPack.txz' "${normalized_file}" || wcp_fail "Missing prefixPack.txz"
  grep -qx 'profile.json' "${normalized_file}" || wcp_fail "Missing profile.json"
  grep -q '^lib/wine/aarch64-unix/' "${normalized_file}" || wcp_fail "Missing lib/wine/aarch64-unix"
  grep -q '^lib/wine/aarch64-windows/' "${normalized_file}" || wcp_fail "Missing lib/wine/aarch64-windows"
  grep -q '^lib/wine/i386-windows/' "${normalized_file}" || wcp_fail "Missing lib/wine/i386-windows"

  if grep -qx 'bin/wine.glibc-real' "${normalized_file}"; then
    grep -qx 'lib/wine/wcp-glibc-runtime/ld-linux-aarch64.so.1' "${normalized_file}" || wcp_fail "Missing bundled glibc runtime loader"
    case "${wcp_compress}" in
      xz) shebang="$(tar -xJOf "${wcp_path}" ./bin/wine 2>/dev/null | head -n1)" ;;
      zst|zstd) shebang="$(tar --zstd -xOf "${wcp_path}" ./bin/wine 2>/dev/null | head -n1)" ;;
    esac
    [[ "${shebang}" == "#!/system/bin/sh" ]] || wcp_fail "bin/wine wrapper must use #!/system/bin/sh"
  fi

  (
    cd "$(dirname "${wcp_path}")"
    sha256sum "$(basename "${wcp_path}")" > SHA256SUMS
  )

  wcp_log "WCP smoke checks passed for ${wcp_path}"
}
