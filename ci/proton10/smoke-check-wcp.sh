#!/usr/bin/env bash
set -euo pipefail

WCP_PATH="${1:-${WCP_PATH:-}}"
WCP_COMPRESS="${2:-${WCP_COMPRESS:-xz}}"
WCP_PRUNE_EXTERNAL_COMPONENTS="${WCP_PRUNE_EXTERNAL_COMPONENTS:-1}"
WCP_ENABLE_SDL2_RUNTIME="${WCP_ENABLE_SDL2_RUNTIME:-1}"
WCP_MAINLINE_FEX_EXTERNAL_ONLY="${WCP_MAINLINE_FEX_EXTERNAL_ONLY:-1}"

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
grep -qx 'share/wcp-forensics/external-runtime-components.tsv' "${normalized_file}" || fail "Missing share/wcp-forensics/external-runtime-components.tsv"

if grep -qx 'bin/wine.glibc-real' "${normalized_file}"; then
  grep -qx 'bin/wineserver.glibc-real' "${normalized_file}" || fail "Missing bin/wineserver.glibc-real"
  grep -qx 'lib/wine/wcp-glibc-runtime/ld-linux-aarch64.so.1' "${normalized_file}" || fail "Missing bundled glibc runtime loader"

  case "${WCP_COMPRESS}" in
    xz)
      shebang="$(tar -xJOf "${WCP_PATH}" ./bin/wine 2>/dev/null | head -n1)"
      ;;
    zst|zstd)
      shebang="$(tar --zstd -xOf "${WCP_PATH}" ./bin/wine 2>/dev/null | head -n1)"
      ;;
  esac
  [[ "${shebang}" == "#!/system/bin/sh" ]] || fail "bin/wine wrapper must use #!/system/bin/sh"
fi

if [[ "${WCP_ENABLE_SDL2_RUNTIME}" == "1" ]]; then
  grep -Eq '^lib/wine/aarch64-unix/winebus(\.sys)?\.so$' "${normalized_file}" || fail "Missing lib/wine/aarch64-unix/winebus.so (or winebus.sys.so)"
fi

if [[ "${WCP_PRUNE_EXTERNAL_COMPONENTS}" == "1" ]]; then
  if grep -Eq '^lib/wine/aarch64-windows/lib(arm64ec|wow64)fex\.dll$' "${normalized_file}"; then
    fail "FEX payload is present while WCP_PRUNE_EXTERNAL_COMPONENTS=1"
  fi
  if grep -Eq '^lib/wine/(dxvk|vkd3d|vk3d)(/|$)' "${normalized_file}"; then
    fail "DXVK/VKD3D payload is present while WCP_PRUNE_EXTERNAL_COMPONENTS=1"
  fi
fi

if [[ "${WCP_MAINLINE_FEX_EXTERNAL_ONLY}" == "1" ]]; then
  if grep -Eiq '(^|/)(libarm64ecfex\.dll|libwow64fex\.dll|fexcore|box64|wowbox64)($|/)' "${normalized_file}"; then
    fail "Mainline external-runtime policy violation: embedded FEX/Box/WoWBox artifacts detected"
  fi
fi

(
  cd "$(dirname "${WCP_PATH}")"
  sha256sum "$(basename "${WCP_PATH}")" > SHA256SUMS
)

log "WCP smoke checks passed for ${WCP_PATH}"
log "SHA256SUMS generated at $(dirname "${WCP_PATH}")/SHA256SUMS"
