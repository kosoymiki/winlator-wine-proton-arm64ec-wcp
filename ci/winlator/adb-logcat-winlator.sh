#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-${ADB_TARGET:-}}"
SERIAL="${ADB_SERIAL:-}"

log() { printf '[adb-winlator] %s\n' "$*"; }
fail() { printf '[adb-winlator][error] %s\n' "$*" >&2; exit 1; }

command -v adb >/dev/null 2>&1 || fail "adb not found"

if [[ -n "${TARGET}" ]]; then
  log "Connecting to ${TARGET}"
  adb connect "${TARGET}" >/dev/null
fi

if [[ -z "${SERIAL}" ]]; then
  SERIAL="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
fi

[[ -n "${SERIAL}" ]] || fail "No active adb device"

log "Streaming logcat from ${SERIAL}"
exec adb -s "${SERIAL}" logcat -v threadtime \
  Winlator:D \
  WineInfo:D \
  ContainerManager:D \
  GuestProgramLauncherComponent:D \
  ActivityManager:I \
  AndroidRuntime:E \
  libc:E \
  *:S
