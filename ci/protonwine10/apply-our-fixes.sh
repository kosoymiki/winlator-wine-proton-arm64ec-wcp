#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WINE_SRC_DIR="${WINE_SRC_DIR:-${ROOT_DIR}/work/protonwine10/wine-src}"

log() { printf '[protonwine10][apply-ours] %s\n' "$*"; }
fail() { printf '[protonwine10][apply-ours][error] %s\n' "$*" >&2; exit 1; }

main() {
  local winnt_h bus_sdl_c

  [[ -d "${WINE_SRC_DIR}" ]] || fail "Missing WINE_SRC_DIR: ${WINE_SRC_DIR}"

  winnt_h="${WINE_SRC_DIR}/include/winnt.h"
  [[ -f "${winnt_h}" ]] || fail "Missing ${winnt_h}"
  if grep -q '^    LONG dummy;$' "${winnt_h}"; then
    sed -i 's/^    LONG dummy;$/    long volatile dummy = 0;/' "${winnt_h}"
    log "Applied winnt.h InterlockedOr ARM64EC compatibility fix"
  fi

  bus_sdl_c="${WINE_SRC_DIR}/dlls/winebus.sys/bus_sdl.c"
  [[ -f "${bus_sdl_c}" ]] || fail "Missing ${bus_sdl_c}"
  perl -0pi -e 's/#else\n\nNTSTATUS sdl_bus_init\(void \*args\)/#else\n\nBOOL is_sdl_ignored_device(WORD vid, WORD pid)\n{\n    return FALSE;\n}\n\nNTSTATUS sdl_bus_init(void *args)/' "${bus_sdl_c}"
  log "Applied SDL fallback stub fix for winebus"

  if [[ ! -f "${WINE_SRC_DIR}/dlls/winebus.sys/Makefile.in" ]]; then
    fail "winebus Makefile is missing; cannot confirm SDL2 integration"
  fi

  if ! grep -q 'SDL2_CFLAGS' "${WINE_SRC_DIR}/dlls/winebus.sys/Makefile.in"; then
    fail "SDL2 flags are missing in winebus Makefile; incompatible source layout"
  fi

  log "Project-local compatibility fixes applied"
}

main "$@"
