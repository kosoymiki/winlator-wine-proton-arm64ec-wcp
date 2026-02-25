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

f_loader="${SOURCE_DIR}/dlls/ntdll/loader.c"
f_wow64_syscall="${SOURCE_DIR}/dlls/wow64/syscall.c"
f_wow64_spec="${SOURCE_DIR}/dlls/wow64/wow64.spec"
f_winternl="${SOURCE_DIR}/include/winternl.h"
f_menubuilder="${SOURCE_DIR}/programs/winemenubuilder/winemenubuilder.c"

for f in "${f_loader}" "${f_wow64_syscall}" "${f_wow64_spec}" "${f_winternl}" "${f_menubuilder}"; do
  [[ -f "${f}" ]] || fail "required source file missing: ${f}"
done

# Core WOW64/FEX contract shared by wine and proton-ge.
check_fixed "${f_loader}" 'libarm64ecfex.dll' 'ntdll loader uses libarm64ecfex.dll'
check_fixed "${f_loader}" 'pWow64SuspendLocalThread' 'ntdll loader has pWow64SuspendLocalThread pointer'
check_fixed "${f_loader}" 'GET_PTR( Wow64SuspendLocalThread );' 'ntdll loader imports Wow64SuspendLocalThread'
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

if [[ "${TARGET}" == "wine" ]]; then
  f_wineboot="${SOURCE_DIR}/programs/wineboot/wineboot.c"
  [[ -f "${f_wineboot}" ]] || fail "required source file missing: ${f_wineboot}"
  check_fixed "${f_wineboot}" 'initialize_xstate_features(struct _KUSER_SHARED_DATA *data)' 'wineboot has xstate initializer'
  check_fixed "${f_wineboot}" 'xstate->AllFeatureSize = 0x340;' 'wineboot xstate size is set for arm64 path'
fi

if [[ "${TARGET}" == "protonge" ]]; then
  f_window="${SOURCE_DIR}/dlls/winex11.drv/window.c"
  [[ -f "${f_window}" ]] || fail "required source file missing: ${f_window}"
  check_fixed "${f_wow64_syscall}" 'wow64GetEnvironmentVariableW' 'wow64 syscall has env helper for HODLL override'
  check_fixed "${f_wow64_syscall}" 'L"HODLL"' 'wow64 syscall supports HODLL override'
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
