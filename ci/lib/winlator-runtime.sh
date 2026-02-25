#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for packaging Wine/Proton runtimes for Winlator bionic.
# Expects caller to define: log(), fail(), WCP_TARGET_RUNTIME, WCP_ROOT.

winlator_detect_runtime_class() {
  local wcp_root="${1:-${WCP_ROOT:-}}"
  local wine_bin wine_real unix_abi
  [[ -n "${wcp_root}" ]] || { printf '%s' "unknown"; return 0; }

  wine_bin="${wcp_root}/bin/wine"
  wine_real="${wcp_root}/bin/wine.glibc-real"

  if [[ -f "${wine_real}" ]]; then
    printf '%s' "glibc-wrapped"
    return 0
  fi

  if winlator_is_glibc_launcher "${wine_bin}"; then
    printf '%s' "glibc-raw"
    return 0
  fi

  if [[ -f "${wine_bin}" ]]; then
    unix_abi="$(winlator_detect_unix_module_abi "${wcp_root}")"
    if [[ "${unix_abi}" == "glibc-unix" ]]; then
      printf '%s' "bionic-launcher-glibc-unix"
      return 0
    fi
    printf '%s' "bionic-native"
    return 0
  fi

  printf '%s' "unknown"
}

winlator_runtime_target_is_glibc_wrapped() {
  [[ "${WCP_RUNTIME_CLASS_TARGET:-bionic-native}" == "glibc-wrapped" ]]
}

winlator_runtime_target_enforced() {
  [[ "${WCP_RUNTIME_CLASS_ENFORCE:-0}" == "1" ]]
}

winlator_bionic_mainline_strict() {
  [[ "${WCP_MAINLINE_BIONIC_ONLY:-0}" == "1" && "${WCP_RUNTIME_CLASS_ENFORCE:-0}" == "1" ]]
}

winlator_sha256_file() {
  local file_path="$1"
  command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required"
  sha256sum "${file_path}" | awk '{print tolower($1)}'
}

winlator_verify_sha256() {
  local file_path="$1"
  local expected_sha="$2"
  local label="${3:-artifact}"
  local actual_sha

  [[ -n "${expected_sha}" ]] || return 0
  [[ -f "${file_path}" ]] || fail "Cannot verify ${label} SHA256: missing file ${file_path}"
  actual_sha="$(winlator_sha256_file "${file_path}")"
  if [[ "${actual_sha}" != "${expected_sha,,}" ]]; then
    fail "${label} SHA256 mismatch: expected=${expected_sha,,} actual=${actual_sha} file=${file_path}"
  fi
  log "Verified ${label} SHA256 (${expected_sha,,})"
}

winlator_download_cached_archive() {
  local url="$1"
  local cache_path="$2"
  local expected_sha="${3:-}"
  local label="${4:-archive}"
  local actual_sha

  [[ -n "${url}" ]] || fail "Cannot download ${label}: empty URL"
  command -v curl >/dev/null 2>&1 || fail "curl is required to download ${label}"
  command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required to verify ${label}"
  mkdir -p "$(dirname "${cache_path}")"

  if [[ -f "${cache_path}" ]]; then
    if [[ -n "${expected_sha}" ]]; then
      actual_sha="$(sha256sum "${cache_path}" | awk '{print tolower($1)}')"
      if [[ "${actual_sha}" == "${expected_sha,,}" ]]; then
        log "Using cached ${label} (${cache_path})"
        return 0
      fi
      log "Cached ${label} SHA256 mismatch; re-downloading (${cache_path})"
    else
      log "Using cached ${label} (${cache_path})"
      return 0
    fi
  fi

  log "Downloading ${label}: ${url}"
  curl -fL --retry 5 --retry-delay 2 --connect-timeout 20 --max-time 900 \
    -o "${cache_path}.tmp" "${url}" || fail "Failed to download ${label} from ${url}"
  mv -f "${cache_path}.tmp" "${cache_path}"
  winlator_verify_sha256 "${cache_path}" "${expected_sha}" "${label}"
}

winlator_detect_launcher_abi() {
  local bin_path="$1"
  [[ -e "${bin_path}" ]] || { printf '%s' "missing"; return 0; }
  if winlator_is_bionic_launcher "${bin_path}"; then
    printf '%s' "bionic"
    return 0
  fi
  if winlator_is_glibc_launcher "${bin_path}"; then
    printf '%s' "glibc"
    return 0
  fi
  if head -n1 "${bin_path}" 2>/dev/null | grep -q '^#!'; then
    printf '%s' "wrapper-script"
    return 0
  fi
  printf '%s' "unknown"
}

winlator_detect_runtime_mismatch_reason() {
  local wcp_root="${1:-${WCP_ROOT:-}}"
  local target="${2:-${WCP_RUNTIME_CLASS_TARGET:-bionic-native}}"
  local detected unix_abi wine_abi wineserver_abi

  [[ -n "${wcp_root}" ]] || { printf '%s' "missing-wcp-root"; return 0; }
  detected="$(winlator_detect_runtime_class "${wcp_root}")"
  unix_abi="$(winlator_detect_unix_module_abi "${wcp_root}")"
  wine_abi="$(winlator_detect_launcher_abi "${wcp_root}/bin/wine")"
  wineserver_abi="$(winlator_detect_launcher_abi "${wcp_root}/bin/wineserver")"

  case "${target}" in
    bionic-native)
      if [[ "${detected}" != "bionic-native" ]]; then
        printf '%s' "runtime-class:${detected}"
        return 0
      fi
      if [[ "${unix_abi}" != "bionic-unix" ]]; then
        printf '%s' "unix-abi:${unix_abi}"
        return 0
      fi
      if [[ "${wine_abi}" != "bionic" ]]; then
        printf '%s' "wine-launcher-abi:${wine_abi}"
        return 0
      fi
      if [[ "${wineserver_abi}" != "bionic" ]]; then
        printf '%s' "wineserver-launcher-abi:${wineserver_abi}"
        return 0
      fi
      ;;
    glibc-wrapped)
      if [[ "${detected}" != "glibc-wrapped" ]]; then
        printf '%s' "runtime-class:${detected}"
        return 0
      fi
      if [[ "${wine_abi}" != "wrapper-script" ]]; then
        printf '%s' "wine-launcher-abi:${wine_abi}"
        return 0
      fi
      if [[ "${wineserver_abi}" != "wrapper-script" ]]; then
        printf '%s' "wineserver-launcher-abi:${wineserver_abi}"
        return 0
      fi
      ;;
    *)
      printf '%s' "unknown-target:${target}"
      return 0
      ;;
  esac
  printf '%s' "none"
}

winlator_report_runtime_class_mismatch() {
  local detected="$1"
  local target="${WCP_RUNTIME_CLASS_TARGET:-bionic-native}"
  local msg="Runtime class target=${target} but detected=${detected}"
  if winlator_runtime_target_enforced; then
    fail "${msg}"
  fi
  log "runtime-class warning: ${msg} (continuing because WCP_RUNTIME_CLASS_ENFORCE=0)"
}

winlator_is_glibc_launcher() {
  local bin_path="$1"
  [[ -f "${bin_path}" ]] || return 1
  readelf -l "${bin_path}" 2>/dev/null | grep -q 'Requesting program interpreter: /lib/ld-linux-aarch64.so.1'
}

winlator_is_bionic_launcher() {
  local bin_path="$1"
  [[ -f "${bin_path}" ]] || return 1
  readelf -l "${bin_path}" 2>/dev/null | grep -q 'Requesting program interpreter: /system/bin/linker64'
}

winlator_detect_unix_module_abi() {
  local wcp_root="${1:-${WCP_ROOT:-}}"
  local ntdll soname
  local has_libc=0 has_libc6=0

  [[ -n "${wcp_root}" ]] || { printf '%s' "unknown"; return 0; }
  ntdll="${wcp_root}/lib/wine/aarch64-unix/ntdll.so"
  [[ -f "${ntdll}" ]] || { printf '%s' "missing"; return 0; }

  while IFS= read -r soname; do
    case "${soname}" in
      libc.so) has_libc=1 ;;
      libc.so.6) has_libc6=1 ;;
    esac
  done < <(winlator_collect_needed_sonames "${ntdll}" || true)

  if [[ "${has_libc6}" == "1" ]]; then
    printf '%s' "glibc-unix"
    return 0
  fi
  if [[ "${has_libc}" == "1" ]]; then
    printf '%s' "bionic-unix"
    return 0
  fi
  printf '%s' "unknown"
}

winlator_detect_unix_module_abi_from_path() {
  local module_path="$1"
  local soname
  local has_libc=0 has_libc6=0

  [[ -f "${module_path}" ]] || { printf '%s' "missing"; return 0; }

  while IFS= read -r soname; do
    case "${soname}" in
      libc.so) has_libc=1 ;;
      libc.so.6) has_libc6=1 ;;
    esac
  done < <(winlator_collect_needed_sonames "${module_path}" || true)

  if [[ "${has_libc6}" == "1" ]]; then
    printf '%s' "glibc-unix"
    return 0
  fi
  if [[ "${has_libc}" == "1" ]]; then
    printf '%s' "bionic-unix"
    return 0
  fi
  printf '%s' "unknown"
}

winlator_list_glibc_unix_modules() {
  local unix_dir="$1"
  local mod mod_name mod_abi
  local nullglob_was_set=0
  [[ -d "${unix_dir}" ]] || return 0

  if shopt -q nullglob; then
    nullglob_was_set=1
  fi
  shopt -s nullglob
  for mod in "${unix_dir}"/*.so; do
    [[ -f "${mod}" ]] || continue
    mod_name="$(basename "${mod}")"
    mod_abi="$(winlator_detect_unix_module_abi_from_path "${mod}")"
    [[ "${mod_abi}" == "glibc-unix" ]] || continue
    printf '%s\n' "${mod_name}"
  done
  if [[ "${nullglob_was_set}" == "0" ]]; then
    shopt -u nullglob
  fi
}

winlator_verify_bionic_unix_source_archive() {
  local source_wcp="$1"
  local label="${2:-bionic unix source WCP}"
  local tmp_extract src_unix source_unix_abi

  tmp_extract="$(mktemp -d)"
  if ! winlator_extract_wcp_archive "${source_wcp}" "${tmp_extract}"; then
    rm -rf "${tmp_extract}"
    fail "Unable to extract ${label}: ${source_wcp}"
  fi
  src_unix="$(find "${tmp_extract}" -type d -path '*/lib/wine/aarch64-unix' | head -n1 || true)"
  [[ -n "${src_unix}" ]] || { rm -rf "${tmp_extract}"; fail "${label} is missing lib/wine/aarch64-unix"; }
  source_unix_abi="$(winlator_detect_unix_module_abi_from_path "${src_unix}/ntdll.so")"
  rm -rf "${tmp_extract}"
  [[ "${source_unix_abi}" == "bionic-unix" ]] || fail "${label} has non-bionic unix ABI (detected=${source_unix_abi})"
}

winlator_verify_bionic_launcher_source_archive() {
  local source_wcp="$1"
  local label="${2:-bionic launcher source WCP}"
  local tmp_extract src_wine src_wineserver

  tmp_extract="$(mktemp -d)"
  if ! winlator_extract_wcp_archive "${source_wcp}" "${tmp_extract}"; then
    rm -rf "${tmp_extract}"
    fail "Unable to extract ${label}: ${source_wcp}"
  fi
  src_wine="$(find "${tmp_extract}" -type f -path '*/bin/wine' | head -n1 || true)"
  src_wineserver="$(find "${tmp_extract}" -type f -path '*/bin/wineserver' | head -n1 || true)"
  [[ -n "${src_wine}" ]] || { rm -rf "${tmp_extract}"; fail "${label} is missing bin/wine"; }
  [[ -n "${src_wineserver}" ]] || { rm -rf "${tmp_extract}"; fail "${label} is missing bin/wineserver"; }
  winlator_is_bionic_launcher "${src_wine}" || { rm -rf "${tmp_extract}"; fail "${label} bin/wine is not bionic-native (/system/bin/linker64)"; }
  winlator_is_bionic_launcher "${src_wineserver}" || { rm -rf "${tmp_extract}"; fail "${label} bin/wineserver is not bionic-native (/system/bin/linker64)"; }
  rm -rf "${tmp_extract}"
}

winlator_preflight_bionic_source_contract() {
  local strict_mode=0
  local launcher_wcp launcher_url launcher_sha launcher_cache
  local unix_wcp unix_url unix_sha unix_cache
  local launcher_actual_sha unix_actual_sha

  [[ "${WCP_TARGET_RUNTIME:-winlator-bionic}" == "winlator-bionic" ]] || return 0
  [[ "${WCP_RUNTIME_CLASS_TARGET:-bionic-native}" == "bionic-native" ]] || return 0
  : "${WCP_BIONIC_DONOR_PREFLIGHT:=0}"
  : "${WCP_BIONIC_DONOR_PREFLIGHT_DONE:=0}"
  if [[ "${WCP_BIONIC_DONOR_PREFLIGHT}" != "1" ]]; then
    return 0
  fi
  if [[ "${WCP_BIONIC_DONOR_PREFLIGHT_DONE}" == "1" ]]; then
    return 0
  fi
  if winlator_bionic_mainline_strict; then
    strict_mode=1
  fi

  winlator_apply_bionic_source_map_overrides

  launcher_wcp="${WCP_BIONIC_LAUNCHER_SOURCE_WCP_PATH:-}"
  launcher_url="${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:-}"
  launcher_sha="${WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256:-}"
  launcher_cache="${WCP_BIONIC_LAUNCHER_CACHE_DIR:-${CACHE_DIR:-/tmp}/wcp-bionic-launcher-cache}/launcher-source.wcp"
  if [[ -z "${launcher_wcp}" && -n "${launcher_url}" ]]; then
    winlator_download_cached_archive "${launcher_url}" "${launcher_cache}" "${launcher_sha}" "bionic launcher source WCP"
    launcher_wcp="${launcher_cache}"
  fi
  if [[ -z "${launcher_wcp}" ]]; then
    if [[ "${strict_mode}" == "1" ]]; then
      fail "Bionic launcher source WCP preflight is enabled but source is unresolved (WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL/PATH)"
    fi
    return 0
  fi
  [[ -f "${launcher_wcp}" ]] || fail "Bionic launcher source WCP not found: ${launcher_wcp}"
  winlator_verify_sha256 "${launcher_wcp}" "${launcher_sha}" "bionic launcher source WCP"
  winlator_verify_bionic_launcher_source_archive "${launcher_wcp}" "bionic launcher source WCP"
  launcher_actual_sha="$(winlator_sha256_file "${launcher_wcp}")"
  WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH="${launcher_wcp}"
  WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256="${launcher_actual_sha}"
  export WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256

  unix_wcp="${WCP_BIONIC_UNIX_SOURCE_WCP_PATH:-}"
  unix_url="${WCP_BIONIC_UNIX_SOURCE_WCP_URL:-${launcher_url}}"
  unix_sha="${WCP_BIONIC_UNIX_SOURCE_WCP_SHA256:-}"
  unix_cache="${WCP_BIONIC_UNIX_SOURCE_WCP_CACHE_DIR:-${CACHE_DIR:-/tmp}/wcp-bionic-unix-cache}/unix-source.wcp"
  if [[ -z "${unix_wcp}" && -n "${unix_url}" ]]; then
    winlator_download_cached_archive "${unix_url}" "${unix_cache}" "${unix_sha}" "bionic unix source WCP"
    unix_wcp="${unix_cache}"
  fi
  if [[ -z "${unix_wcp}" ]]; then
    if [[ "${strict_mode}" == "1" ]]; then
      fail "Bionic unix source WCP preflight is enabled but source is unresolved (WCP_BIONIC_UNIX_SOURCE_WCP_URL/PATH)"
    fi
    return 0
  fi
  [[ -f "${unix_wcp}" ]] || fail "Bionic unix source WCP not found: ${unix_wcp}"
  winlator_verify_sha256 "${unix_wcp}" "${unix_sha}" "bionic unix source WCP"
  winlator_verify_bionic_unix_source_archive "${unix_wcp}" "bionic unix source WCP"
  unix_actual_sha="$(winlator_sha256_file "${unix_wcp}")"
  WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH="${unix_wcp}"
  WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256="${unix_actual_sha}"
  export WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256
  WCP_BIONIC_DONOR_PREFLIGHT_DONE="1"
  export WCP_BIONIC_DONOR_PREFLIGHT_DONE
}

winlator_extract_wcp_archive() {
  local archive="$1" out_dir="$2"
  [[ -f "${archive}" ]] || return 1
  mkdir -p "${out_dir}"
  if tar -xJf "${archive}" -C "${out_dir}" >/dev/null 2>&1; then
    return 0
  fi
  if tar --zstd -xf "${archive}" -C "${out_dir}" >/dev/null 2>&1; then
    return 0
  fi
  tar -xf "${archive}" -C "${out_dir}" >/dev/null 2>&1
}

winlator_apply_bionic_source_map_overrides() {
  local map_file pkg_name out line key value
  local root_dir="${ROOT_DIR:-}"

  : "${WCP_BIONIC_SOURCE_MAP_FILE:=}"
  : "${WCP_BIONIC_SOURCE_MAP_FORCE:=0}"
  : "${WCP_BIONIC_SOURCE_MAP_REQUIRED:=0}"
  : "${WCP_BIONIC_SOURCE_MAP_RESOLVED:=0}"
  if [[ "${WCP_BIONIC_SOURCE_MAP_RESOLVED}" == "1" ]]; then
    return 0
  fi
  pkg_name="${WCP_NAME:-}"
  [[ -n "${pkg_name}" ]] || return 0

  map_file="${WCP_BIONIC_SOURCE_MAP_FILE}"
  if [[ -z "${map_file}" && -n "${root_dir}" ]]; then
    map_file="${root_dir}/ci/runtime-sources/bionic-source-map.json"
  fi

  if [[ -z "${map_file}" || ! -f "${map_file}" ]]; then
    if [[ "${WCP_BIONIC_SOURCE_MAP_REQUIRED}" == "1" ]]; then
      fail "Bionic source-map is required but missing: ${map_file:-<unset>}"
    fi
    return 0
  fi
  WCP_BIONIC_SOURCE_MAP_FILE="${map_file}"
  WCP_BIONIC_SOURCE_MAP_PATH_EFFECTIVE="${map_file}"
  WCP_BIONIC_SOURCE_MAP_SHA256="$(winlator_sha256_file "${map_file}")"
  export WCP_BIONIC_SOURCE_MAP_FILE WCP_BIONIC_SOURCE_MAP_PATH_EFFECTIVE WCP_BIONIC_SOURCE_MAP_SHA256

  command -v python3 >/dev/null 2>&1 || fail "python3 is required to read bionic source-map"
  out="$(python3 - "${map_file}" "${pkg_name}" "${WCP_BIONIC_SOURCE_MAP_FORCE}" "${WCP_BIONIC_SOURCE_MAP_REQUIRED}" <<'PY'
import json
import sys
from pathlib import Path

map_file = Path(sys.argv[1])
pkg_name = sys.argv[2]
force = sys.argv[3] == "1"
required = sys.argv[4] == "1"

with map_file.open("r", encoding="utf-8") as f:
    data = json.load(f)

packages = data.get("packages") or {}
entry = packages.get(pkg_name)
if entry is None:
    if required:
        print("ERROR=missing-package-entry")
    sys.exit(0)

def emit(var: str, key: str):
    value = entry.get(key)
    if value is None:
        return
    if isinstance(value, list):
        out = " ".join(str(v) for v in value)
    else:
        out = str(value)
    print(f"{var}={out}")

emit("WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL", "launcherSourceWcpUrl")
emit("WCP_BIONIC_UNIX_SOURCE_WCP_URL", "unixSourceWcpUrl")
emit("WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256", "launcherSourceSha256")
emit("WCP_BIONIC_UNIX_SOURCE_WCP_SHA256", "unixSourceSha256")
emit("WCP_BIONIC_UNIX_CORE_ADOPT", "unixCoreAdopt")
emit("WCP_BIONIC_UNIX_CORE_MODULES", "unixCoreModules")
if force:
    print("WCP_BIONIC_SOURCE_MAP_APPLIED=1")
else:
    print("WCP_BIONIC_SOURCE_MAP_APPLIED=0")
PY
)"

  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    key="${line%%=*}"
    value="${line#*=}"
    if [[ "${key}" == "ERROR" ]]; then
      fail "Bionic source-map entry for ${pkg_name} is required but missing in ${map_file}"
    fi
    case "${key}" in
      WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL|WCP_BIONIC_UNIX_SOURCE_WCP_URL|WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256|WCP_BIONIC_UNIX_SOURCE_WCP_SHA256)
        # In mainline, source-map should provide donor URLs/SHA by default while still
        # allowing explicit workflow/env overrides when FORCE=0.
        if [[ "${WCP_BIONIC_SOURCE_MAP_FORCE}" == "1" || -z "${!key:-}" ]]; then
          printf -v "${key}" '%s' "${value}"
          export "${key}"
        fi
        ;;
      WCP_BIONIC_UNIX_CORE_ADOPT|WCP_BIONIC_UNIX_CORE_MODULES|WCP_BIONIC_SOURCE_MAP_APPLIED)
        if [[ "${WCP_BIONIC_SOURCE_MAP_FORCE}" == "1" || -z "${!key:-}" ]]; then
          printf -v "${key}" '%s' "${value}"
          export "${key}"
        fi
        ;;
    esac
  done <<< "${out}"

  if [[ "${WCP_BIONIC_SOURCE_MAP_APPLIED:-0}" == "1" ]]; then
    log "Applied bionic source-map overrides for ${pkg_name}"
  fi
  WCP_BIONIC_SOURCE_MAP_RESOLVED="1"
  export WCP_BIONIC_SOURCE_MAP_RESOLVED
}

winlator_adopt_bionic_unix_core_modules() {
  local wcp_root="${1:-${WCP_ROOT:-}}"
  local target="${WCP_RUNTIME_CLASS_TARGET:-bionic-native}"
  local unix_abi source_wcp source_url source_sha cache_dir archive_path
  local tmp_extract src_unix dst_unix mod source_unix_abi src_mod_abi
  local copied_count=0
  local -a core_modules
  local -a glibc_modules replaced_glibc

  [[ "${WCP_TARGET_RUNTIME:-winlator-bionic}" == "winlator-bionic" ]] || return 0
  [[ "${target}" == "bionic-native" ]] || return 0
  [[ -n "${wcp_root}" ]] || return 0
  winlator_apply_bionic_source_map_overrides
  # Cross-version unix core replacement can create hard ABI drift with the package's
  # own aarch64-windows DLL set (observed as early wineboot crashes). Keep disabled
  # by default; enable only for controlled experiments with matching source payloads.
  : "${WCP_BIONIC_UNIX_CORE_ADOPT:=0}"
  unix_abi="$(winlator_detect_unix_module_abi "${wcp_root}")"
  [[ "${unix_abi}" == "glibc-unix" ]] || return 0
  if [[ "${WCP_BIONIC_UNIX_CORE_ADOPT}" != "1" ]]; then
    if winlator_bionic_mainline_strict; then
      log "Auto-enabling bionic unix core adoption: enforced bionic-native target cannot ship glibc-unix ntdll"
      WCP_BIONIC_UNIX_CORE_ADOPT="1"
      export WCP_BIONIC_UNIX_CORE_ADOPT
    else
      return 0
    fi
  fi

  source_wcp="${WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH:-${WCP_BIONIC_UNIX_SOURCE_WCP_PATH:-}}"
  source_url="${WCP_BIONIC_UNIX_SOURCE_WCP_URL:-${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:-}}"
  source_sha="${WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256:-${WCP_BIONIC_UNIX_SOURCE_WCP_SHA256:-}}"
  cache_dir="${WCP_BIONIC_UNIX_SOURCE_WCP_CACHE_DIR:-${CACHE_DIR:-/tmp}/wcp-bionic-unix-cache}"

  if [[ -z "${source_wcp}" && -n "${source_url}" ]]; then
    archive_path="${cache_dir}/unix-source.wcp"
    winlator_download_cached_archive "${source_url}" "${archive_path}" "${source_sha}" "bionic unix source WCP"
    source_wcp="${archive_path}"
  fi

  if [[ -z "${source_wcp}" ]]; then
    if winlator_bionic_mainline_strict; then
      fail "Bionic unix source WCP is required in strict mainline mode but not configured (WCP_BIONIC_UNIX_SOURCE_WCP_URL/PATH)"
    fi
    log "Bionic unix source WCP is not configured (WCP_BIONIC_UNIX_SOURCE_WCP_URL/PATH)"
    return 0
  fi
  [[ -f "${source_wcp}" ]] || fail "Bionic unix source WCP not found: ${source_wcp}"
  winlator_verify_sha256 "${source_wcp}" "${source_sha}" "bionic unix source WCP"
  WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH="${source_wcp}"
  WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256="$(winlator_sha256_file "${source_wcp}")"
  export WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256

  tmp_extract="$(mktemp -d)"
  if ! winlator_extract_wcp_archive "${source_wcp}" "${tmp_extract}"; then
    rm -rf "${tmp_extract}"
    fail "Unable to extract bionic unix source WCP: ${source_wcp}"
  fi

  src_unix="$(find "${tmp_extract}" -type d -path '*/lib/wine/aarch64-unix' | head -n1 || true)"
  [[ -n "${src_unix}" ]] || { rm -rf "${tmp_extract}"; fail "Bionic unix source WCP is missing lib/wine/aarch64-unix"; }
  dst_unix="${wcp_root}/lib/wine/aarch64-unix"
  [[ -d "${dst_unix}" ]] || { rm -rf "${tmp_extract}"; fail "Target WCP is missing lib/wine/aarch64-unix"; }
  source_unix_abi="$(winlator_detect_unix_module_abi_from_path "${src_unix}/ntdll.so")"
  if [[ "${source_unix_abi}" != "bionic-unix" ]]; then
    rm -rf "${tmp_extract}"
    if winlator_bionic_mainline_strict; then
      fail "Bionic unix source WCP has non-bionic unix ABI (detected=${source_unix_abi}, source=${source_wcp})"
    fi
    log "Skipping unix core adoption due to non-bionic donor unix ABI (detected=${source_unix_abi})"
    return 0
  fi

  # Keep module surface minimal to reduce cross-version drift while fixing ABI.
  # Caller can override with a space-separated list via WCP_BIONIC_UNIX_CORE_MODULES.
  core_modules=(
    "ntdll.so"
    "win32u.so"
    "ws2_32.so"
    "winevulkan.so"
    "winebus.so"
    "winebus.sys.so"
  )
  if [[ -n "${WCP_BIONIC_UNIX_CORE_MODULES:-}" ]]; then
    # shellcheck disable=SC2206
    core_modules=( ${WCP_BIONIC_UNIX_CORE_MODULES} )
  fi

  for mod in "${core_modules[@]}"; do
    [[ -f "${src_unix}/${mod}" ]] || continue
    cp -f "${src_unix}/${mod}" "${dst_unix}/${mod}"
    chmod +x "${dst_unix}/${mod}" || true
    copied_count=$((copied_count + 1))
  done

  if [[ "${copied_count}" -eq 0 ]]; then
    rm -rf "${tmp_extract}"
    if winlator_bionic_mainline_strict; then
      fail "Bionic unix core adoption copied zero modules (source=${source_wcp}, modules=${WCP_BIONIC_UNIX_CORE_MODULES:-default})"
    fi
    log "Skipping unix core adoption: no requested modules found in donor WCP"
    return 0
  fi

  if winlator_bionic_mainline_strict; then
    mapfile -t glibc_modules < <(winlator_list_glibc_unix_modules "${dst_unix}")
    for mod in "${glibc_modules[@]}"; do
      [[ -f "${src_unix}/${mod}" ]] || continue
      src_mod_abi="$(winlator_detect_unix_module_abi_from_path "${src_unix}/${mod}")"
      [[ "${src_mod_abi}" == "bionic-unix" ]] || continue
      cp -f "${src_unix}/${mod}" "${dst_unix}/${mod}"
      chmod +x "${dst_unix}/${mod}" || true
      replaced_glibc+=("${mod}")
    done
    if [[ "${#replaced_glibc[@]}" -gt 0 ]]; then
      log "Replaced additional glibc unix modules from donor: ${replaced_glibc[*]}"
    fi
    mapfile -t glibc_modules < <(winlator_list_glibc_unix_modules "${dst_unix}")
    if [[ "${#glibc_modules[@]}" -gt 0 ]]; then
      fail "Strict bionic mainline found remaining glibc unix modules after adoption: ${glibc_modules[*]}"
    fi
  fi

  rm -rf "${tmp_extract}"

  unix_abi="$(winlator_detect_unix_module_abi "${wcp_root}")"
  if [[ "${unix_abi}" != "bionic-unix" ]]; then
    if winlator_bionic_mainline_strict; then
      fail "Bionic unix core adoption failed in strict mainline mode (detected=${unix_abi}, source=${source_wcp}, modules=${WCP_BIONIC_UNIX_CORE_MODULES:-default})"
    fi
    log "Bionic unix core adoption did not fully switch ABI (detected=${unix_abi})"
    return 0
  fi
  log "Adopted bionic unix core modules from source WCP"
}

winlator_adopt_bionic_launchers() {
  local wcp_root="${1:-${WCP_ROOT:-}}"
  local target="${WCP_RUNTIME_CLASS_TARGET:-bionic-native}"
  local wine_bin wineserver_bin
  local source_wcp source_url source_sha cache_dir archive_path
  local tmp_extract src_wine src_wineserver src_preloader
  local detected unix_abi

  [[ "${WCP_TARGET_RUNTIME:-winlator-bionic}" == "winlator-bionic" ]] || return 0
  [[ "${target}" == "bionic-native" ]] || return 0
  [[ -n "${wcp_root}" ]] || return 0
  winlator_apply_bionic_source_map_overrides

  wine_bin="${wcp_root}/bin/wine"
  wineserver_bin="${wcp_root}/bin/wineserver"
  [[ -f "${wine_bin}" ]] || return 0
  [[ -f "${wineserver_bin}" ]] || return 0
  winlator_is_glibc_launcher "${wine_bin}" || return 0

  unix_abi="$(winlator_detect_unix_module_abi "${wcp_root}")"
  if [[ "${unix_abi}" == "glibc-unix" ]]; then
    if winlator_bionic_mainline_strict; then
      fail "Cannot adopt bionic launchers while unix ABI is glibc-unix in strict mainline mode (source map / donor WCP mismatch)"
    fi
    log "Skipping bionic launcher adoption: unix runtime is glibc-linked (ntdll needs libc.so.6)"
    return 0
  fi

  source_wcp="${WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH:-${WCP_BIONIC_LAUNCHER_SOURCE_WCP_PATH:-}}"
  source_url="${WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:-}"
  source_sha="${WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256:-${WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256:-}}"
  cache_dir="${WCP_BIONIC_LAUNCHER_CACHE_DIR:-${CACHE_DIR:-/tmp}/wcp-bionic-launcher-cache}"

  if [[ -z "${source_wcp}" && -n "${source_url}" ]]; then
    archive_path="${cache_dir}/launcher-source.wcp"
    winlator_download_cached_archive "${source_url}" "${archive_path}" "${source_sha}" "bionic launcher source WCP"
    source_wcp="${archive_path}"
  fi

  if [[ -z "${source_wcp}" ]]; then
    if winlator_bionic_mainline_strict; then
      fail "Bionic launcher source WCP is required in strict mainline mode but not configured (WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL/PATH)"
    fi
    log "Bionic launcher source WCP is not configured (WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL/PATH)"
    winlator_report_runtime_class_mismatch "glibc-raw"
    return 0
  fi
  [[ -f "${source_wcp}" ]] || fail "Bionic launcher source WCP not found: ${source_wcp}"
  winlator_verify_sha256 "${source_wcp}" "${source_sha}" "bionic launcher source WCP"
  WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH="${source_wcp}"
  WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256="$(winlator_sha256_file "${source_wcp}")"
  export WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256

  tmp_extract="$(mktemp -d)"
  if ! winlator_extract_wcp_archive "${source_wcp}" "${tmp_extract}"; then
    rm -rf "${tmp_extract}"
    fail "Unable to extract bionic launcher source WCP: ${source_wcp}"
  fi

  src_wine="$(find "${tmp_extract}" -type f -path '*/bin/wine' | head -n1 || true)"
  src_wineserver="$(find "${tmp_extract}" -type f -path '*/bin/wineserver' | head -n1 || true)"
  src_preloader="$(find "${tmp_extract}" -type f -path '*/bin/wine-preloader' | head -n1 || true)"

  [[ -n "${src_wine}" ]] || { rm -rf "${tmp_extract}"; fail "Bionic launcher source WCP is missing bin/wine"; }
  [[ -n "${src_wineserver}" ]] || { rm -rf "${tmp_extract}"; fail "Bionic launcher source WCP is missing bin/wineserver"; }

  winlator_is_bionic_launcher "${src_wine}" || { rm -rf "${tmp_extract}"; fail "Source bin/wine is not bionic-native (/system/bin/linker64)"; }
  winlator_is_bionic_launcher "${src_wineserver}" || { rm -rf "${tmp_extract}"; fail "Source bin/wineserver is not bionic-native (/system/bin/linker64)"; }

  cp -f "${src_wine}" "${wine_bin}"
  cp -f "${src_wineserver}" "${wineserver_bin}"
  chmod +x "${wine_bin}" "${wineserver_bin}"
  if [[ -n "${src_preloader}" ]]; then
    cp -f "${src_preloader}" "${wcp_root}/bin/wine-preloader"
    chmod +x "${wcp_root}/bin/wine-preloader"
  fi
  [[ -e "${wcp_root}/bin/wine64" ]] || ln -sfn wine "${wcp_root}/bin/wine64"

  rm -rf "${tmp_extract}"

  detected="$(winlator_detect_runtime_class "${wcp_root}")"
  if [[ "${detected}" != "bionic-native" ]]; then
    fail "Bionic launcher adoption failed: detected runtime class is ${detected}"
  fi
  log "Adopted bionic-native Wine launchers from source WCP"
}

winlator_ensure_arm64ec_unix_loader_compat_links() {
  local wcp_root="${1:-${WCP_ROOT:-}}"
  local unix_dir compat_dir dst mod
  local -a compat_modules

  [[ -n "${wcp_root}" ]] || return 0
  unix_dir="${wcp_root}/lib/wine/aarch64-unix"
  compat_dir="${wcp_root}/lib/wine"
  [[ -d "${unix_dir}" && -d "${compat_dir}" ]] || return 0

  compat_modules=(
    "ntdll.so"
    "win32u.so"
    "ws2_32.so"
    "winevulkan.so"
    "winebus.so"
    "winebus.sys.so"
  )

  for mod in "${compat_modules[@]}"; do
    [[ -f "${unix_dir}/${mod}" ]] || continue
    dst="${compat_dir}/${mod}"
    if [[ -e "${dst}" && ! -L "${dst}" ]]; then
      # Keep explicit files from upstream layouts; add links only for missing targets.
      continue
    fi
    ln -sfn "aarch64-unix/${mod}" "${dst}"
  done
}

winlator_resolve_host_lib() {
  local soname="$1" dir
  for dir in \
    /lib/aarch64-linux-gnu \
    /usr/lib/aarch64-linux-gnu \
    /lib \
    /usr/lib; do
    if [[ -e "${dir}/${soname}" ]]; then
      readlink -f "${dir}/${soname}"
      return 0
    fi
  done
  return 1
}

winlator_collect_needed_sonames() {
  local elf_path="$1"
  readelf -d "${elf_path}" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\].*/\1/p'
}

winlator_copy_glibc_runtime_tree() {
  local src_dir="$1" runtime_dir="$2"
  local loader_target

  [[ -d "${src_dir}" ]] || fail "Pinned glibc runtime dir not found: ${src_dir}"
  mkdir -p "${runtime_dir}"

  # Copy contents as a runtime tree snapshot (files + symlinks), preserving layout.
  cp -a "${src_dir}/." "${runtime_dir}/"

  [[ -e "${runtime_dir}/ld-linux-aarch64.so.1" ]] || fail "Pinned glibc runtime is missing ld-linux-aarch64.so.1"
  loader_target="$(readlink -f "${runtime_dir}/ld-linux-aarch64.so.1" 2>/dev/null || true)"
  [[ -n "${loader_target}" && -e "${loader_target}" ]] || fail "Pinned glibc runtime loader symlink is broken: ${runtime_dir}/ld-linux-aarch64.so.1"
}

winlator_extract_glibc_runtime_archive() {
  local archive="$1" out_dir="$2"
  local runtime_subdir="${3:-}"
  local tmp_extract

  [[ -f "${archive}" ]] || fail "Pinned glibc runtime archive not found: ${archive}"
  command -v tar >/dev/null 2>&1 || fail "tar is required to unpack pinned glibc runtime archive"

  tmp_extract="$(mktemp -d)"
  tar -xf "${archive}" -C "${tmp_extract}"

  if [[ -n "${runtime_subdir}" ]]; then
    [[ -d "${tmp_extract}/${runtime_subdir}" ]] || fail "Pinned glibc archive missing runtime subdir: ${runtime_subdir}"
    winlator_copy_glibc_runtime_tree "${tmp_extract}/${runtime_subdir}" "${out_dir}"
  elif [[ -d "${tmp_extract}/wcp-glibc-runtime" ]]; then
    winlator_copy_glibc_runtime_tree "${tmp_extract}/wcp-glibc-runtime" "${out_dir}"
  else
    # Fallback: archive root already contains ld-linux + libs.
    winlator_copy_glibc_runtime_tree "${tmp_extract}" "${out_dir}"
  fi

  rm -rf "${tmp_extract}"
}

winlator_apply_glibc_runtime_patchset() {
  local runtime_dir="$1"
  local overlay_dir="${WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR:-}"
  local patch_script="${WCP_GLIBC_RUNTIME_PATCH_SCRIPT:-}"
  local patchset_id="${WCP_GLIBC_PATCHSET_ID:-}"

  [[ -d "${runtime_dir}" ]] || fail "glibc runtime dir not found for patchset apply: ${runtime_dir}"

  if [[ -n "${overlay_dir}" ]]; then
    [[ -d "${overlay_dir}" ]] || fail "WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR not found: ${overlay_dir}"
    cp -a "${overlay_dir}/." "${runtime_dir}/"
    log "Applied glibc runtime overlay patchset (${patchset_id:-overlay-only}) from ${overlay_dir}"
  fi

  if [[ -n "${patch_script}" ]]; then
    [[ -x "${patch_script}" ]] || fail "WCP_GLIBC_RUNTIME_PATCH_SCRIPT is not executable: ${patch_script}"
    "${patch_script}" "${runtime_dir}"
    log "Applied glibc runtime patch script (${patchset_id:-script-only}) via ${patch_script}"
  fi

  [[ -e "${runtime_dir}/ld-linux-aarch64.so.1" ]] || fail "glibc runtime patchset removed loader symlink"
  local loader_target
  loader_target="$(readlink -f "${runtime_dir}/ld-linux-aarch64.so.1" 2>/dev/null || true)"
  [[ -n "${loader_target}" && -e "${loader_target}" ]] || fail "glibc runtime patchset left broken loader symlink"
}

winlator_bundle_glibc_runtime_from_pinned_source() {
  local runtime_dir="$1"
  local source_dir="${WCP_GLIBC_RUNTIME_DIR:-}"
  local source_archive="${WCP_GLIBC_RUNTIME_ARCHIVE:-}"
  local archive_subdir="${WCP_GLIBC_RUNTIME_SUBDIR:-}"
  local build_script="${ROOT_DIR:-}/ci/runtime-bundle/build-glibc-runtime-from-source.sh"
  local cache_root="${WCP_GLIBC_BUILD_CACHE_DIR:-${CACHE_DIR:-/tmp}/wcp-glibc-runtime-cache}"
  local cached_runtime_dir="${cache_root}/runtime-${WCP_GLIBC_VERSION:-unknown}-${WCP_GLIBC_TARGET_VERSION:-target}"
  local -a build_args=()

  case "${WCP_GLIBC_SOURCE_MODE:-host}" in
    pinned-source|pinned|prebuilt) ;;
    *) fail "winlator_bundle_glibc_runtime_from_pinned_source called with unsupported WCP_GLIBC_SOURCE_MODE=${WCP_GLIBC_SOURCE_MODE:-}" ;;
  esac

  if [[ -n "${source_dir}" ]]; then
    winlator_copy_glibc_runtime_tree "${source_dir}" "${runtime_dir}"
    return 0
  fi

  if [[ -n "${source_archive}" ]]; then
    winlator_extract_glibc_runtime_archive "${source_archive}" "${runtime_dir}" "${archive_subdir}"
    return 0
  fi

  if [[ -x "${build_script}" && -n "${WCP_GLIBC_SOURCE_URL:-}" ]]; then
    mkdir -p "${cache_root}"
    if [[ ! -f "${cached_runtime_dir}/ld-linux-aarch64.so.1" ]]; then
      build_args=(
        --out-dir "${cached_runtime_dir}"
        --src-url "${WCP_GLIBC_SOURCE_URL}"
        --version "${WCP_GLIBC_VERSION:-${WCP_GLIBC_TARGET_VERSION:-unknown}}"
        --cache-dir "${cache_root}"
        --enable-kernel "${WCP_GLIBC_ENABLE_KERNEL:-4.14}"
        --jobs "${WCP_GLIBC_BUILD_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
      )
      if [[ -n "${WCP_GLIBC_SOURCE_SHA256:-}" ]]; then
        build_args+=(--src-sha256 "${WCP_GLIBC_SOURCE_SHA256}")
      fi
      "${build_script}" "${build_args[@]}"
    fi
    winlator_copy_glibc_runtime_tree "${cached_runtime_dir}" "${runtime_dir}"
    return 0
  fi

  fail "Pinned glibc mode requires WCP_GLIBC_RUNTIME_DIR or WCP_GLIBC_RUNTIME_ARCHIVE"
}

winlator_bundle_glibc_runtime() {
  local runtime_dir="$1"
  local -a seed_sonames=()
  local extra_sonames
  local -a elf_roots=()
  local root f dep host_path real_name loader_name
  local -a queue=()
  declare -A seen=()
  local glibc_mode="${WCP_GLIBC_SOURCE_MODE:-host}"

  if [[ "${glibc_mode}" != "host" ]]; then
    winlator_bundle_glibc_runtime_from_pinned_source "${runtime_dir}"
    winlator_apply_glibc_runtime_patchset "${runtime_dir}"
    log "Winlator glibc runtime bundled from pinned source mode (${glibc_mode})"
    return 0
  fi

  elf_roots=(
    "${WCP_ROOT}/bin"
    "${WCP_ROOT}/lib/wine/aarch64-unix"
  )

  mkdir -p "${runtime_dir}"

  # Seed list from all packaged ELF binaries/modules plus core glibc sonames.
  for root in "${elf_roots[@]}"; do
    [[ -d "${root}" ]] || continue
    while IFS= read -r -d '' f; do
      if file -b "${f}" | grep -q '^ELF '; then
        while IFS= read -r dep; do
          [[ -n "${dep}" ]] && seed_sonames+=("${dep}")
        done < <(winlator_collect_needed_sonames "${f}")
      fi
    done < <(find "${root}" -type f -print0)
  done

  seed_sonames+=(
    "libc.so.6"
    "libdl.so.2"
    "libm.so.6"
    "libpthread.so.0"
    "librt.so.1"
    "libgcc_s.so.1"
    "libstdc++.so.6"
    "libz.so.1"
  )

  # Runtime-only symbols frequently requested via dlopen() on glibc builds.
  : "${WCP_BIONIC_EXTRA_GLIBC_LIBS:=libnss_files.so.2 libnss_dns.so.2 libresolv.so.2 libutil.so.1 libnsl.so.1 libSDL2-2.0.so.0 libSDL2-2.0.so}"
  extra_sonames="$(printf '%s' "${WCP_BIONIC_EXTRA_GLIBC_LIBS}" | tr ',' ' ')"
  for dep in ${extra_sonames}; do
    seed_sonames+=("${dep}")
  done

  # Copy ELF interpreter used by glibc Wine launchers.
  host_path="$(winlator_resolve_host_lib ld-linux-aarch64.so.1 || true)"
  if [[ -z "${host_path}" ]]; then
    fail "Unable to resolve host ld-linux-aarch64.so.1 required for glibc launcher wrapping"
  fi
  loader_name="$(basename "${host_path}")"
  cp -a "${host_path}" "${runtime_dir}/${loader_name}"
  if [[ "${loader_name}" != "ld-linux-aarch64.so.1" ]]; then
    ln -sfn "${loader_name}" "${runtime_dir}/ld-linux-aarch64.so.1"
  fi

  # Breadth-first copy of transitive shared-library dependencies.
  queue=("${seed_sonames[@]}")
  while ((${#queue[@]})); do
    dep="${queue[0]}"
    queue=("${queue[@]:1}")
    [[ -n "${dep}" ]] || continue
    [[ -n "${seen["${dep}"]:-}" ]] && continue
    seen["${dep}"]=1

    # Package-provided Wine unix modules are resolved via wrapper library path.
    if [[ -e "${WCP_ROOT}/lib/wine/aarch64-unix/${dep}" || -e "${WCP_ROOT}/lib/${dep}" ]]; then
      continue
    fi

    host_path="$(winlator_resolve_host_lib "${dep}" || true)"
    if [[ -z "${host_path}" ]]; then
      log "winlator runtime: unresolved host soname ${dep}, keeping external resolution"
      continue
    fi

    real_name="$(basename "${host_path}")"
    cp -an "${host_path}" "${runtime_dir}/${real_name}" || true
    if [[ "${real_name}" != "${dep}" ]]; then
      ln -sfn "${real_name}" "${runtime_dir}/${dep}"
    fi

    while IFS= read -r dep; do
      [[ -n "${dep}" ]] && queue+=("${dep}")
    done < <(winlator_collect_needed_sonames "${host_path}")
  done

  winlator_apply_glibc_runtime_patchset "${runtime_dir}"
}

winlator_write_glibc_wrapper() {
  local launcher_path="$1" real_name="$2" export_wineserver="$3"

  cat > "${launcher_path}" <<EOF_WRAPPER
#!/system/bin/sh
set -eu

self="\$0"
# Some Android launch paths arrive with nested quotes (e.g. ""/path/bin/wine").
while :; do
  case "\${self}" in
    \\"*) self="\${self#\\"}"; continue ;;
    \\'*) self="\${self#\\'}"; continue ;;
    \\\\\\"*) self="\${self#\\\\\\"}"; continue ;;
    *) ;;
  esac
  break
done
while :; do
  case "\${self}" in
    *\\\\\\") self="\${self%\\\\\\"}"; continue ;;
    *\\") self="\${self%\\"}"; continue ;;
    *\\') self="\${self%\\'}"; continue ;;
    *) ;;
  esac
  break
done
bindir="\$(CDPATH= cd -- "\$(dirname -- "\${self}")" 2>/dev/null && pwd)" || {
  echo "Cannot resolve launcher directory from argv0: \$0" >&2
  exit 127
}
root="\$(CDPATH= cd -- "\${bindir}/.." && pwd)"
runtime="\${root}/lib/wine/wcp-glibc-runtime"
loader="\${runtime}/ld-linux-aarch64.so.1"
real="\${bindir}/${real_name}"
libpath="\${runtime}:\${runtime}/deps:\${root}/lib:\${root}/lib64:\${root}/lib/aarch64-linux-gnu:\${root}/lib/wine:\${root}/lib/wine/aarch64-unix:\${root}/lib/wine/x86_64-unix:\${root}/usr/lib:\${root}/usr/lib64:\${root}/usr/lib/aarch64-linux-gnu"
winedllpath="\${root}/lib/wine/aarch64-windows:\${root}/lib/wine/i386-windows:\${root}/lib/wine/x86_64-windows:\${root}/lib/wine/aarch64-unix:\${root}/lib/wine/x86_64-unix"
export PATH="\${bindir}:\${root}/bin:\${PATH}"
export WINEDLLPATH="\${winedllpath}\${WINEDLLPATH:+:\${WINEDLLPATH}}"
export LD_LIBRARY_PATH="\${libpath}\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
# Winlator injects Android sysvshm as a bionic LD_PRELOAD. This breaks glibc-wrapped Wine/Hangover
# launchers (missing libdl.so/ld-android.so or early traps), so glibc wrappers must clear it.
unset LD_PRELOAD
# Android app seccomp often blocks glibc rseq and causes SIGSYS (signal 31) very early.
case ":\${GLIBC_TUNABLES:-}:" in
  *:glibc.pthread.rseq=*:) ;;
  *) export GLIBC_TUNABLES="\${GLIBC_TUNABLES:+\${GLIBC_TUNABLES}:}glibc.pthread.rseq=0" ;;
esac

[ -x "\${loader}" ] || { echo "Missing runtime loader: \${loader}" >&2; exit 127; }
[ -x "\${real}" ] || { echo "Missing launcher payload: \${real}" >&2; exit 127; }
EOF_WRAPPER

  if [[ "${export_wineserver}" == "1" ]]; then
    cat >> "${launcher_path}" <<'EOF_WRAPPER'
export WINESERVER="${bindir}/wineserver"
EOF_WRAPPER
  fi

  cat >> "${launcher_path}" <<'EOF_WRAPPER'
exec "${loader}" --library-path "${LD_LIBRARY_PATH}" "${real}" "$@"
EOF_WRAPPER

  chmod +x "${launcher_path}"
}

winlator_wrap_glibc_launchers() {
  local wine_bin wineserver_bin runtime_dir
  local wine_real wineserver_real
  local target_class
  local detected_before

  [[ "${WCP_TARGET_RUNTIME}" == "winlator-bionic" ]] || return

  wine_bin="${WCP_ROOT}/bin/wine"
  wineserver_bin="${WCP_ROOT}/bin/wineserver"
  [[ -f "${wine_bin}" ]] || return
  [[ -f "${wineserver_bin}" ]] || return

  detected_before="$(winlator_detect_runtime_class "${WCP_ROOT}")"
  target_class="${WCP_RUNTIME_CLASS_TARGET:-bionic-native}"
  : "${WCP_ALLOW_GLIBC_EXPERIMENTAL:=0}"

  if [[ "${target_class}" != "glibc-wrapped" ]]; then
    if winlator_is_glibc_launcher "${wine_bin}"; then
      winlator_report_runtime_class_mismatch "glibc-raw"
    fi
    return
  fi

  if [[ "${WCP_ALLOW_GLIBC_EXPERIMENTAL}" != "1" ]]; then
    fail "glibc-wrapped runtime is disabled in mainline (set WCP_ALLOW_GLIBC_EXPERIMENTAL=1 only in experimental builds)"
  fi
  if ! winlator_is_glibc_launcher "${wine_bin}"; then
    if [[ "${detected_before}" != "glibc-wrapped" ]]; then
      winlator_report_runtime_class_mismatch "${detected_before}"
    fi
    return
  fi

  runtime_dir="${WCP_ROOT}/lib/wine/wcp-glibc-runtime"
  winlator_bundle_glibc_runtime "${runtime_dir}"

  wine_real="wine.glibc-real"
  wineserver_real="wineserver.glibc-real"
  mv -f "${wine_bin}" "${WCP_ROOT}/bin/${wine_real}"
  mv -f "${wineserver_bin}" "${WCP_ROOT}/bin/${wineserver_real}"

  winlator_write_glibc_wrapper "${wine_bin}" "${wine_real}" "1"
  winlator_write_glibc_wrapper "${wineserver_bin}" "${wineserver_real}" "0"
  log "Winlator bionic wrapper enabled for glibc Wine launchers"
}

winlator_validate_runtime_class_target() {
  local detected target
  [[ "${WCP_TARGET_RUNTIME}" == "winlator-bionic" ]] || return 0
  target="${WCP_RUNTIME_CLASS_TARGET:-bionic-native}"
  : "${WCP_ALLOW_GLIBC_EXPERIMENTAL:=0}"
  detected="$(winlator_detect_runtime_class "${WCP_ROOT}")"
  case "${target}" in
    bionic-native)
      if [[ "${detected}" == "glibc-wrapped" || "${detected}" == "glibc-raw" || "${detected}" == "bionic-launcher-glibc-unix" ]]; then
        winlator_report_runtime_class_mismatch "${detected}"
      fi
      ;;
    glibc-wrapped)
      if [[ "${WCP_ALLOW_GLIBC_EXPERIMENTAL}" != "1" ]]; then
        fail "WCP_RUNTIME_CLASS_TARGET=glibc-wrapped is disabled in mainline (set WCP_ALLOW_GLIBC_EXPERIMENTAL=1 only in experimental builds)"
      fi
      if [[ "${detected}" != "glibc-wrapped" ]]; then
        winlator_report_runtime_class_mismatch "${detected}"
      fi
      ;;
    *)
      fail "Unsupported WCP_RUNTIME_CLASS_TARGET: ${target}"
      ;;
  esac
}

winlator_validate_launchers() {
  local wine_bin wineserver_bin runtime_mismatch_reason

  [[ "${WCP_TARGET_RUNTIME}" == "winlator-bionic" ]] || return

  wine_bin="${WCP_ROOT}/bin/wine"
  wineserver_bin="${WCP_ROOT}/bin/wineserver"
  [[ -e "${wine_bin}" ]] || fail "Missing bin/wine"
  [[ -e "${wineserver_bin}" ]] || fail "Missing bin/wineserver"

  if winlator_is_glibc_launcher "${wine_bin}"; then
    fail "bin/wine is a raw glibc launcher for /lib/ld-linux-aarch64.so.1; Winlator bionic cannot execute it directly"
  fi
  if winlator_is_glibc_launcher "${wineserver_bin}"; then
    fail "bin/wineserver is a raw glibc launcher for /lib/ld-linux-aarch64.so.1; Winlator bionic cannot execute it directly"
  fi

  if [[ -f "${WCP_ROOT}/bin/wine.glibc-real" ]]; then
    local shebang
    shebang="$(head -n1 "${wine_bin}" || true)"
    [[ "${shebang}" == "#!/system/bin/sh" ]] || fail "bin/wine wrapper must use #!/system/bin/sh for Android execution"
    [[ -x "${WCP_ROOT}/lib/wine/wcp-glibc-runtime/ld-linux-aarch64.so.1" ]] || fail "Missing wrapped runtime loader: lib/wine/wcp-glibc-runtime/ld-linux-aarch64.so.1"
    grep -Fq 'unset LD_PRELOAD' "${wine_bin}" || fail "bin/wine glibc wrapper must clear LD_PRELOAD for Android bionic preload compatibility"
    grep -Fq 'glibc.pthread.rseq=0' "${wine_bin}" || fail "bin/wine glibc wrapper must disable glibc rseq on Android"
    grep -Fq 'unset LD_PRELOAD' "${wineserver_bin}" || fail "bin/wineserver glibc wrapper must clear LD_PRELOAD for Android bionic preload compatibility"
    grep -Fq 'glibc.pthread.rseq=0' "${wineserver_bin}" || fail "bin/wineserver glibc wrapper must disable glibc rseq on Android"
  fi

  winlator_validate_runtime_class_target
  runtime_mismatch_reason="$(winlator_detect_runtime_mismatch_reason "${WCP_ROOT}" "${WCP_RUNTIME_CLASS_TARGET:-bionic-native}")"
  [[ "${runtime_mismatch_reason}" == "none" ]] || fail "runtime mismatch detected after launcher validation: ${runtime_mismatch_reason}"
}
