#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_PACKAGE:=by.aero.so.benchmark}"
: "${WLT_HOME_ROOT:=files/imagefs/home}"
: "${WLT_SEED_CONTAINER_ID:=1}"
: "${WLT_TARGET_CONTAINERS:=2 3 4}"
: "${WLT_OVERWRITE:=1}"
: "${WLT_CONTAINER_PROFILE_MAP:=}"
: "${WLT_OUT_DIR:=/tmp/winlator-seed-matrix-$(date +%Y%m%d_%H%M%S)}"

log() { printf '[adb-seed] %s\n' "$*"; }
fail() { printf '[adb-seed][error] %s\n' "$*" >&2; exit 1; }

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

declare -A PROFILE_SPEC

parse_profile_map() {
  local spec token cid kv
  [[ -n "${WLT_CONTAINER_PROFILE_MAP}" ]] || return 0
  IFS=',' read -r -a token <<< "${WLT_CONTAINER_PROFILE_MAP}"
  for spec in "${token[@]}"; do
    spec="$(trim "${spec}")"
    [[ -n "${spec}" ]] || continue
    [[ "${spec}" == *:* ]] || fail "invalid WLT_CONTAINER_PROFILE_MAP entry: ${spec}"
    cid="$(trim "${spec%%:*}")"
    kv="$(trim "${spec#*:}")"
    [[ "${cid}" =~ ^[0-9]+$ ]] || fail "invalid container id in map entry: ${spec}"
    PROFILE_SPEC["${cid}"]="${kv}"
  done
}

read_container_json() {
  local cid="$1"
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'cat ${WLT_HOME_ROOT}/xuser-${cid}/.container'" 2>/dev/null
}

copy_seed_tree() {
  local dst_cid="$1"
  local cmd
  cmd=$(cat <<CMD
set -e
src='${WLT_HOME_ROOT}/xuser-${WLT_SEED_CONTAINER_ID}'
dst='${WLT_HOME_ROOT}/xuser-${dst_cid}'
[ -d "\${src}" ] || exit 41
if [ -d "\${dst}" ]; then
  if [ '${WLT_OVERWRITE}' = '1' ]; then
    rm -rf "\${dst}"
  else
    exit 42
  fi
fi
cp -a "\${src}" "\${dst}"
CMD
)
  adb_s shell "run-as ${WLT_PACKAGE} sh -c \"${cmd}\"" >/dev/null
}

update_container_json() {
  local cid="$1"
  local in_json="$2"
  local out_json="$3"
  local spec pair key value tmp

  jq --argjson id "${cid}" --arg name "Container-${cid}" '.id=$id | .name=$name' "${in_json}" > "${out_json}"

  spec="${PROFILE_SPEC[${cid}]:-}"
  [[ -n "${spec}" ]] || return 0

  IFS=';' read -r -a pair <<< "${spec}"
  for pair in "${pair[@]}"; do
    pair="$(trim "${pair}")"
    [[ -n "${pair}" ]] || continue
    [[ "${pair}" == *=* ]] || fail "invalid key=value in profile map for container ${cid}: ${pair}"
    key="$(trim "${pair%%=*}")"
    value="$(trim "${pair#*=}")"
    [[ -n "${key}" ]] || fail "empty key in profile map for container ${cid}"

    tmp="$(mktemp "${WLT_OUT_DIR}/.json.XXXXXX")"
    if [[ "${value}" =~ ^-?[0-9]+$ ]]; then
      jq --arg k "${key}" --argjson v "${value}" '.[$k]=$v' "${out_json}" > "${tmp}"
    elif [[ "${value}" =~ ^(true|false|null)$ ]]; then
      jq --arg k "${key}" --argjson v "${value}" '.[$k]=$v' "${out_json}" > "${tmp}"
    else
      jq --arg k "${key}" --arg v "${value}" '.[$k]=$v' "${out_json}" > "${tmp}"
    fi
    mv "${tmp}" "${out_json}"
  done
}

push_container_json() {
  local cid="$1"
  local src_json="$2"
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'cat > ${WLT_HOME_ROOT}/xuser-${cid}/.container'" < "${src_json}"
}

main() {
  local cid target_dir before_json_file after_json_file device_after_file

  require_cmd adb
  require_cmd jq
  require_cmd python3

  [[ "${WLT_OVERWRITE}" =~ ^[01]$ ]] || fail "WLT_OVERWRITE must be 0 or 1"
  [[ "${WLT_SEED_CONTAINER_ID}" =~ ^[0-9]+$ ]] || fail "WLT_SEED_CONTAINER_ID must be numeric"

  mkdir -p "${WLT_OUT_DIR}"
  parse_profile_map

  ADB_SERIAL_PICKED="$(pick_serial)"
  [[ -n "${ADB_SERIAL_PICKED}" ]] || fail "no active adb device"

  log "device=${ADB_SERIAL_PICKED}"
  log "package=${WLT_PACKAGE}"
  log "seed=${WLT_SEED_CONTAINER_ID}"
  log "targets=${WLT_TARGET_CONTAINERS}"

  if ! read_container_json "${WLT_SEED_CONTAINER_ID}" > "${WLT_OUT_DIR}/seed-container.json"; then
    fail "unable to read seed container xuser-${WLT_SEED_CONTAINER_ID}"
  fi

  for cid in ${WLT_TARGET_CONTAINERS}; do
    [[ "${cid}" =~ ^[0-9]+$ ]] || fail "target container id must be numeric: ${cid}"
    [[ "${cid}" != "${WLT_SEED_CONTAINER_ID}" ]] || fail "target container cannot equal seed id: ${cid}"

    target_dir="${WLT_OUT_DIR}/container-${cid}"
    mkdir -p "${target_dir}"
    before_json_file="${target_dir}/before.json"
    after_json_file="${target_dir}/after.json"
    device_after_file="${target_dir}/device-after.json"

    read_container_json "${cid}" > "${before_json_file}" 2>/dev/null || true

    copy_seed_tree "${cid}"

    if ! read_container_json "${cid}" > "${target_dir}/seed-copy.json"; then
      fail "failed reading copied container xuser-${cid}"
    fi

    update_container_json "${cid}" "${target_dir}/seed-copy.json" "${after_json_file}"
    push_container_json "${cid}" "${after_json_file}"

    if ! read_container_json "${cid}" > "${device_after_file}"; then
      fail "failed reading updated container xuser-${cid}"
    fi

    if ! diff -u "${after_json_file}" "${device_after_file}" > "${target_dir}/after.diff"; then
      fail "device json mismatch after update for xuser-${cid} (see ${target_dir}/after.diff)"
    fi

    log "seeded xuser-${cid}"
  done

  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'find ${WLT_HOME_ROOT} -maxdepth 2 -type f -name .container | sort'" \
    > "${WLT_OUT_DIR}/containers-index.txt" 2>/dev/null || true

  printf 'serial=%s\npackage=%s\nseed=%s\ntargets=%s\ntime=%s\n' \
    "${ADB_SERIAL_PICKED}" "${WLT_PACKAGE}" "${WLT_SEED_CONTAINER_ID}" "${WLT_TARGET_CONTAINERS}" "$(date -Is)" \
    > "${WLT_OUT_DIR}/session-meta.txt"

  log "done: ${WLT_OUT_DIR}"
}

main "$@"
