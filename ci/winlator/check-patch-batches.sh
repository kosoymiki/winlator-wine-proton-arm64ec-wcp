#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_DIR="${1:-}"
PATCH_DIR="${2:-${ROOT_DIR}/ci/winlator/patches}"
TMP_DIR=""
: "${WINLATOR_PATCH_BATCH_PLAN_FILE:=${ROOT_DIR}/ci/winlator/patch-batch-plan.tsv}"
: "${WINLATOR_PATCH_BATCH_PHASE:=}"
: "${WINLATOR_PATCH_BATCH_PROFILE:=custom}"
: "${WINLATOR_PATCH_BATCH_SIZE:=5}"
: "${WINLATOR_PATCH_BATCH_MODE:=batch}"
: "${WINLATOR_PATCH_BATCH_FIRST:=1}"
: "${WINLATOR_PATCH_BATCH_LAST:=0}"
: "${WINLATOR_PATCH_BATCH_KEEP_CLONE:=0}"
: "${WINLATOR_PATCH_BATCH_OUT_FILE:=}"

log() { printf '[patch-batch] %s\n' "$*"; }
fail() { printf '[patch-batch][error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
usage: ci/winlator/check-patch-batches.sh <winlator-src-git-dir> [patch-dir]

Applies the Winlator patch stack in ordered batches against one clean temporary
clone. This is a lighter local flow for patch-base bring-up than the full
patch-stack audit.

Environment:
  WINLATOR_PATCH_BATCH_PLAN_FILE=...  Phase plan file used by WINLATOR_PATCH_BATCH_PHASE.
  WINLATOR_PATCH_BATCH_PHASE=         Optional named phase (overrides FIRST/LAST).
  WINLATOR_PATCH_BATCH_PROFILE=custom custom|standard|wide|single convenience profile.
  WINLATOR_PATCH_BATCH_SIZE=5       Number of patches per batch in batch mode.
  WINLATOR_PATCH_BATCH_MODE=batch   batch|single (single forces size=1).
  WINLATOR_PATCH_BATCH_FIRST=1      First 1-based patch index to apply.
  WINLATOR_PATCH_BATCH_LAST=0       Last 1-based patch index (0 = through end).
  WINLATOR_PATCH_BATCH_KEEP_CLONE=0 Keep the temp clone for manual inspection.
  WINLATOR_PATCH_BATCH_OUT_FILE=    Optional metadata output file.
EOF
}

cleanup() {
  if [[ "${WINLATOR_PATCH_BATCH_KEEP_CLONE}" == "1" ]]; then
    return 0
  fi
  [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]] && rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

[[ -n "${SRC_DIR}" ]] || { usage; exit 1; }
[[ -d "${SRC_DIR}/.git" ]] || fail "Not a git checkout: ${SRC_DIR}"
[[ -d "${PATCH_DIR}" ]] || fail "Patch dir not found: ${PATCH_DIR}"
[[ -f "${WINLATOR_PATCH_BATCH_PLAN_FILE}" ]] || fail "Plan file not found: ${WINLATOR_PATCH_BATCH_PLAN_FILE}"
[[ "${WINLATOR_PATCH_BATCH_PROFILE}" =~ ^(custom|standard|wide|single)$ ]] || fail "WINLATOR_PATCH_BATCH_PROFILE must be custom, standard, wide or single"
[[ "${WINLATOR_PATCH_BATCH_SIZE}" =~ ^[0-9]+$ ]] || fail "WINLATOR_PATCH_BATCH_SIZE must be numeric"
[[ "${WINLATOR_PATCH_BATCH_MODE}" =~ ^(batch|single)$ ]] || fail "WINLATOR_PATCH_BATCH_MODE must be batch or single"
[[ "${WINLATOR_PATCH_BATCH_FIRST}" =~ ^[0-9]+$ ]] || fail "WINLATOR_PATCH_BATCH_FIRST must be numeric"
[[ "${WINLATOR_PATCH_BATCH_LAST}" =~ ^[0-9]+$ ]] || fail "WINLATOR_PATCH_BATCH_LAST must be numeric"
[[ "${WINLATOR_PATCH_BATCH_KEEP_CLONE}" =~ ^[01]$ ]] || fail "WINLATOR_PATCH_BATCH_KEEP_CLONE must be 0 or 1"

command -v git >/dev/null 2>&1 || fail "git not found"

case "${WINLATOR_PATCH_BATCH_PROFILE}" in
  standard)
    WINLATOR_PATCH_BATCH_MODE="batch"
    WINLATOR_PATCH_BATCH_SIZE=5
    ;;
  wide)
    WINLATOR_PATCH_BATCH_MODE="batch"
    WINLATOR_PATCH_BATCH_SIZE=7
    ;;
  single)
    WINLATOR_PATCH_BATCH_MODE="single"
    WINLATOR_PATCH_BATCH_SIZE=1
    ;;
esac

if [[ "${WINLATOR_PATCH_BATCH_MODE}" == "single" ]]; then
  WINLATOR_PATCH_BATCH_SIZE=1
fi
(( 10#${WINLATOR_PATCH_BATCH_SIZE} > 0 )) || fail "WINLATOR_PATCH_BATCH_SIZE must be > 0"
(( 10#${WINLATOR_PATCH_BATCH_FIRST} > 0 )) || fail "WINLATOR_PATCH_BATCH_FIRST must be > 0"

log "Validating patch numbering contract"
bash "${ROOT_DIR}/ci/winlator/validate-patch-sequence.sh" "${PATCH_DIR}"

mapfile -t patch_names < <(find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' -printf '%f\n' | sort)
(( ${#patch_names[@]} > 0 )) || fail "No patch files found in ${PATCH_DIR}"

patch_count="${#patch_names[@]}"
phase_label=""
phase_note=""
if [[ -n "${WINLATOR_PATCH_BATCH_PHASE}" ]]; then
  declare -A phase_map=()
  while IFS='=' read -r key value; do
    phase_map["${key}"]="${value}"
  done < <(bash "${ROOT_DIR}/ci/winlator/resolve-patch-phase.sh" "${WINLATOR_PATCH_BATCH_PHASE}" "${WINLATOR_PATCH_BATCH_PLAN_FILE}")
  batch_first=$((10#${phase_map[first]}))
  batch_last=$((10#${phase_map[last]}))
  phase_label="${phase_map[phase]}"
  phase_note="${phase_map[note]}"
else
  batch_first=$((10#${WINLATOR_PATCH_BATCH_FIRST}))
  batch_last=$((10#${WINLATOR_PATCH_BATCH_LAST}))
fi
if (( batch_last == 0 )); then
  batch_last="${patch_count}"
fi

(( batch_first <= patch_count )) || fail "WINLATOR_PATCH_BATCH_FIRST exceeds patch count (${patch_count})"
(( batch_last >= batch_first )) || fail "WINLATOR_PATCH_BATCH_LAST must be >= WINLATOR_PATCH_BATCH_FIRST"
(( batch_last <= patch_count )) || fail "WINLATOR_PATCH_BATCH_LAST exceeds patch count (${patch_count})"

TMP_DIR="$(mktemp -d /tmp/winlator_patch_batch_XXXXXX)"
CLONE_DIR="${TMP_DIR}/src"

log "Creating clean local clone"
git clone -q --no-hardlinks -- "${SRC_DIR}" "${CLONE_DIR}"
git -C "${CLONE_DIR}" reset --hard -q HEAD
git -C "${CLONE_DIR}" clean -fdqx

if [[ -n "${phase_label}" ]]; then
  log "Applying phase ${phase_label}: ${batch_first}..${batch_last} (${WINLATOR_PATCH_BATCH_MODE} mode, size=${WINLATOR_PATCH_BATCH_SIZE})"
else
  log "Applying patches ${batch_first}..${batch_last} (${WINLATOR_PATCH_BATCH_MODE} mode, size=${WINLATOR_PATCH_BATCH_SIZE})"
fi

idx="${batch_first}"
batch_no=0
while (( idx <= batch_last )); do
  batch_no=$((batch_no + 1))
  end=$((idx + 10#${WINLATOR_PATCH_BATCH_SIZE} - 1))
  if (( end > batch_last )); then
    end="${batch_last}"
  fi

  first_name="${patch_names[$((idx - 1))]}"
  last_name="${patch_names[$((end - 1))]}"
  first_num="${first_name%%-*}"
  last_num="${last_name%%-*}"

  log "Batch ${batch_no}: ${first_name} .. ${last_name}"
  WINLATOR_PATCH_FROM="${first_num}" \
  WINLATOR_PATCH_TO="${last_num}" \
    bash "${ROOT_DIR}/ci/winlator/apply-repo-patches.sh" "${CLONE_DIR}" "${PATCH_DIR}"

  git -C "${CLONE_DIR}" diff --check
  idx=$((end + 1))
done

changed_files="$(git -C "${CLONE_DIR}" diff --cached --name-only | wc -l | tr -d ' ')"
log "Batch apply-check passed (${patch_count} total patches, ${changed_files} changed files in temp clone)"
if [[ -n "${WINLATOR_PATCH_BATCH_OUT_FILE}" ]]; then
  mkdir -p "$(dirname -- "${WINLATOR_PATCH_BATCH_OUT_FILE}")"
  {
    printf 'phase=%s\n' "${phase_label:-}"
    printf 'phase_note=%s\n' "${phase_note:-}"
    printf 'profile=%s\n' "${WINLATOR_PATCH_BATCH_PROFILE}"
    printf 'mode=%s\n' "${WINLATOR_PATCH_BATCH_MODE}"
    printf 'size=%s\n' "${WINLATOR_PATCH_BATCH_SIZE}"
    printf 'first=%s\n' "${batch_first}"
    printf 'last=%s\n' "${batch_last}"
    printf 'batches=%s\n' "${batch_no}"
    printf 'changed_files=%s\n' "${changed_files}"
  } > "${WINLATOR_PATCH_BATCH_OUT_FILE}"
fi
if [[ "${WINLATOR_PATCH_BATCH_KEEP_CLONE}" == "1" ]]; then
  log "Temporary clone kept at: ${CLONE_DIR}"
else
  log "Temporary clone: ${CLONE_DIR} (auto-cleanup on exit)"
fi
