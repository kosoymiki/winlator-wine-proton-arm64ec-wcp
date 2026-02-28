#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

: "${ONLINE_COMMIT_SCAN_REPO_FILE:=ci/reverse/online_intake_repos.json}"
: "${ONLINE_COMMIT_SCAN_ALIASES:=}"
: "${ONLINE_COMMIT_SCAN_PROFILE:=core}"
: "${ONLINE_COMMIT_SCAN_COMMITS_PER_REPO:=12}"
: "${ONLINE_COMMIT_SCAN_MARKERS:=x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION,ContentProfile,REMOTE_PROFILES,WINEDEBUG,MESA_VK_WSI_PRESENT_MODE,TU_DEBUG,DXVK,VKD3D,D8VK,DXVK_NVAPI,WINE_FULLSCREEN_FSR,WINE_FULLSCREEN_FSR_STRENGTH,WINE_FULLSCREEN_FSR_MODE,VKBASALT_CONFIG}"
: "${ONLINE_COMMIT_SCAN_RETRIES:=3}"
: "${ONLINE_COMMIT_SCAN_RETRY_DELAY_SEC:=1.5}"
: "${ONLINE_COMMIT_SCAN_OUT_DIR:=docs/reverse/online-intake}"

[[ "${ONLINE_COMMIT_SCAN_PROFILE}" =~ ^(core|all|custom)$ ]] || {
  echo "[online-commit-scan][error] ONLINE_COMMIT_SCAN_PROFILE must be core|all|custom" >&2
  exit 1
}

if [[ "${ONLINE_COMMIT_SCAN_PROFILE}" == "core" && -z "${ONLINE_COMMIT_SCAN_ALIASES}" ]]; then
  ONLINE_COMMIT_SCAN_ALIASES="coffin_winlator,coffin_wine,gamenative_protonwine,froggingfamily_wine_tkg_git,utkarsh_gamenative,termux_x11,olegos2_mobox,ilya114_box64droid,ahmad1abbadi_darkos"
fi
if [[ "${ONLINE_COMMIT_SCAN_PROFILE}" == "all" ]]; then
  ONLINE_COMMIT_SCAN_ALIASES=""
fi
if [[ "${ONLINE_COMMIT_SCAN_PROFILE}" == "custom" && -z "${ONLINE_COMMIT_SCAN_ALIASES}" ]]; then
  echo "[online-commit-scan][error] ONLINE_COMMIT_SCAN_PROFILE=custom requires ONLINE_COMMIT_SCAN_ALIASES" >&2
  exit 1
fi

python3 ci/reverse/online_commit_scan.py \
  --repo-file "${ONLINE_COMMIT_SCAN_REPO_FILE}" \
  --aliases "${ONLINE_COMMIT_SCAN_ALIASES}" \
  --commits-per-repo "${ONLINE_COMMIT_SCAN_COMMITS_PER_REPO}" \
  --markers "${ONLINE_COMMIT_SCAN_MARKERS}" \
  --gh-retries "${ONLINE_COMMIT_SCAN_RETRIES}" \
  --gh-retry-delay-sec "${ONLINE_COMMIT_SCAN_RETRY_DELAY_SEC}" \
  --out-json "${ONLINE_COMMIT_SCAN_OUT_DIR}/commit-scan.json" \
  --out-md "${ONLINE_COMMIT_SCAN_OUT_DIR}/commit-scan.md"
