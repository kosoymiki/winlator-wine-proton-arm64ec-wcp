#!/usr/bin/env bash
set -euo pipefail

WINLATOR_SRC_DIR="${1:-}"; shift || true
ASSETS_DIR="${WINLATOR_SRC_DIR}/app/src/main/res/drawable"
BROKEN=(ab_gear_0001.png ab_gear_0004.png ab_gear_0005.png ab_gear_0011.png ab_gear_0036.png ab_gear_0038.png)

[[ -d "${ASSETS_DIR}" ]] || exit 0
removed=0
for f in "${BROKEN[@]}"; do
  if [[ -f "${ASSETS_DIR}/${f}" ]]; then
    rm -f "${ASSETS_DIR}/${f}"
    printf '[winlator-assets-fix] removed %s\n' "${f}"
    removed=1
  fi
done

# Remove any remaining gear frames to avoid AAPT crunch crashes (some files are malformed PNGs).
find "${ASSETS_DIR}" -maxdepth 1 -type f -name 'ab_gear_*.png' -print -delete \
  | sed 's/^/[winlator-assets-fix] removed /'

exit 0
