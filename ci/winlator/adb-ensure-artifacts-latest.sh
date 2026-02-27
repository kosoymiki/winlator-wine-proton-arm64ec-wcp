#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_PACKAGE:=by.aero.so.benchmark}"
: "${WLT_SOURCE_MAP:=${ROOT_DIR}/ci/winlator/artifact-source-map.json}"
: "${WLT_TARGET_KEYS:=wine11 protonwine10 protonge10 gamenative104}"
: "${WLT_INSTALL_TARGET:=run_as_contents}"
: "${WLT_FORCE_REINSTALL:=1}"
: "${WLT_OUT_DIR:=/tmp/winlator-artifacts-latest-$(date +%Y%m%d_%H%M%S)}"

log() { printf '[adb-artifacts] %s\n' "$*"; }
warn() { printf '[adb-artifacts][warn] %s\n' "$*" >&2; }
fail() { printf '[adb-artifacts][error] %s\n' "$*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }

pick_serial() {
  local serial
  serial="${ADB_SERIAL:-}"
  if [[ -n "${serial}" ]]; then
    printf '%s\n' "${serial}"
    return 0
  fi
  adb devices | awk 'NR>1 && $2=="device" {print $1; exit}'
}

adb_s() { adb -s "${ADB_SERIAL_PICKED}" "$@"; }

trim() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "${s}"
}

download_with_retries() {
  local url="$1"
  local out="$2"
  curl -fL --retry 3 --retry-all-errors --connect-timeout 20 --max-time 0 -A "Aero.solator artifact sync/0.9c+" -o "${out}" "${url}"
}

extract_archive() {
  local archive="$1"
  local out_dir="$2"
  rm -rf "${out_dir}"
  mkdir -p "${out_dir}"

  if tar -xf "${archive}" -C "${out_dir}" >/dev/null 2>&1; then
    return 0
  fi
  if tar -xJf "${archive}" -C "${out_dir}" >/dev/null 2>&1; then
    return 0
  fi
  if tar --zstd -xf "${archive}" -C "${out_dir}" >/dev/null 2>&1; then
    return 0
  fi
  fail "cannot extract archive: ${archive}"
}

resolve_expected_sha() {
  local sha_file="$1"
  local asset_name="$2"
  python3 - "${sha_file}" "${asset_name}" <<'PY'
import re
import sys
from pathlib import Path

sha_file = Path(sys.argv[1])
asset_name = sys.argv[2]
text = sha_file.read_text(encoding="utf-8", errors="ignore").splitlines()
for line in text:
    m = re.match(r"\s*([0-9a-fA-F]{64})\s+\*?(\S+)\s*$", line)
    if not m:
        continue
    digest, name = m.group(1).lower(), m.group(2)
    if name == asset_name or name.endswith("/" + asset_name):
        print(digest)
        raise SystemExit(0)
print("")
PY
}

verify_sha_if_available() {
  local asset="$1"
  local sha_url="$2"
  local sha_file="$3"
  [[ -n "${sha_url}" ]] || return 0

  download_with_retries "${sha_url}" "${sha_file}"
  local asset_name expected actual
  asset_name="$(basename -- "${asset}")"
  expected="$(resolve_expected_sha "${sha_file}" "${asset_name}")"
  [[ -n "${expected}" ]] || {
    warn "sha entry not found for ${asset_name} in $(basename -- "${sha_file}")"
    return 0
  }
  actual="$(sha256sum "${asset}" | awk '{print $1}')"
  [[ "${actual}" == "${expected}" ]] || fail "sha mismatch for ${asset_name}: expected=${expected} actual=${actual}"
}

install_wcp_to_device() {
  local stage_dir="$1"
  local content_type="$2"
  local content_name="$3"
  local device_dir="files/contents/${content_type}/${content_name}"

  if [[ "${WLT_FORCE_REINSTALL}" == "1" ]]; then
    adb_s shell "run-as ${WLT_PACKAGE} sh -c 'rm -rf ${device_dir}'" >/dev/null
  else
    if adb_s shell "run-as ${WLT_PACKAGE} sh -c 'test -f ${device_dir}/profile.json'" >/dev/null 2>&1; then
      log "skip existing ${device_dir} (WLT_FORCE_REINSTALL=0)"
      return 0
    fi
  fi

  tar -C "${stage_dir}" -cf - . | \
    adb_s shell "run-as ${WLT_PACKAGE} sh -c 'mkdir -p ${device_dir} && tar -xf - -C ${device_dir}'"

  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'test -f ${device_dir}/profile.json'" >/dev/null \
    || fail "installed profile missing in ${device_dir}"
}

main() {
  local key artifact_json kind remote_url sha_url description
  local download_path sha_path stage_dir profile_path type_name content_name summary_line

  require_cmd jq
  require_cmd python3
  require_cmd curl
  require_cmd tar

  [[ -f "${WLT_SOURCE_MAP}" ]] || fail "source map not found: ${WLT_SOURCE_MAP}"
  [[ "${WLT_FORCE_REINSTALL}" =~ ^[01]$ ]] || fail "WLT_FORCE_REINSTALL must be 0 or 1"

  if [[ "${WLT_INSTALL_TARGET}" == "run_as_contents" ]]; then
    require_cmd adb
    ADB_SERIAL_PICKED="$(pick_serial)"
    [[ -n "${ADB_SERIAL_PICKED}" ]] || fail "no active adb device"
    log "device=${ADB_SERIAL_PICKED} package=${WLT_PACKAGE}"
  fi

  mkdir -p "${WLT_OUT_DIR}/downloads" "${WLT_OUT_DIR}/stage"
  : > "${WLT_OUT_DIR}/summary.tsv"
  printf 'key\tkind\turl\tsha256\tinstall\tcontent_type\tcontent_name\n' >> "${WLT_OUT_DIR}/summary.tsv"

  for key in ${WLT_TARGET_KEYS}; do
    key="$(trim "${key}")"
    [[ -n "${key}" ]] || continue

    artifact_json="$(jq -c --arg k "${key}" '.artifacts[$k] // empty' "${WLT_SOURCE_MAP}")"
    [[ -n "${artifact_json}" ]] || fail "key not found in source map: ${key}"

    kind="$(jq -r '.kind // "wcp"' <<< "${artifact_json}")"
    remote_url="$(jq -r '.remoteUrl // empty' <<< "${artifact_json}")"
    sha_url="$(jq -r '.sha256Url // empty' <<< "${artifact_json}")"
    description="$(jq -r '.description // ""' <<< "${artifact_json}")"

    [[ -n "${remote_url}" ]] || fail "remoteUrl missing for key ${key}"
    log "sync ${key}: ${description:-no-description}"

    download_path="${WLT_OUT_DIR}/downloads/${key}-$(basename -- "${remote_url%%\?*}")"
    sha_path="${WLT_OUT_DIR}/downloads/${key}.sha256.txt"

    download_with_retries "${remote_url}" "${download_path}"
    verify_sha_if_available "${download_path}" "${sha_url}" "${sha_path}"

    if [[ "${kind}" != "wcp" ]]; then
      warn "unsupported kind=${kind} for ${key}; downloaded only"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${key}" "${kind}" "${remote_url}" "-" "download-only" "-" "-" >> "${WLT_OUT_DIR}/summary.tsv"
      continue
    fi

    stage_dir="${WLT_OUT_DIR}/stage/${key}"
    extract_archive "${download_path}" "${stage_dir}"

    profile_path="$(find "${stage_dir}" -maxdepth 3 -type f -name profile.json | head -n1 || true)"
    [[ -n "${profile_path}" ]] || fail "profile.json missing after extract for ${key}"

    type_name="$(jq -r '.type // empty' "${profile_path}")"
    content_name="$(jq -r '.name // empty' "${profile_path}")"
    [[ -n "${type_name}" ]] || fail "type missing in profile.json for ${key}"
    [[ -n "${content_name}" ]] || fail "name missing in profile.json for ${key}"

    if [[ "${WLT_INSTALL_TARGET}" == "run_as_contents" ]]; then
      install_wcp_to_device "${stage_dir}" "${type_name}" "${content_name}"
      summary_line="installed"
    else
      summary_line="staged"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${key}" "${kind}" "${remote_url}" "$(sha256sum "${download_path}" | awk '{print $1}')" "${summary_line}" "${type_name}" "${content_name}" >> "${WLT_OUT_DIR}/summary.tsv"
  done

  if [[ "${WLT_INSTALL_TARGET}" == "run_as_contents" ]]; then
    adb_s shell "run-as ${WLT_PACKAGE} sh -c 'for f in files/contents/Wine/*/profile.json; do [ -f \"\$f\" ] || continue; echo ===== \$f =====; cat \"\$f\"; echo; done'" \
      > "${WLT_OUT_DIR}/device-wine-profiles.txt" 2>/dev/null || true
  fi

  printf 'time=%s\nsource_map=%s\nkeys=%s\ninstall_target=%s\nforce_reinstall=%s\n' \
    "$(date -Is)" "${WLT_SOURCE_MAP}" "${WLT_TARGET_KEYS}" "${WLT_INSTALL_TARGET}" "${WLT_FORCE_REINSTALL}" \
    > "${WLT_OUT_DIR}/session-meta.txt"

  log "done: ${WLT_OUT_DIR}"
}

main "$@"
