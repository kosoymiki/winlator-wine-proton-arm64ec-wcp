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

# If still any ab_gear frames remain and are PNG, nuke the whole sequence to avoid AAPT crashes.
if ls "${ASSETS_DIR}"/ab_gear_*.png >/dev/null 2>&1; then
  rm -f "${ASSETS_DIR}"/ab_gear_*.png
  printf '[winlator-assets-fix] removed remaining ab_gear PNG sequence\n'
fi

exit 0
