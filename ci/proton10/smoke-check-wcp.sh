#!/usr/bin/env bash
set -euo pipefail

WCP_PATH="${1:-${WCP_PATH:-}}"
WCP_COMPRESS="${2:-${WCP_COMPRESS:-xz}}"
WCP_PRUNE_EXTERNAL_COMPONENTS="${WCP_PRUNE_EXTERNAL_COMPONENTS:-1}"
WCP_ENABLE_SDL2_RUNTIME="${WCP_ENABLE_SDL2_RUNTIME:-1}"

log() { printf '[proton10][smoke] %s\n' "$*"; }
fail() { printf '[proton10][smoke][error] %s\n' "$*" >&2; exit 1; }

[[ -n "${WCP_PATH}" ]] || fail "WCP path is required (arg1 or WCP_PATH)"
[[ -f "${WCP_PATH}" ]] || fail "WCP artifact not found: ${WCP_PATH}"

list_file="$(mktemp)"
normalized_file="$(mktemp)"
trap 'rm -f "${list_file}" "${normalized_file}"' EXIT

case "${WCP_COMPRESS}" in
  xz)
    tar -tJf "${WCP_PATH}" > "${list_file}"
    ;;
  zst|zstd)
    tar --zstd -tf "${WCP_PATH}" > "${list_file}"
    ;;
  *)
    fail "WCP_COMPRESS must be xz or zst"
    ;;
esac

sed 's#^\./##' "${list_file}" > "${normalized_file}"

grep -qx 'bin/wine' "${normalized_file}" || fail "Missing bin/wine"
grep -qx 'bin/wineserver' "${normalized_file}" || fail "Missing bin/wineserver"
grep -q '^lib/wine/' "${normalized_file}" || fail "Missing lib/wine/"
grep -q '^share/' "${normalized_file}" || fail "Missing share/"
grep -qx 'prefixPack.txz' "${normalized_file}" || fail "Missing prefixPack.txz"
grep -qx 'profile.json' "${normalized_file}" || fail "Missing profile.json"

if [[ "${WCP_ENABLE_SDL2_RUNTIME}" == "1" ]]; then
  grep -qx 'lib/wine/aarch64-unix/winebus.sys.so' "${normalized_file}" || fail "Missing lib/wine/aarch64-unix/winebus.sys.so"
fi

if [[ "${WCP_PRUNE_EXTERNAL_COMPONENTS}" == "1" ]]; then
  if grep -Eq '^lib/wine/aarch64-windows/lib(arm64ec|wow64)fex\.dll$' "${normalized_file}"; then
    fail "FEX payload is present while WCP_PRUNE_EXTERNAL_COMPONENTS=1"
  fi
  if grep -Eq '^lib/wine/(dxvk|vkd3d|vk3d)(/|$)' "${normalized_file}"; then
    fail "DXVK/VKD3D payload is present while WCP_PRUNE_EXTERNAL_COMPONENTS=1"
  fi
fi

(
  cd "$(dirname "${WCP_PATH}")"
  sha256sum "$(basename "${WCP_PATH}")" > SHA256SUMS
)

log "WCP smoke checks passed for ${WCP_PATH}"
log "SHA256SUMS generated at $(dirname "${WCP_PATH}")/SHA256SUMS"
