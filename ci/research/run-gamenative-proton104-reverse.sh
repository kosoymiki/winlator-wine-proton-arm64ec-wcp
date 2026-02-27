#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

: "${ADB_SERIAL:=edb0acd0}"
: "${WLT_PACKAGE:=by.aero.so.benchmark}"
: "${WLT_COMPARE_WINE_DIR:=/data/user/0/by.aero.so.benchmark/files/contents/Wine/11-arm64ec-1}"
: "${WCP_SOURCE:=/run/user/1000/gvfs/mtp:host=realme_CAPE-MTP__SN%3AEDB0ACD0_edb0acd0/Внутренняя память/Download/proton-10-4-arm64ec.wcp.xz}"
: "${WCP_COMPARE_SOURCE:=}"
: "${WCP_FULL_INVENTORY:=1}"
: "${WCP_INVENTORY_PREFIXES:=bin lib/wine/aarch64-unix lib/wine/aarch64-windows}"

TMP_COMPARE_DIR="$(mktemp -d /tmp/wcp_reverse_compare.XXXXXX)"
trap 'rm -rf "${TMP_COMPARE_DIR}"' EXIT

resolve_wcp_source() {
  local candidate="$1"
  local -a fallbacks=(
    "${candidate}"
    "/home/mikhail/Загрузки/proton-10-4-arm64ec.wcp.xz"
    "/tmp/proton-10-4-arm64ec.wcp.xz"
  )
  local path
  for path in "${fallbacks[@]}"; do
    [[ -f "${path}" ]] || continue
    printf '%s\n' "${path}"
    return 0
  done
  return 1
}

if ! WCP_SOURCE_RESOLVED="$(resolve_wcp_source "${WCP_SOURCE}")"; then
  echo "[reverse-wcp][error] WCP source archive not found: ${WCP_SOURCE}" >&2
  exit 1
fi
echo "[reverse-wcp] source=${WCP_SOURCE_RESOLVED}"

if [[ -n "${WCP_COMPARE_SOURCE}" ]]; then
  if [[ -d "${WCP_COMPARE_SOURCE}" ]]; then
    echo "[reverse-wcp] using local compare directory ${WCP_COMPARE_SOURCE}"
    tar -C "${WCP_COMPARE_SOURCE}" -cf - . | tar -xf - -C "${TMP_COMPARE_DIR}"
  elif [[ -f "${WCP_COMPARE_SOURCE}" ]]; then
    echo "[reverse-wcp] using archive compare source ${WCP_COMPARE_SOURCE}"
    reverse_compare_arg="${WCP_COMPARE_SOURCE}"
  else
    echo "[reverse-wcp][error] WCP_COMPARE_SOURCE not found: ${WCP_COMPARE_SOURCE}" >&2
    exit 1
  fi
else
  echo "[reverse-wcp] pulling compare package from device ${ADB_SERIAL}"
  if ! adb -s "${ADB_SERIAL}" get-state >/dev/null 2>&1; then
    echo "[reverse-wcp][error] adb device ${ADB_SERIAL} is not available (set WCP_COMPARE_SOURCE to local path/archive)" >&2
    exit 1
  fi
  adb -s "${ADB_SERIAL}" exec-out run-as "${WLT_PACKAGE}" \
    tar -C "${WLT_COMPARE_WINE_DIR}" -cf - . | tar -xf - -C "${TMP_COMPARE_DIR}"
fi

if [[ -z "${reverse_compare_arg:-}" ]]; then
  reverse_compare_arg="${TMP_COMPARE_DIR}"
fi

echo "[reverse-wcp] running reverse analysis"
reverse_args=(
  --input "${WCP_SOURCE_RESOLVED}"
  --compare "${reverse_compare_arg}"
  --output-json docs/GAMENATIVE_PROTON104_WCP_REVERSE.json
  --output-md docs/GAMENATIVE_PROTON104_WCP_REVERSE.md
)
if [[ "${WCP_FULL_INVENTORY}" == "1" ]]; then
  reverse_args+=(--full-inventory)
  for prefix in ${WCP_INVENTORY_PREFIXES}; do
    reverse_args+=(--inventory-prefix "${prefix}")
  done
fi
python3 ci/research/reverse-wcp-package.py "${reverse_args[@]}"

echo "[reverse-wcp] done"
