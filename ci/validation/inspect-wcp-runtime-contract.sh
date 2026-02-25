#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/ci/lib/winlator-runtime.sh"

usage() {
  cat <<'EOF'
Usage:
  bash ci/validation/inspect-wcp-runtime-contract.sh <path-to.wcp> [--strict-bionic]

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

main() {
  local wcp_path="${1:-}"
  local strict_bionic=0
  local tmp_dir wcp_root unix_abi_file glibc_hits

  [[ -n "${wcp_path}" ]] || { usage; fail "WCP path is required"; }
  shift || true
  if [[ "${1:-}" == "--strict-bionic" ]]; then
    strict_bionic=1
  elif [[ -n "${1:-}" ]]; then
    usage
    fail "Unknown argument: ${1}"
  fi
  [[ -f "${wcp_path}" ]] || fail "WCP not found: ${wcp_path}"

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT
  winlator_extract_wcp_archive "${wcp_path}" "${tmp_dir}" || fail "Unable to extract WCP"
  wcp_root="${tmp_dir}"

  log "runtimeClass=$(winlator_detect_runtime_class "${wcp_root}")"
  log "unixAbi=$(winlator_detect_unix_module_abi "${wcp_root}")"
  log "wineLauncherAbi=$(winlator_detect_launcher_abi "${wcp_root}/bin/wine")"
  log "wineserverLauncherAbi=$(winlator_detect_launcher_abi "${wcp_root}/bin/wineserver")"

  unix_abi_file="${wcp_root}/share/wcp-forensics/unix-module-abi.tsv"
  if [[ -f "${unix_abi_file}" ]]; then
    log "unixModuleAbiFile=${unix_abi_file}"
    log "unixModuleAbiRows=$(wc -l < "${unix_abi_file}")"
    glibc_hits="$(grep -c $'\tglibc-unix$' "${unix_abi_file}" || true)"
    log "unixModuleAbiGlibcRows=${glibc_hits}"
    if [[ "${strict_bionic}" == "1" && "${glibc_hits}" != "0" ]]; then
      fail "Strict bionic check failed: found glibc-unix rows in unix-module-abi.tsv"
    fi
  else
    log "unixModuleAbiFile=ABSENT"
    if [[ "${strict_bionic}" == "1" ]]; then
      fail "Strict bionic check failed: unix-module-abi.tsv is missing"
    fi
  fi

  if [[ -f "${wcp_root}/profile.json" ]]; then
    log "profileRuntimeFields:"
    grep -E '"runtimeClass(Target|Detected)"|"unixAbiDetected"|"runtimeMismatchReason"|"bionic(SourceMap|LauncherSource|UnixSource)"' "${wcp_root}/profile.json" || true
  fi
}

main "$@"
