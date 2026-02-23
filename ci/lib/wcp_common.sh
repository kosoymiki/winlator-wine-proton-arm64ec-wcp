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

wcp_validate_winlator_profile_identifier() {
  local version_name="$1" version_code="$2"

  # Winlator Ludashi currently parses installed Wine entries through
  # Wine-<versionName>-<versionCode> and strips exactly two trailing chars
  # from identifier, so versionCode must remain one digit.
  [[ "${version_code}" =~ ^[0-9]$ ]] || wcp_fail "WCP_VERSION_CODE must be a single digit for Winlator compatibility (got: ${version_code})"

  # Must map to regex: ^(wine|proton)-([0-9\\.]+)-?([0-9\\.]+)?-(x86|x86_64|arm64ec)$
  [[ "${version_name}" =~ ^[0-9]+([.][0-9]+)*(-[0-9]+([.][0-9]+)*)?-(x86|x86_64|arm64ec)$ ]] || \
    wcp_fail "WCP_VERSION_NAME must be Winlator-parseable (example: 10.32-arm64ec), got: ${version_name}"
}

ensure_prefix_pack() {
  local dst="${1:-${PREFIX_PACK_PATH:-${ROOT_DIR:-$(pwd)}/prefixPack.txz}}"
  local url="${PREFIX_PACK_URL:-https://github.com/GameNative/bionic-prefix-files/releases/latest/download/prefixPack.txz}"
  local tmp

  if [[ -f "${dst}" ]]; then
    return
  fi

  wcp_require_cmd curl
  tmp="$(mktemp)"
  wcp_log "Downloading prefixPack.txz from ${url}"
  if ! curl -fL --retry 5 --retry-delay 2 -o "${tmp}" "${url}"; then
    rm -f "${tmp}"
    wcp_fail "Failed to download prefixPack from ${url}"
  fi
  mkdir -p "$(dirname "${dst}")"
  mv "${tmp}" "${dst}"
}

wcp_check_host_arch() {
  local arch
  arch="$(uname -m)"
  if [[ "${arch}" != "aarch64" && "${arch}" != "arm64" ]]; then
    wcp_fail "ARM64 host is required (aarch64/arm64). Current arch: ${arch}"
  fi
}

wcp_try_bootstrap_winevulkan() {
  local wine_src_dir="$1"
  local log_file="${2:-}"
  if [[ "$#" -ge 2 ]]; then
    shift 2
  else
    shift "$#"
  fi

  local make_vulkan_py vk_xml video_xml search_dir
  local -a search_roots cmd

  [[ -d "${wine_src_dir}" ]] || wcp_fail "wine source directory not found: ${wine_src_dir}"
  [[ -f "${wine_src_dir}/include/wine/vulkan.h" ]] && return 0

  make_vulkan_py="${wine_src_dir}/dlls/winevulkan/make_vulkan"
  if [[ ! -f "${make_vulkan_py}" ]]; then
    wcp_log "Skipping make_vulkan bootstrap: missing ${make_vulkan_py}"
    return 0
  fi

  search_roots=(
    "${wine_src_dir}/dlls/winevulkan"
    "${wine_src_dir}/Vulkan-Headers/registry"
  )
  for search_dir in "$@"; do
    [[ -n "${search_dir}" ]] || continue
    search_roots+=(
      "${search_dir}/dlls/winevulkan"
      "${search_dir}/Vulkan-Headers/registry"
      "${search_dir}"
    )
  done

  vk_xml=""
  video_xml=""
  for search_dir in "${search_roots[@]}"; do
    if [[ -f "${search_dir}/vk.xml" ]]; then
      vk_xml="${search_dir}/vk.xml"
      [[ -f "${search_dir}/video.xml" ]] && video_xml="${search_dir}/video.xml"
      break
    fi
  done

  if [[ -z "${vk_xml}" ]]; then
    wcp_log "Skipping make_vulkan bootstrap: vk.xml not found in known registry paths"
    return 0
  fi

  wcp_require_cmd python3
  cmd=(python3 "${make_vulkan_py}" -x "${vk_xml}")
  [[ -n "${video_xml}" ]] && cmd+=(-X "${video_xml}")

  if [[ -n "${log_file}" ]]; then
    mkdir -p "$(dirname -- "${log_file}")"
    "${cmd[@]}" >"${log_file}" 2>&1 || wcp_fail "make_vulkan failed; see ${log_file}"
  else
    "${cmd[@]}"
  fi
}

wcp_ensure_configure_script() {
  local wine_src_dir="$1"

  if [[ -x "${wine_src_dir}/configure" ]]; then
    return
  fi

  [[ -f "${wine_src_dir}/configure.ac" ]] || wcp_fail "Missing configure script and configure.ac in ${wine_src_dir}"
  wcp_require_cmd autoreconf

  wcp_log "configure is missing in ${wine_src_dir}; generating it with autoreconf -ifv"
  pushd "${wine_src_dir}" >/dev/null
  if [[ -x tools/make_requests ]]; then
    tools/make_requests
  fi
  if [[ -x tools/make_specfiles ]]; then
    tools/make_specfiles
  fi
  wcp_try_bootstrap_winevulkan "${wine_src_dir}"
  autoreconf -ifv
  popd >/dev/null

  [[ -f "${wine_src_dir}/configure" ]] || wcp_fail "autoreconf did not produce configure in ${wine_src_dir}"
  chmod +x "${wine_src_dir}/configure" || true
}

build_wine_tools_host() {
  local wine_src_dir="$1" build_dir="$2"
  local -a configure_args

  wcp_ensure_configure_script "${wine_src_dir}"
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

  wcp_ensure_configure_script "${wine_src_dir}"

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

  wcp_validate_winlator_profile_identifier "${WCP_VERSION_NAME}" "${WCP_VERSION_CODE}"

  prefix_pack_path="${PREFIX_PACK_PATH:-${ROOT_DIR}/prefixPack.txz}"
  ensure_prefix_pack "${prefix_pack_path}"
  profile_name="${WCP_PROFILE_NAME}"
  profile_type="${WCP_PROFILE_TYPE}"

  [[ -d "${stage_dir}/usr" ]] || wcp_fail "Stage is missing usr/ payload: ${stage_dir}/usr"

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
  trap 'rm -f "${list_file:-}" "${normalized_file:-}"' RETURN

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
