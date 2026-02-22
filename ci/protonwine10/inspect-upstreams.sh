#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${WCP_OUTPUT_DIR:-${ROOT_DIR}/out/protonwine10}"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work/protonwine10}"
LOG_DIR="${OUT_DIR}/logs/protonwine10/inspect-upstreams"
UPSTREAM_WORK_DIR="${WORK_DIR}/upstreams"
GAME_NATIVE_DIR="${UPSTREAM_WORK_DIR}/gamenative"
ANDROID_SUPPORT_DIR="${UPSTREAM_WORK_DIR}/android-support"

: "${PROTONWINE_REPO:=https://github.com/GameNative/proton-wine.git}"
: "${PROTONWINE_REF:=e7dbb4a10b85c1e8d505068d36249127d8b7fe79}"
: "${ANDROID_SUPPORT_REPO:=https://github.com/sidaodomorro/proton-wine.git}"
: "${ANDROID_SUPPORT_REF:=47e79a66652afae9fd0e521b03736d1e6536ac5a}"
: "${PROTONWINE_ANDROID_SUPPORT_ROOT:=}"

log() { printf '[protonwine10][inspect] %s\n' "$*"; }
fail() { printf '[protonwine10][inspect][error] %s\n' "$*" >&2; exit 1; }

main() {
  local root_commit merge_base series_file summary_file diffstat_file count

  mkdir -p "${LOG_DIR}" "${UPSTREAM_WORK_DIR}"
  rm -rf "${GAME_NATIVE_DIR}" "${ANDROID_SUPPORT_DIR}"

  log "Cloning GameNative source (${PROTONWINE_REF})"
  git clone --filter=blob:none --no-checkout "${PROTONWINE_REPO}" "${GAME_NATIVE_DIR}"
  git -C "${GAME_NATIVE_DIR}" fetch --no-tags origin "${PROTONWINE_REF}"
  git -C "${GAME_NATIVE_DIR}" checkout --detach "${PROTONWINE_REF}"

  log "Cloning Android-support source (${ANDROID_SUPPORT_REF})"
  git clone --filter=blob:none --no-checkout "${ANDROID_SUPPORT_REPO}" "${ANDROID_SUPPORT_DIR}"
  git -C "${ANDROID_SUPPORT_DIR}" fetch --no-tags origin "${ANDROID_SUPPORT_REF}"
  git -C "${ANDROID_SUPPORT_DIR}" checkout --detach "${ANDROID_SUPPORT_REF}"

  if [[ -n "${PROTONWINE_ANDROID_SUPPORT_ROOT}" ]]; then
    root_commit="${PROTONWINE_ANDROID_SUPPORT_ROOT}"
  else
    root_commit="$(git -C "${ANDROID_SUPPORT_DIR}" log --regexp-ignore-case --grep='add android support' --format='%H' -n1 "${ANDROID_SUPPORT_REF}" || true)"
  fi
  [[ -n "${root_commit}" ]] || fail "Unable to find Android support root commit"
  git -C "${ANDROID_SUPPORT_DIR}" cat-file -e "${root_commit}^{commit}" || fail "Android support root commit is invalid: ${root_commit}"

  git -C "${ANDROID_SUPPORT_DIR}" merge-base --is-ancestor "${root_commit}" "${ANDROID_SUPPORT_REF}" \
    || fail "Android support root commit is not ancestor of ${ANDROID_SUPPORT_REF}"

  merge_base="$(git -C "${ANDROID_SUPPORT_DIR}" merge-base "${root_commit}" "${ANDROID_SUPPORT_REF}")"

  series_file="${LOG_DIR}/android-support-series.txt"
  diffstat_file="${LOG_DIR}/android-support-diffstat.txt"
  summary_file="${LOG_DIR}/summary.txt"

  git -C "${ANDROID_SUPPORT_DIR}" rev-list --reverse "${root_commit}^..${ANDROID_SUPPORT_REF}" > "${series_file}"
  count="$(wc -l < "${series_file}" | tr -d '[:space:]')"
  [[ "${count}" != "0" ]] || fail "Android support series is empty"

  : > "${diffstat_file}"
  while IFS= read -r commit; do
    [[ -n "${commit}" ]] || continue
    {
      echo "== ${commit} =="
      git -C "${ANDROID_SUPPORT_DIR}" show -s --format='%h %s (%aI)' "${commit}"
      git -C "${ANDROID_SUPPORT_DIR}" show --stat --format= "${commit}"
      echo
    } >> "${diffstat_file}"
  done < "${series_file}"

  {
    echo "protonwine_repo=${PROTONWINE_REPO}"
    echo "protonwine_ref=${PROTONWINE_REF}"
    echo "android_support_repo=${ANDROID_SUPPORT_REPO}"
    echo "android_support_ref=${ANDROID_SUPPORT_REF}"
    echo "android_support_root=${root_commit}"
    echo "android_support_merge_base=${merge_base}"
    echo "android_support_commit_count=${count}"
    echo "series_file=${series_file}"
    echo "diffstat_file=${diffstat_file}"
  } > "${summary_file}"

  cp -f "${series_file}" "${OUT_DIR}/android-support-series.txt"
  log "Android support root: ${root_commit}"
  log "Series commits: ${count}"
  log "Summary: ${summary_file}"
}

main "$@"
