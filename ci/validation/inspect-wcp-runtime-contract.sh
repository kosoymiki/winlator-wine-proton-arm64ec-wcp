#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/winlator-runtime.sh"

usage() {
  cat <<'EOF'
Usage:
  bash ci/validation/inspect-wcp-runtime-contract.sh <path-to.wcp> [--strict-bionic] [--strict-gamenative]

Outputs:
  - runtime class / launcher ABI / unix ABI summary
  - unix-module-abi forensic table stats
EOF
}

fail() {
  printf '[inspect-wcp][error] %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[inspect-wcp] %s\n' "$*"
}

extract_elf_runpath() {
  local elf_path="$1"
  local dyn
  dyn="$(readelf -d "${elf_path}" 2>/dev/null || true)"
  [[ -n "${dyn}" ]] || return 0
  awk '
    /RUNPATH|RPATH/ {
      if (match($0, /\[[^]]+\]/)) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
      }
    }
  ' <<<"${dyn}"
}

main() {
  local wcp_path="${1:-}"
  local strict_bionic=0
  local strict_gamenative=0
  local strict_runpath
  local runpath_contract_set runpath_regex_set
  local tmp_dir wcp_root unix_abi_file glibc_hits
  local glibc_row glibc_name allowed opt
  local wine_runpath wineserver_runpath runpath_accept_regex
  local -a strict_allowed_glibc_modules forensic_glibc_rows blocking_glibc_rows
  local -a missing_gn_symbols

  [[ -n "${wcp_path}" ]] || { usage; fail "WCP path is required"; }
  shift || true
  while [[ -n "${1:-}" ]]; do
    case "${1}" in
      --strict-bionic) strict_bionic=1 ;;
      --strict-gamenative) strict_gamenative=1 ;;
      *)
        usage
        fail "Unknown argument: ${1}"
        ;;
    esac
    shift
  done
  [[ -f "${wcp_path}" ]] || fail "WCP not found: ${wcp_path}"
  runpath_contract_set="${WCP_STRICT_RUNPATH_CONTRACT+x}"
  runpath_regex_set="${WCP_RUNPATH_ACCEPT_REGEX+x}"
  : "${WCP_STRICT_RUNPATH_CONTRACT:=0}"
  : "${WCP_RUNPATH_ACCEPT_REGEX:=^/data/data/(com\\.termux|com\\.winlator\\.cmod|by\\.aero\\.so\\.benchmark)/files/(usr/lib|imagefs/usr/lib)$}"
  strict_runpath="${WCP_STRICT_RUNPATH_CONTRACT}"
  runpath_accept_regex="${WCP_RUNPATH_ACCEPT_REGEX}"
  if [[ "${strict_bionic}" == "1" && -z "${runpath_contract_set}" ]]; then
    strict_runpath="1"
  fi
  if [[ "${strict_bionic}" == "1" && -z "${runpath_regex_set}" ]]; then
    runpath_accept_regex='^/data/data/com\.termux/files/usr/lib$'
  fi
  [[ "${strict_runpath}" =~ ^[01]$ ]] || fail "WCP_STRICT_RUNPATH_CONTRACT must be 0 or 1"

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir:-}"' EXIT
  winlator_extract_wcp_archive "${wcp_path}" "${tmp_dir}" || fail "Unable to extract WCP"
  wcp_root="${tmp_dir}"

  log "runtimeClass=$(winlator_detect_runtime_class "${wcp_root}")"
  log "unixAbi=$(winlator_detect_unix_module_abi "${wcp_root}")"
  log "wineLauncherAbi=$(winlator_detect_launcher_abi "${wcp_root}/bin/wine")"
  log "wineserverLauncherAbi=$(winlator_detect_launcher_abi "${wcp_root}/bin/wineserver")"
  wine_runpath="$(extract_elf_runpath "${wcp_root}/bin/wine" || true)"
  wineserver_runpath="$(extract_elf_runpath "${wcp_root}/bin/wineserver" || true)"
  log "wineRunpath=${wine_runpath:-ABSENT}"
  log "wineserverRunpath=${wineserver_runpath:-ABSENT}"
  if [[ "${strict_runpath}" == "1" && -z "${wine_runpath}" ]]; then
    fail "Runpath contract failed for bin/wine: RUNPATH is missing"
  fi
  if [[ -n "${wine_runpath}" && ! "${wine_runpath}" =~ ${runpath_accept_regex} ]]; then
    if [[ "${strict_runpath}" == "1" ]]; then
      fail "Runpath contract failed for bin/wine: ${wine_runpath}"
    fi
    log "runpath warn: bin/wine runpath outside accepted regex (${runpath_accept_regex})"
  fi
  if [[ "${strict_runpath}" == "1" && -z "${wineserver_runpath}" ]]; then
    fail "Runpath contract failed for bin/wineserver: RUNPATH is missing"
  fi
  if [[ -n "${wineserver_runpath}" && ! "${wineserver_runpath}" =~ ${runpath_accept_regex} ]]; then
    if [[ "${strict_runpath}" == "1" ]]; then
      fail "Runpath contract failed for bin/wineserver: ${wineserver_runpath}"
    fi
    log "runpath warn: bin/wineserver runpath outside accepted regex (${runpath_accept_regex})"
  fi

  unix_abi_file="${wcp_root}/share/wcp-forensics/unix-module-abi.tsv"
  if [[ -f "${unix_abi_file}" ]]; then
    log "unixModuleAbiFile=${unix_abi_file}"
    log "unixModuleAbiRows=$(wc -l < "${unix_abi_file}")"
    glibc_hits="$(grep -c $'\tglibc-unix$' "${unix_abi_file}" || true)"
    log "unixModuleAbiGlibcRows=${glibc_hits}"
    if [[ "${strict_bionic}" == "1" && "${glibc_hits}" != "0" ]]; then
      : "${WCP_BIONIC_STRICT_ALLOWED_GLIBC_UNIX_MODULES:=winebth.so opencl.so winedmo.so}"
      # shellcheck disable=SC2206
      strict_allowed_glibc_modules=( ${WCP_BIONIC_STRICT_ALLOWED_GLIBC_UNIX_MODULES} )
      mapfile -t forensic_glibc_rows < <(awk -F'\t' '$2=="glibc-unix"{print $1}' "${unix_abi_file}" || true)
      blocking_glibc_rows=()
      for glibc_row in "${forensic_glibc_rows[@]}"; do
        glibc_name="$(basename "${glibc_row}")"
        allowed=0
        for opt in "${strict_allowed_glibc_modules[@]}"; do
          [[ "${glibc_name}" == "${opt}" ]] || continue
          allowed=1
          break
        done
        if [[ "${allowed}" != "1" ]]; then
          blocking_glibc_rows+=("${glibc_row}")
        fi
      done
      if [[ "${#blocking_glibc_rows[@]}" -gt 0 ]]; then
        fail "Strict bionic check failed: found non-allowed glibc-unix rows in unix-module-abi.tsv: ${blocking_glibc_rows[*]}"
      fi
      log "Strict bionic check tolerated optional glibc rows: ${forensic_glibc_rows[*]}"
    fi
  else
    log "unixModuleAbiFile=ABSENT"
    if [[ "${strict_bionic}" == "1" ]]; then
      fail "Strict bionic check failed: unix-module-abi.tsv is missing (expected Aero.so WCP forensic bundle)"
    fi
  fi

  if [[ -f "${wcp_root}/profile.json" ]]; then
    log "profileRuntimeFields:"
    grep -E '"runtimeClass(Target|Detected)"|"unixAbiDetected"|"runtimeMismatchReason"|"bionic(SourceMap|LauncherSource|UnixSource|DonorPreflightDone)"' "${wcp_root}/profile.json" || true
  fi
  if [[ -f "${wcp_root}/share/wcp-forensics/source-refs.json" ]]; then
    log "forensicSourceRefs:"
    grep -E '"WCP_BIONIC_SOURCE_MAP_|"WCP_BIONIC_(LAUNCHER|UNIX)_SOURCE_WCP_(RESOLVED_)?(PATH|SHA256)"' \
      "${wcp_root}/share/wcp-forensics/source-refs.json" || true
  fi
  if [[ -f "${wcp_root}/share/wcp-forensics/bionic-source-entry.json" ]]; then
    log "forensicBionicSourceEntry:"
    grep -E '"packageName"|"path"|"sha256"|"resolved(Sha256|Path)"|"donorPreflightDone"' \
      "${wcp_root}/share/wcp-forensics/bionic-source-entry.json" || true
    if [[ "${strict_bionic}" == "1" ]]; then
      python3 - "${wcp_root}/share/wcp-forensics/bionic-source-entry.json" <<'PY' || \
        fail "Strict bionic check failed: bionic-source-entry.json contract violation"
import json
import re
import sys
from pathlib import Path

entry = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
sha_re = re.compile(r"^[0-9a-f]{64}$")
errors = []

def sval(obj, key):
    v = (obj or {}).get(key)
    return (v or "").strip() if isinstance(v, str) else ""

def validate_source(block_name, block, strict_donor):
    source_sha = sval(block, "sha256").lower()
    resolved_sha = sval(block, "resolvedSha256").lower()
    resolved_path = sval(block, "resolvedPath")
    if strict_donor:
        if not sha_re.fullmatch(source_sha):
            errors.append(f"{block_name}.sha256 must be 64 lowercase hex")
        if not sha_re.fullmatch(resolved_sha):
            errors.append(f"{block_name}.resolvedSha256 must be 64 lowercase hex")
        if source_sha and resolved_sha and source_sha != resolved_sha:
            errors.append(f"{block_name}.sha256 and resolvedSha256 mismatch")
        if not resolved_path:
            errors.append(f"{block_name}.resolvedPath must be set")

source_map = entry.get("sourceMap") or {}
source_map_applied = sval(source_map, "applied")
source_map_resolved = sval(source_map, "resolved")
source_map_sha = sval(source_map, "sha256").lower()
if source_map_applied in ("1", "true") and not sha_re.fullmatch(source_map_sha):
    errors.append("sourceMap.sha256 must be 64 lowercase hex when sourceMap.applied=1")
if source_map_applied and source_map_applied not in ("0", "1", "true", "false"):
    errors.append("sourceMap.applied must be 0/1/true/false when set")
if source_map_resolved and source_map_resolved not in ("0", "1", "true", "false"):
    errors.append("sourceMap.resolved must be 0/1/true/false when set")

launcher = entry.get("launcherSource") or {}
unix = entry.get("unixSource") or {}
donor_fields = (
    sval(launcher, "url"), sval(launcher, "sha256"), sval(launcher, "resolvedPath"), sval(launcher, "resolvedSha256"),
    sval(unix, "url"), sval(unix, "sha256"), sval(unix, "resolvedPath"), sval(unix, "resolvedSha256"),
)
donor_configured = any(v for v in donor_fields)
if donor_configured and sval(entry, "donorPreflightDone") not in ("1", "true"):
    errors.append("donorPreflightDone must be 1 when donor source is configured")

validate_source("launcherSource", launcher, donor_configured)
validate_source("unixSource", unix, donor_configured)

if errors:
    for e in errors:
        print(f"[inspect-wcp][error] {e}")
    sys.exit(1)
PY
    fi
  elif [[ "${strict_bionic}" == "1" ]]; then
    fail "Strict bionic check failed: bionic-source-entry.json is missing"
  fi

  if command -v llvm-readobj >/dev/null 2>&1; then
    local ntdll_dll wow64_dll win32u_dll
    ntdll_dll="${wcp_root}/lib/wine/aarch64-windows/ntdll.dll"
    wow64_dll="${wcp_root}/lib/wine/aarch64-windows/wow64.dll"
    win32u_dll="${wcp_root}/lib/wine/aarch64-windows/win32u.dll"
    missing_gn_symbols=()

    check_symbol() {
      local dll="$1" symbol="$2" label="$3"
      local dump
      if [[ ! -f "${dll}" ]]; then
        missing_gn_symbols+=("${label}:${symbol}:dll-missing")
        log "gamenativeBaseline warn: ${label} missing (${dll})"
        return
      fi
      dump="$(llvm-readobj --coff-exports "${dll}" 2>/dev/null || true)"
      if grep -q "Name: ${symbol}" <<<"${dump}"; then
        log "gamenativeBaseline ok: ${label} exports ${symbol}"
      else
        missing_gn_symbols+=("${label}:${symbol}:missing-export")
        log "gamenativeBaseline warn: ${label} missing export ${symbol}"
      fi
    }

    check_symbol "${ntdll_dll}" "NtCreateUserProcess" "ntdll.dll"
    check_symbol "${ntdll_dll}" "RtlCreateUserThread" "ntdll.dll"
    check_symbol "${ntdll_dll}" "RtlWow64GetThreadContext" "ntdll.dll"
    check_symbol "${ntdll_dll}" "RtlWow64SetThreadContext" "ntdll.dll"
    check_symbol "${wow64_dll}" "Wow64SuspendLocalThread" "wow64.dll"
    check_symbol "${win32u_dll}" "NtUserSendInput" "win32u.dll"
    check_symbol "${win32u_dll}" "NtUserGetRawInputData" "win32u.dll"

    if [[ "${strict_gamenative}" == "1" && "${#missing_gn_symbols[@]}" -gt 0 ]]; then
      fail "Strict gamenative check failed: missing baseline symbols: ${missing_gn_symbols[*]}"
    fi
  else
    log "gamenativeBaseline skipped: llvm-readobj unavailable"
    if [[ "${strict_gamenative}" == "1" ]]; then
      fail "Strict gamenative check failed: llvm-readobj unavailable"
    fi
  fi
}

main "$@"
