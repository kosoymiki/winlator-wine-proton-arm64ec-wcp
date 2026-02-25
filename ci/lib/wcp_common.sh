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

wcp_make_jobs() {
  if [[ -n "${WCP_WINE_BUILD_JOBS:-}" ]]; then
    printf '%s' "${WCP_WINE_BUILD_JOBS}"
    return
  fi
  if [[ -n "${WCP_BUILD_JOBS:-}" ]]; then
    printf '%s' "${WCP_BUILD_JOBS}"
    return
  fi
  nproc
}

source "${WCP_COMMON_DIR}/runtime-bundle-lock.sh"

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

wcp_require_enum() {
  local flag_name="$1" flag_value="$2"; shift 2
  local candidate
  for candidate in "$@"; do
    [[ "${flag_value}" == "${candidate}" ]] && return 0
  done
  wcp_fail "${flag_name} must be one of: $* (got: ${flag_value})"
}

wcp_json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "${s}"
}

wcp_sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
  else
    wcp_fail "Neither sha256sum nor shasum is available"
  fi
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
  # Default to raw file in GameNative/bionic-prefix-files main branch.
  local url="${PREFIX_PACK_URL:-https://raw.githubusercontent.com/GameNative/bionic-prefix-files/main/prefixPack-arm64ec.txz}"
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

  if ! make -j"$(wcp_make_jobs)" tools; then
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

  make -j"$(wcp_make_jobs)"
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
  local prefix_pack_path profile_name profile_type utc_now runtime_class_detected

  : "${ROOT_DIR:=$(cd -- "${WCP_COMMON_DIR}/../.." && pwd)}"
  : "${WCP_TARGET_RUNTIME:=winlator-bionic}"
  : "${WCP_RUNTIME_CLASS_TARGET:=bionic-native}"
  : "${WCP_RUNTIME_CLASS_ENFORCE:=1}"
  : "${WCP_VERSION_NAME:=arm64ec}"
  : "${WCP_VERSION_CODE:=0}"
  : "${WCP_DESCRIPTION:=ARM64EC WCP package}"
  : "${WCP_NAME:=arm64ec-wcp}"
  : "${WCP_PROFILE_NAME:=${WCP_NAME}}"
  : "${WCP_PROFILE_TYPE:=Wine}"
  : "${WCP_CHANNEL:=stable}"
  : "${WCP_DELIVERY:=remote}"
  : "${WCP_DISPLAY_CATEGORY:=Wine/Proton}"
  : "${WCP_SOURCE_REPO:=${GITHUB_REPOSITORY:-kosoymiki/winlator-wine-proton-arm64ec-wcp}}"
  : "${WCP_RELEASE_TAG:=wcp-latest}"
  if [[ -z "${WCP_GLIBC_SOURCE_MODE+x}" ]]; then
    if [[ "${WCP_RUNTIME_CLASS_TARGET}" == "glibc-wrapped" ]]; then
      WCP_GLIBC_SOURCE_MODE="pinned-source"
    else
      WCP_GLIBC_SOURCE_MODE="host"
    fi
  fi
  : "${WCP_GLIBC_VERSION:=2.43}"
  : "${WCP_GLIBC_TARGET_VERSION:=2.43}"
  : "${WCP_GLIBC_SOURCE_URL:=https://ftp.gnu.org/gnu/glibc/glibc-2.43.tar.xz}"
  : "${WCP_GLIBC_SOURCE_SHA256:=d9c86c6b5dbddb43a3e08270c5844fc5177d19442cf5b8df4be7c07cd5fa3831}"
  : "${WCP_GLIBC_SOURCE_REF:=glibc-2.43}"
  : "${WCP_GLIBC_PATCHSET_ID:=}"
  : "${WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR:=}"
  : "${WCP_GLIBC_RUNTIME_PATCH_SCRIPT:=}"
  : "${WCP_RUNTIME_BUNDLE_LOCK_ID:=glibc-2.43-bundle-v1}"
  : "${WCP_RUNTIME_BUNDLE_LOCK_FILE:=}"
  : "${WCP_RUNTIME_BUNDLE_ENFORCE_LOCK:=0}"
  : "${WCP_RUNTIME_BUNDLE_LOCK_MODE:=relaxed-enforce}"
  : "${WCP_INCLUDE_FEX_DLLS:=0}"
  : "${WCP_FEX_EXPECTATION_MODE:=external}"

  wcp_validate_winlator_profile_identifier "${WCP_VERSION_NAME}" "${WCP_VERSION_CODE}"
  wcp_require_enum WCP_RUNTIME_CLASS_TARGET "${WCP_RUNTIME_CLASS_TARGET}" bionic-native glibc-wrapped
  wcp_require_bool WCP_RUNTIME_CLASS_ENFORCE "${WCP_RUNTIME_CLASS_ENFORCE}"
  wcp_require_bool WCP_INCLUDE_FEX_DLLS "${WCP_INCLUDE_FEX_DLLS}"
  wcp_require_enum WCP_FEX_EXPECTATION_MODE "${WCP_FEX_EXPECTATION_MODE}" external bundled

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

  winlator_adopt_bionic_launchers "${wcp_root}"
  winlator_wrap_glibc_launchers
  generate_winetools_layer "${wcp_root}"
  runtime_class_detected="$(winlator_detect_runtime_class "${wcp_root}")"

  utc_now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  cat > "${wcp_root}/profile.json" <<EOF_PROFILE
{
  "type": "${profile_type}",
  "name": "${profile_name}",
  "versionName": "${WCP_VERSION_NAME}",
  "versionCode": ${WCP_VERSION_CODE},
  "description": "${WCP_DESCRIPTION}",
  "channel": "$(wcp_json_escape "${WCP_CHANNEL}")",
  "delivery": "$(wcp_json_escape "${WCP_DELIVERY}")",
  "displayCategory": "$(wcp_json_escape "${WCP_DISPLAY_CATEGORY}")",
  "sourceRepo": "$(wcp_json_escape "${WCP_SOURCE_REPO}")",
  "releaseTag": "$(wcp_json_escape "${WCP_RELEASE_TAG}")",
  "files": [],
  "wine": {
    "binPath": "bin",
    "libPath": "lib",
    "prefixPack": "prefixPack.txz"
  },
  "runtime": {
    "target": "${WCP_TARGET_RUNTIME}",
    "runtimeClassTarget": "$(wcp_json_escape "${WCP_RUNTIME_CLASS_TARGET}")",
    "runtimeClassDetected": "$(wcp_json_escape "${runtime_class_detected}")",
    "fexExpectationMode": "$(wcp_json_escape "${WCP_FEX_EXPECTATION_MODE}")",
    "fexBundledInWcp": ${WCP_INCLUDE_FEX_DLLS}
  },
  "built": "${utc_now}"
}
EOF_PROFILE
}

wcp_write_forensic_manifest() {
  local wcp_root="$1"
  local forensic_root manifest_file source_refs_file env_file index_file hashes_file utc_now repo_commit repo_remote
  local glibc_runtime_index glibc_runtime_markers glibc_runtime_present
  local glibc_stage_reports_index glibc_stage_reports_dir
  local fex_bundled_present=0
  local -a critical_paths
  local rel hash runtime_class_detected

  : "${WCP_FORENSICS_ALWAYS_ON:=1}"
  [[ "${WCP_FORENSICS_ALWAYS_ON}" == "1" ]] || return 0
  [[ -d "${wcp_root}" ]] || wcp_fail "WCP root not found for forensic manifest: ${wcp_root}"

  forensic_root="${wcp_root}/share/wcp-forensics"
  mkdir -p "${forensic_root}"
  manifest_file="${forensic_root}/manifest.json"
  source_refs_file="${forensic_root}/source-refs.json"
  env_file="${forensic_root}/build-env.txt"
  index_file="${forensic_root}/file-index.txt"
  hashes_file="${forensic_root}/critical-sha256.tsv"
  glibc_runtime_index="${forensic_root}/glibc-runtime-libs.tsv"
  glibc_runtime_markers="${forensic_root}/glibc-runtime-version-markers.tsv"
  glibc_stage_reports_index="${forensic_root}/glibc-stage-reports-index.tsv"
  glibc_stage_reports_dir="${forensic_root}/glibc-stage-reports"
  utc_now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  repo_commit=""
  repo_remote=""
  if [[ -n "${ROOT_DIR:-}" && -d "${ROOT_DIR}/.git" ]]; then
    repo_commit="$(git -C "${ROOT_DIR}" rev-parse HEAD 2>/dev/null || true)"
    repo_remote="$(git -C "${ROOT_DIR}" remote get-url origin 2>/dev/null || true)"
  fi

  find "${wcp_root}" -type f -printf '%P\t%s\n' | LC_ALL=C sort > "${index_file}"

  critical_paths=(
    "profile.json"
    "bin/wine"
    "bin/wineserver"
    "bin/wine.glibc-real"
    "bin/wineserver.glibc-real"
    "lib/wine/aarch64-unix/ntdll.so"
    "lib/wine/aarch64-unix/win32u.so"
    "lib/wine/aarch64-unix/ws2_32.so"
    "lib/wine/aarch64-unix/winevulkan.so"
    "lib/wine/aarch64-unix/winebus.so"
    "lib/wine/aarch64-unix/winebus.sys.so"
    "lib/wine/wcp-glibc-runtime/ld-linux-aarch64.so.1"
    "lib/wine/wcp-glibc-runtime/libc.so.6"
    "lib/wine/wcp-glibc-runtime/libstdc++.so.6"
    "lib/wine/wcp-glibc-runtime/libgcc_s.so.1"
    "lib/wine/wcp-glibc-runtime/libSDL2-2.0.so.0"
    "prefixPack.txz"
  )

  : > "${hashes_file}"
  for rel in "${critical_paths[@]}"; do
    if [[ -f "${wcp_root}/${rel}" ]]; then
      hash="$(wcp_sha256_file "${wcp_root}/${rel}")"
      printf '%s\t%s\n' "${rel}" "${hash}" >> "${hashes_file}"
    else
      printf '%s\t%s\n' "${rel}" "MISSING" >> "${hashes_file}"
    fi
  done

  {
    echo "generatedAt=${utc_now}"
    echo "WCP_NAME=${WCP_NAME:-}"
    echo "WCP_VERSION_NAME=${WCP_VERSION_NAME:-}"
    echo "WCP_VERSION_CODE=${WCP_VERSION_CODE:-}"
    echo "WCP_PROFILE_NAME=${WCP_PROFILE_NAME:-}"
    echo "WCP_PROFILE_TYPE=${WCP_PROFILE_TYPE:-Wine}"
    echo "WCP_TARGET_RUNTIME=${WCP_TARGET_RUNTIME:-}"
    echo "WCP_RUNTIME_CLASS_TARGET=${WCP_RUNTIME_CLASS_TARGET:-}"
    echo "WCP_RUNTIME_CLASS_ENFORCE=${WCP_RUNTIME_CLASS_ENFORCE:-}"
    echo "WCP_GLIBC_SOURCE_MODE=${WCP_GLIBC_SOURCE_MODE:-}"
    echo "WCP_GLIBC_VERSION=${WCP_GLIBC_VERSION:-}"
    echo "WCP_GLIBC_TARGET_VERSION=${WCP_GLIBC_TARGET_VERSION:-}"
    echo "WCP_GLIBC_SOURCE_URL=${WCP_GLIBC_SOURCE_URL:-}"
    echo "WCP_GLIBC_SOURCE_SHA256=${WCP_GLIBC_SOURCE_SHA256:-}"
    echo "WCP_GLIBC_SOURCE_REF=${WCP_GLIBC_SOURCE_REF:-}"
    echo "WCP_GLIBC_PATCHSET_ID=${WCP_GLIBC_PATCHSET_ID:-}"
    echo "WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR=${WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR:-}"
    echo "WCP_GLIBC_RUNTIME_PATCH_SCRIPT=${WCP_GLIBC_RUNTIME_PATCH_SCRIPT:-}"
    echo "WCP_RUNTIME_BUNDLE_LOCK_ID=${WCP_RUNTIME_BUNDLE_LOCK_ID:-}"
    echo "WCP_RUNTIME_BUNDLE_LOCK_FILE=${WCP_RUNTIME_BUNDLE_LOCK_FILE:-}"
    echo "WCP_RUNTIME_BUNDLE_ENFORCE_LOCK=${WCP_RUNTIME_BUNDLE_ENFORCE_LOCK:-}"
    echo "WCP_RUNTIME_BUNDLE_LOCK_MODE=${WCP_RUNTIME_BUNDLE_LOCK_MODE:-}"
    echo "WCP_INCLUDE_FEX_DLLS=${WCP_INCLUDE_FEX_DLLS:-}"
    echo "WCP_FEX_EXPECTATION_MODE=${WCP_FEX_EXPECTATION_MODE:-}"
    echo "WCP_BIONIC_LAUNCHER_SOURCE_WCP_PATH=${WCP_BIONIC_LAUNCHER_SOURCE_WCP_PATH:-}"
    echo "WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL=${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:-}"
    echo "WCP_COMPRESS=${WCP_COMPRESS:-}"
    echo "TARGET_HOST=${TARGET_HOST:-}"
    echo "LLVM_MINGW_TAG=${LLVM_MINGW_TAG:-}"
    echo "STRIP_STAGE=${STRIP_STAGE:-}"
  } > "${env_file}"

  cat > "${source_refs_file}" <<EOF_SOURCE_REFS
{
  "repo": {
    "origin": "$(wcp_json_escape "${repo_remote}")",
    "commit": "$(wcp_json_escape "${repo_commit}")"
  },
  "inputs": {
    "WINE_REPO": "$(wcp_json_escape "${WINE_REPO:-}")",
    "WINE_BRANCH": "$(wcp_json_escape "${WINE_BRANCH:-}")",
    "WINE_REF": "$(wcp_json_escape "${WINE_REF:-}")",
    "VALVE_WINE_REPO": "$(wcp_json_escape "${VALVE_WINE_REPO:-}")",
    "VALVE_WINE_REF": "$(wcp_json_escape "${VALVE_WINE_REF:-}")",
    "ANDRE_WINE_REPO": "$(wcp_json_escape "${ANDRE_WINE_REPO:-}")",
    "ANDRE_ARM64EC_REF": "$(wcp_json_escape "${ANDRE_ARM64EC_REF:-}")",
    "PROTON_GE_REPO": "$(wcp_json_escape "${PROTON_GE_REPO:-}")",
    "PROTON_GE_REF": "$(wcp_json_escape "${PROTON_GE_REF:-}")",
    "PROTONWINE_REPO": "$(wcp_json_escape "${PROTONWINE_REPO:-}")",
    "PROTONWINE_REF": "$(wcp_json_escape "${PROTONWINE_REF:-}")",
    "HANGOVER_REPO": "$(wcp_json_escape "${HANGOVER_REPO:-}")",
    "FEX_SOURCE_MODE": "$(wcp_json_escape "${FEX_SOURCE_MODE:-}")",
    "WCP_GLIBC_SOURCE_MODE": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_MODE:-}")",
    "WCP_GLIBC_VERSION": "$(wcp_json_escape "${WCP_GLIBC_VERSION:-}")",
    "WCP_GLIBC_TARGET_VERSION": "$(wcp_json_escape "${WCP_GLIBC_TARGET_VERSION:-}")",
    "WCP_GLIBC_SOURCE_URL": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_URL:-}")",
    "WCP_GLIBC_SOURCE_SHA256": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_SHA256:-}")",
    "WCP_GLIBC_SOURCE_REF": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_REF:-}")",
    "WCP_GLIBC_PATCHSET_ID": "$(wcp_json_escape "${WCP_GLIBC_PATCHSET_ID:-}")",
    "WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR": "$(wcp_json_escape "${WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR:-}")",
    "WCP_GLIBC_RUNTIME_PATCH_SCRIPT": "$(wcp_json_escape "${WCP_GLIBC_RUNTIME_PATCH_SCRIPT:-}")",
    "WCP_RUNTIME_CLASS_TARGET": "$(wcp_json_escape "${WCP_RUNTIME_CLASS_TARGET:-}")",
    "WCP_RUNTIME_CLASS_ENFORCE": "$(wcp_json_escape "${WCP_RUNTIME_CLASS_ENFORCE:-}")",
    "WCP_RUNTIME_BUNDLE_LOCK_ID": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_LOCK_ID:-}")",
    "WCP_RUNTIME_BUNDLE_LOCK_FILE": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_LOCK_FILE:-}")",
    "WCP_RUNTIME_BUNDLE_ENFORCE_LOCK": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_ENFORCE_LOCK:-}")",
    "WCP_RUNTIME_BUNDLE_LOCK_MODE": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_LOCK_MODE:-}")",
    "WCP_INCLUDE_FEX_DLLS": "$(wcp_json_escape "${WCP_INCLUDE_FEX_DLLS:-}")",
    "WCP_FEX_EXPECTATION_MODE": "$(wcp_json_escape "${WCP_FEX_EXPECTATION_MODE:-}")",
    "WCP_BIONIC_LAUNCHER_SOURCE_WCP_PATH": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_PATH:-}")",
    "WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL": "$(wcp_json_escape "${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:-}")"
  }
}
EOF_SOURCE_REFS

  glibc_runtime_present=0
  : > "${glibc_runtime_index}"
  if [[ -d "${wcp_root}/lib/wine/wcp-glibc-runtime" ]]; then
    glibc_runtime_present=1
    while IFS= read -r rel; do
      [[ -f "${wcp_root}/${rel}" ]] || continue
      printf '%s\t%s\t%s\n' "${rel}" "$(stat -c '%s' "${wcp_root}/${rel}" 2>/dev/null || echo 0)" "$(wcp_sha256_file "${wcp_root}/${rel}")" >> "${glibc_runtime_index}"
    done < <(find "${wcp_root}/lib/wine/wcp-glibc-runtime" -type f -printf '%P\n' | LC_ALL=C sort | sed 's#^#lib/wine/wcp-glibc-runtime/#')
  else
    echo "ABSENT" > "${glibc_runtime_index}"
  fi
  wcp_runtime_write_glibc_markers "${wcp_root}" "${glibc_runtime_markers}"

  rm -rf "${glibc_stage_reports_dir}"
  : > "${glibc_stage_reports_index}"
  if [[ -d "${wcp_root}/lib/wine/wcp-glibc-runtime/.build-reports" ]]; then
    mkdir -p "${glibc_stage_reports_dir}"
    while IFS= read -r rel; do
      [[ -f "${wcp_root}/${rel}" ]] || continue
      mkdir -p "${glibc_stage_reports_dir}/$(dirname -- "${rel#lib/wine/wcp-glibc-runtime/.build-reports/}")"
      cp -f "${wcp_root}/${rel}" "${glibc_stage_reports_dir}/${rel#lib/wine/wcp-glibc-runtime/.build-reports/}"
      printf '%s\t%s\n' "${rel#lib/wine/wcp-glibc-runtime/.build-reports/}" "$(stat -c '%s' "${wcp_root}/${rel}" 2>/dev/null || echo 0)" >> "${glibc_stage_reports_index}"
    done < <(find "${wcp_root}/lib/wine/wcp-glibc-runtime/.build-reports" -type f -printf '%P\n' | LC_ALL=C sort | sed 's#^#lib/wine/wcp-glibc-runtime/.build-reports/#')
  else
    echo "ABSENT" > "${glibc_stage_reports_index}"
  fi

  if [[ -f "${wcp_root}/lib/wine/aarch64-windows/libarm64ecfex.dll" || -f "${wcp_root}/lib/wine/aarch64-windows/libwow64fex.dll" ]]; then
    fex_bundled_present=1
  fi
  runtime_class_detected="$(winlator_detect_runtime_class "${wcp_root}")"

  cat > "${manifest_file}" <<EOF_MANIFEST
{
  "schema": "wcp-forensics/v1",
  "generatedAt": "${utc_now}",
  "package": {
    "name": "$(wcp_json_escape "${WCP_NAME:-}")",
    "profileName": "$(wcp_json_escape "${WCP_PROFILE_NAME:-${WCP_NAME:-}}")",
    "profileType": "$(wcp_json_escape "${WCP_PROFILE_TYPE:-Wine}")",
    "versionName": "$(wcp_json_escape "${WCP_VERSION_NAME:-}")",
    "versionCode": ${WCP_VERSION_CODE:-0},
    "runtimeTarget": "$(wcp_json_escape "${WCP_TARGET_RUNTIME:-}")",
    "runtimeClassTarget": "$(wcp_json_escape "${WCP_RUNTIME_CLASS_TARGET:-}")",
    "runtimeClassDetected": "$(wcp_json_escape "${runtime_class_detected}")",
    "fexBundledInWcp": ${fex_bundled_present},
    "fexExpectationMode": "$(wcp_json_escape "${WCP_FEX_EXPECTATION_MODE:-}")"
  },
  "glibcRuntime": {
    "present": ${glibc_runtime_present},
    "sourceMode": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_MODE:-}")",
    "version": "$(wcp_json_escape "${WCP_GLIBC_VERSION:-}")",
    "targetVersion": "$(wcp_json_escape "${WCP_GLIBC_TARGET_VERSION:-}")",
    "sourceUrl": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_URL:-}")",
    "sourceRef": "$(wcp_json_escape "${WCP_GLIBC_SOURCE_REF:-}")",
    "patchsetId": "$(wcp_json_escape "${WCP_GLIBC_PATCHSET_ID:-}")",
    "runtimeLockId": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_LOCK_ID:-}")",
    "runtimeLockFile": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_LOCK_FILE:-}")",
    "runtimeLockEnforce": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_ENFORCE_LOCK:-}")",
    "runtimeLockMode": "$(wcp_json_escape "${WCP_RUNTIME_BUNDLE_LOCK_MODE:-}")",
    "runtimePatchOverlayDir": "$(wcp_json_escape "${WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR:-}")",
    "runtimePatchScript": "$(wcp_json_escape "${WCP_GLIBC_RUNTIME_PATCH_SCRIPT:-}")",
    "libsIndex": "share/wcp-forensics/glibc-runtime-libs.tsv",
    "versionMarkers": "share/wcp-forensics/glibc-runtime-version-markers.tsv",
    "stageReportsIndex": "share/wcp-forensics/glibc-stage-reports-index.tsv"
  },
  "files": {
    "index": "share/wcp-forensics/file-index.txt",
    "criticalSha256": "share/wcp-forensics/critical-sha256.tsv",
    "glibcRuntimeIndex": "share/wcp-forensics/glibc-runtime-libs.tsv",
    "glibcRuntimeVersionMarkers": "share/wcp-forensics/glibc-runtime-version-markers.tsv",
    "glibcStageReportsIndex": "share/wcp-forensics/glibc-stage-reports-index.tsv",
    "buildEnv": "share/wcp-forensics/build-env.txt",
    "sourceRefs": "share/wcp-forensics/source-refs.json"
  }
}
EOF_MANIFEST

  wcp_log "WCP forensic manifest written: ${forensic_root}"
}

wcp_validate_forensic_manifest() {
  local wcp_root="$1"
  : "${WCP_FORENSICS_ALWAYS_ON:=1}"
  [[ "${WCP_FORENSICS_ALWAYS_ON}" == "1" ]] || return 0

  local required=(
    "${wcp_root}/share/wcp-forensics/manifest.json"
    "${wcp_root}/share/wcp-forensics/critical-sha256.tsv"
    "${wcp_root}/share/wcp-forensics/glibc-runtime-libs.tsv"
    "${wcp_root}/share/wcp-forensics/glibc-runtime-version-markers.tsv"
    "${wcp_root}/share/wcp-forensics/glibc-stage-reports-index.tsv"
    "${wcp_root}/share/wcp-forensics/file-index.txt"
    "${wcp_root}/share/wcp-forensics/build-env.txt"
    "${wcp_root}/share/wcp-forensics/source-refs.json"
  )
  local p
  for p in "${required[@]}"; do
    [[ -f "${p}" ]] || wcp_fail "WCP forensic manifest is incomplete, missing: ${p#${wcp_root}/}"
  done
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

  if [[ "${WCP_FEX_EXPECTATION_MODE:-external}" == "bundled" ]]; then
    [[ -f "${wcp_root}/lib/wine/aarch64-windows/libarm64ecfex.dll" ]] || wcp_fail "Bundled FEX mode requires lib/wine/aarch64-windows/libarm64ecfex.dll"
    [[ -f "${wcp_root}/lib/wine/aarch64-windows/libwow64fex.dll" ]] || wcp_fail "Bundled FEX mode requires lib/wine/aarch64-windows/libwow64fex.dll"
  fi

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
  wcp_validate_forensic_manifest "${wcp_root}"
  wcp_runtime_verify_glibc_lock "${wcp_root}"
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
  grep -qx 'share/wcp-forensics/manifest.json' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/manifest.json"
  grep -qx 'share/wcp-forensics/critical-sha256.tsv' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/critical-sha256.tsv"
  grep -qx 'share/wcp-forensics/file-index.txt' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/file-index.txt"
  grep -qx 'share/wcp-forensics/build-env.txt' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/build-env.txt"
  grep -qx 'share/wcp-forensics/source-refs.json' "${normalized_file}" || wcp_fail "Missing share/wcp-forensics/source-refs.json"
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
