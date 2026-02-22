#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WINE_SRC_DIR="${WINE_SRC_DIR:-${ROOT_DIR}/work/protonwine10/wine-src}"

log() { printf '[protonwine10][apply-ours] %s\n' "$*"; }
fail() { printf '[protonwine10][apply-ours][error] %s\n' "$*" >&2; exit 1; }

main() {
  local winnt_h bus_sdl_c wineboot_c

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

  wineboot_c="${WINE_SRC_DIR}/programs/wineboot/wineboot.c"
  [[ -f "${wineboot_c}" ]] || fail "Missing ${wineboot_c}"
  python3 - <<'PY' "${wineboot_c}"
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = "#elif defined(__aarch64__)"
if marker not in text:
    sys.exit(0)

head, tail = text.split(marker, 1)
if "#else" not in tail:
    raise SystemExit("missing #else delimiter in wineboot.c architecture block")

aarch64_block, rest = tail.split("#else", 1)
if "initialize_xstate_features(struct _KUSER_SHARED_DATA *data)" in aarch64_block:
    sys.exit(0)

inject = """

static void initialize_xstate_features(struct _KUSER_SHARED_DATA *data)
{
    XSTATE_CONFIGURATION *xstate = &data->XState;

    xstate->EnabledFeatures = (1 << XSTATE_LEGACY_FLOATING_POINT) | (1 << XSTATE_LEGACY_SSE) | (1 << XSTATE_AVX);
    xstate->EnabledVolatileFeatures = xstate->EnabledFeatures;
    xstate->AllFeatureSize = 0x340;

    xstate->OptimizedSave = 0;
    xstate->CompactionEnabled = 0;

    xstate->Features[0].Size = xstate->AllFeatures[0] = offsetof(XSAVE_FORMAT, XmmRegisters);
    xstate->Features[1].Size = xstate->AllFeatures[1] = sizeof(M128A) * 16;
    xstate->Features[1].Offset = xstate->Features[0].Size;
    xstate->Features[2].Offset = 0x240;
    xstate->Features[2].Size = 0x100;
    xstate->Size = 0x340;
}
"""

path.write_text(head + marker + aarch64_block + inject + "\n#else" + rest, encoding="utf-8")
PY
  log "Applied aarch64 xstate init fix for wineboot"

  log "Project-local compatibility fixes applied"
}

main "$@"
