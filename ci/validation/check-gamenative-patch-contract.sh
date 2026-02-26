#!/usr/bin/env bash
set -euo pipefail

: "${WCP_GN_PATCHSET_STRICT:=1}"

TARGET=""
SOURCE_DIR=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") --target <wine|protonge> --source-dir <path>

Env:
  WCP_GN_PATCHSET_STRICT   default: 1
USAGE
}

log() { printf '[gamenative][contract] %s\n' "$*"; }
fail() { printf '[gamenative][contract][error] %s\n' "$*" >&2; exit 1; }

require_bool() {
  local name="$1" value="$2"
  case "${value}" in
    0|1) ;;
    *) fail "${name} must be 0 or 1 (got: ${value})" ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --source-dir)
      SOURCE_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "${TARGET}" ]] || fail "--target is required"
[[ -n "${SOURCE_DIR}" ]] || fail "--source-dir is required"
[[ -d "${SOURCE_DIR}" ]] || fail "source dir not found: ${SOURCE_DIR}"
case "${TARGET}" in
  wine|protonge) ;;
  *) fail "target must be wine or protonge (got: ${TARGET})" ;;
esac

require_bool WCP_GN_PATCHSET_STRICT "${WCP_GN_PATCHSET_STRICT}"

missing=0

check_fixed() {
  local file="$1" needle="$2" desc="$3"
  if grep -Fq "${needle}" "${file}"; then
    log "ok: ${desc}"
  else
    log "missing: ${desc}"
    missing=$((missing + 1))
  fi
}

check_regex() {
  local file="$1" pattern="$2" desc="$3"
  if grep -Eq "${pattern}" "${file}"; then
    log "ok: ${desc}"
  else
    log "missing: ${desc}"
    missing=$((missing + 1))
  fi
}

check_any_fixed() {
  local needle="$1" desc="$2"
  shift 2
  local file
  for file in "$@"; do
    if grep -Fq "${needle}" "${file}"; then
      log "ok: ${desc}"
      return 0
    fi
  done
  log "missing: ${desc}"
  missing=$((missing + 1))
}

check_absent_fixed() {
  local file="$1" needle="$2" desc="$3"
  if grep -Fq "${needle}" "${file}"; then
    log "missing: ${desc}"
    missing=$((missing + 1))
  else
    log "ok: ${desc}"
  fi
}

f_loader="${SOURCE_DIR}/dlls/ntdll/loader.c"
f_ntdll_spec="${SOURCE_DIR}/dlls/ntdll/ntdll.spec"
f_wow64_syscall="${SOURCE_DIR}/dlls/wow64/syscall.c"
f_wow64_spec="${SOURCE_DIR}/dlls/wow64/wow64.spec"
f_winternl="${SOURCE_DIR}/include/winternl.h"
f_menubuilder="${SOURCE_DIR}/programs/winemenubuilder/winemenubuilder.c"
f_winebrowser="${SOURCE_DIR}/programs/winebrowser/main.c"

for f in "${f_loader}" "${f_ntdll_spec}" "${f_wow64_syscall}" "${f_wow64_spec}" "${f_winternl}" "${f_menubuilder}"; do
  [[ -f "${f}" ]] || fail "required source file missing: ${f}"
done

# Core WOW64/FEX contract shared by wine and proton-ge.
check_fixed "${f_loader}" 'libarm64ecfex.dll' 'ntdll loader uses libarm64ecfex.dll'
check_fixed "${f_loader}" 'pWow64SuspendLocalThread' 'ntdll loader has pWow64SuspendLocalThread pointer'
check_fixed "${f_loader}" 'GET_PTR( Wow64SuspendLocalThread );' 'ntdll loader imports Wow64SuspendLocalThread'
check_fixed "${f_ntdll_spec}" 'RtlWow64SuspendThread' 'ntdll.spec exports RtlWow64SuspendThread'
check_fixed "${f_wow64_syscall}" 'Wow64SuspendLocalThread' 'wow64 syscall exports local suspend helper'
check_fixed "${f_wow64_spec}" 'Wow64SuspendLocalThread' 'wow64.spec exports Wow64SuspendLocalThread'

# Thread flags/TEB extensions.
check_fixed "${f_winternl}" 'THREAD_CREATE_FLAGS_SKIP_THREAD_ATTACH' 'winternl exposes SKIP_THREAD_ATTACH'
check_fixed "${f_winternl}" 'THREAD_CREATE_FLAGS_SKIP_LOADER_INIT' 'winternl exposes SKIP_LOADER_INIT'
check_fixed "${f_winternl}" 'THREAD_CREATE_FLAGS_BYPASS_PROCESS_FREEZE' 'winternl exposes BYPASS_PROCESS_FREEZE'

# Winlator shortcut contract from winemenubuilder.
check_regex "${f_menubuilder}" 'icons\\\\hicolor' 'winemenubuilder writes icons to xdg hicolor path'
check_fixed "${f_menubuilder}" 'WINECONFIGDIR' 'winemenubuilder uses WINECONFIGDIR in Exec line'
check_regex "${f_menubuilder}" 'fprintf\(file, "wine ' 'winemenubuilder prefixes Exec with wine'

if [[ -f "${f_winebrowser}" ]] && grep -Fq 'send_android_message' "${f_winebrowser}"; then
  check_regex "${f_winebrowser}" 'send\(sock_fd,\s*\(const char \*\)&net_requestcode,\s*sizeof\(net_requestcode\),\s*0\)' 'winebrowser send() casts request code buffer'
  check_regex "${f_winebrowser}" 'send\(sock_fd,\s*\(const char \*\)&net_data_length,\s*sizeof\(net_data_length\),\s*0\)' 'winebrowser send() casts payload length buffer'
  check_fixed "${f_winebrowser}" 'WINE_OPEN_WITH_ANDROID_BROWSER' 'winebrowser uses canonical WINE_OPEN_WITH_ANDROID_BROWSER env key'
  check_absent_fixed "${f_winebrowser}" 'WINE_OPEN_WITH_ANDROID_BROwSER' 'winebrowser does not use typo BROwSER env key'
fi

if [[ "${TARGET}" == "wine" ]]; then
  f_wineboot="${SOURCE_DIR}/programs/wineboot/wineboot.c"
  [[ -f "${f_wineboot}" ]] || fail "required source file missing: ${f_wineboot}"
  check_fixed "${f_wineboot}" 'initialize_xstate_features(struct _KUSER_SHARED_DATA *data)' 'wineboot has xstate initializer'
  check_fixed "${f_wineboot}" 'xstate->AllFeatureSize = 0x340;' 'wineboot xstate size is set for arm64 path'
fi

if [[ "${TARGET}" == "protonge" ]]; then
  f_window="${SOURCE_DIR}/dlls/winex11.drv/window.c"
  f_signal_arm64ec="${SOURCE_DIR}/dlls/ntdll/signal_arm64ec.c"
  f_virtual="${SOURCE_DIR}/dlls/ntdll/unix/virtual.c"
  f_wow64_process="${SOURCE_DIR}/dlls/wow64/process.c"
  f_makedep="${SOURCE_DIR}/tools/makedep.c"
  [[ -f "${f_window}" ]] || fail "required source file missing: ${f_window}"
  [[ -f "${f_signal_arm64ec}" ]] || fail "required source file missing: ${f_signal_arm64ec}"
  [[ -f "${f_virtual}" ]] || fail "required source file missing: ${f_virtual}"
  [[ -f "${f_wow64_process}" ]] || fail "required source file missing: ${f_wow64_process}"
  [[ -f "${f_makedep}" ]] || fail "required source file missing: ${f_makedep}"
  check_fixed "${f_wow64_syscall}" 'wow64GetEnvironmentVariableW' 'wow64 syscall has env helper for HODLL override'
  check_fixed "${f_wow64_syscall}" 'L"HODLL"' 'wow64 syscall supports HODLL override'
  check_fixed "${f_wow64_syscall}" 'Wow64SuspendLocalThread' 'wow64 syscall exposes Wow64SuspendLocalThread'
  check_fixed "${f_wow64_process}" 'RtlWow64SuspendThread' 'wow64 process path uses RtlWow64SuspendThread'
  check_any_fixed 'Wow64SuspendLocalThread' 'wow64 local suspend helper is exported (process or syscall path)' "${f_wow64_process}" "${f_wow64_syscall}"
  check_fixed "${f_signal_arm64ec}" 'ARM64EC_NT_XCONTEXT' 'arm64ec signal path has extended context union'
  check_fixed "${f_virtual}" 'fex_stats_shm' 'ntdll unix virtual path exposes fex stats shared mapping'
  check_fixed "${f_winternl}" 'ProcessFexHardwareTso' 'winternl includes ProcessFexHardwareTso enum'
  check_fixed "${f_winternl}" 'MemoryFexStatsShm' 'winternl includes MemoryFexStatsShm enum'
  check_regex "${f_makedep}" 'aarch64-windows|%s-windows' 'makedep installs arm64ec unix libs into aarch64-windows path'
  check_fixed "${f_window}" 'class_hints->res_name = process_name;' 'winex11 class hints use process_name on Android'
  check_fixed "${f_window}" '#ifdef __ANDROID__' 'winex11 has Android-specific class hints branch'
fi

if [[ "${missing}" -gt 0 ]]; then
  if [[ "${WCP_GN_PATCHSET_STRICT}" == "1" ]]; then
    fail "contract check failed: missing=${missing}"
  fi
  log "contract check warnings: missing=${missing} (strict=0)"
else
  log "contract check passed"
fi
