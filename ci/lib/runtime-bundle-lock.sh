#!/usr/bin/env bash
set -euo pipefail

# Helpers for recording and verifying the bundled glibc runtime group
# (glibc + adjacent libs copied into wcp-glibc-runtime).

wcp_runtime_detect_marker() {
  local file="$1"
  local marker=""
  local comment=""

  if [[ ! -f "${file}" ]]; then
    printf '%s' "MISSING"
    return 0
  fi

  if command -v strings >/dev/null 2>&1; then
    case "$(basename -- "${file}")" in
      libc.so.6|ld-linux-aarch64.so.1)
        marker="$(strings -a "${file}" 2>/dev/null | grep -m1 -E 'GNU C Library|Ubuntu GLIBC|GLIBC [0-9]' || true)"
        ;;
      libstdc++.so.6)
        marker="$(strings -a "${file}" 2>/dev/null | grep -m1 -E 'GCC: \(|GLIBCXX_[0-9]' || true)"
        ;;
      libgcc_s.so.1)
        marker="$(strings -a "${file}" 2>/dev/null | grep -m1 -E 'GCC: \(|GCC_[0-9]' || true)"
        ;;
      libSDL2-2.0.so.0|libSDL2-2.0.so)
        marker="$(strings -a "${file}" 2>/dev/null | grep -m1 -E 'SDL[_ ]?2(\.[0-9]+)+' || true)"
        ;;
      *)
        ;;
    esac
  fi

  if [[ -z "${marker}" ]] && command -v readelf >/dev/null 2>&1; then
    comment="$(readelf -p .comment "${file}" 2>/dev/null | sed -n 's/.*]  //p' | head -n1 || true)"
    marker="${comment}"
  fi

  if [[ -z "${marker}" ]] && command -v strings >/dev/null 2>&1; then
    marker="$(strings -a "${file}" 2>/dev/null | head -n1 || true)"
  fi

  [[ -n "${marker}" ]] || marker="UNKNOWN"
  marker="${marker//$'\t'/ }"
  marker="${marker//$'\r'/ }"
  marker="${marker//$'\n'/ }"
  printf '%s' "${marker}"
}

wcp_runtime_write_glibc_markers() {
  local wcp_root="$1"
  local out_file="$2"
  local rel file marker

  : > "${out_file}"
  if [[ ! -d "${wcp_root}/lib/wine/wcp-glibc-runtime" ]]; then
    echo "ABSENT" > "${out_file}"
    return 0
  fi

  while IFS= read -r rel; do
    file="${wcp_root}/${rel}"
    marker="$(wcp_runtime_detect_marker "${file}")"
    printf '%s\t%s\n' "${rel}" "${marker}" >> "${out_file}"
  done < <(find "${wcp_root}/lib/wine/wcp-glibc-runtime" -type f -printf '%P\n' | LC_ALL=C sort | sed 's#^#lib/wine/wcp-glibc-runtime/#')
}

wcp_runtime_lock_lookup_marker() {
  local markers_file="$1" rel="$2"
  local value
  value="$(awk -F '\t' -v k="${rel}" '$1==k {print $2; exit}' "${markers_file}" 2>/dev/null || true)"
  if [[ -n "${value}" ]]; then
    printf '%s' "${value}"
  else
    printf '%s' "MISSING"
  fi
}

wcp_runtime_verify_glibc_lock() {
  local wcp_root="$1"
  local markers_file="${wcp_root}/share/wcp-forensics/glibc-runtime-version-markers.tsv"
  local lock_file="${WCP_RUNTIME_BUNDLE_LOCK_FILE:-}"
  local enforce="${WCP_RUNTIME_BUNDLE_ENFORCE_LOCK:-0}"
  local mode="${WCP_GLIBC_SOURCE_MODE:-host}"
  local effective_enforce="${enforce}"
  local mismatch_count=0
  local msg_prefix="[wcp-runtime-lock]"
  local actual

  [[ -n "${lock_file}" ]] || return 0
  [[ -f "${lock_file}" ]] || {
    if [[ "${effective_enforce}" == "1" ]]; then
      wcp_fail "Runtime bundle lock file not found: ${lock_file}"
    fi
    wcp_log "${msg_prefix} lock file missing (audit skipped): ${lock_file}"
    return 0
  }

  [[ -f "${markers_file}" ]] || {
    if [[ "${effective_enforce}" == "1" ]]; then
      wcp_fail "Runtime bundle markers file missing: ${markers_file}"
    fi
    wcp_log "${msg_prefix} markers file missing (audit skipped)"
    return 0
  }

  # shellcheck disable=SC1090
  source "${lock_file}"
  : "${WCP_RUNTIME_LOCK_ID:=}"
  : "${WCP_LOCK_EXPECT_LIBC_REGEX:=}"
  : "${WCP_LOCK_EXPECT_LOADER_REGEX:=}"
  : "${WCP_LOCK_EXPECT_LIBSTDCXX_REGEX:=}"
  : "${WCP_LOCK_EXPECT_LIBGCC_REGEX:=}"
  : "${WCP_LOCK_EXPECT_LIBSDL2_REGEX:=}"

  if [[ "${mode}" != "host" ]]; then
    effective_enforce=1
  fi

  _wcp_runtime_check_marker_regex() {
    local rel_path="$1" regex="$2" label="$3"
    [[ -n "${regex}" ]] || return 0
    actual="$(wcp_runtime_lock_lookup_marker "${markers_file}" "${rel_path}")"
    if [[ -z "${actual}" || ! "${actual}" =~ ${regex} ]]; then
      mismatch_count=$((mismatch_count + 1))
      if [[ "${effective_enforce}" == "1" ]]; then
        wcp_log "${msg_prefix} mismatch ${label}: expected /${regex}/ got '${actual:-MISSING}'"
      else
        wcp_log "${msg_prefix} audit mismatch ${label}: expected /${regex}/ got '${actual:-MISSING}'"
      fi
    fi
  }

  _wcp_runtime_check_marker_regex "lib/wine/wcp-glibc-runtime/libc.so.6" "${WCP_LOCK_EXPECT_LIBC_REGEX}" "libc"
  _wcp_runtime_check_marker_regex "lib/wine/wcp-glibc-runtime/ld-linux-aarch64.so.1" "${WCP_LOCK_EXPECT_LOADER_REGEX}" "loader"
  _wcp_runtime_check_marker_regex "lib/wine/wcp-glibc-runtime/libstdc++.so.6" "${WCP_LOCK_EXPECT_LIBSTDCXX_REGEX}" "libstdc++"
  _wcp_runtime_check_marker_regex "lib/wine/wcp-glibc-runtime/libgcc_s.so.1" "${WCP_LOCK_EXPECT_LIBGCC_REGEX}" "libgcc_s"
  _wcp_runtime_check_marker_regex "lib/wine/wcp-glibc-runtime/libSDL2-2.0.so.0" "${WCP_LOCK_EXPECT_LIBSDL2_REGEX}" "SDL2"

  if (( mismatch_count > 0 )); then
    if [[ "${effective_enforce}" == "1" ]]; then
      wcp_fail "Runtime bundle lock validation failed (${mismatch_count} mismatch(es)); lock=${WCP_RUNTIME_LOCK_ID:-unknown}"
    fi
    wcp_log "${msg_prefix} audit completed with ${mismatch_count} mismatch(es); lock=${WCP_RUNTIME_LOCK_ID:-unknown}"
  else
    wcp_log "${msg_prefix} validated (lock=${WCP_RUNTIME_LOCK_ID:-unknown}, mode=${mode}, enforce=${effective_enforce})"
  fi
}
