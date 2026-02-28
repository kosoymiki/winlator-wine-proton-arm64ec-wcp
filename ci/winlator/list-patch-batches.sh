#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_DIR="${1:-${ROOT_DIR}/ci/winlator/patches}"

: "${WINLATOR_PATCH_BATCH_PLAN_FILE:=${ROOT_DIR}/ci/winlator/patch-batch-plan.tsv}"
: "${WINLATOR_PATCH_BATCH_PHASE:=}"
: "${WINLATOR_PATCH_BATCH_PROFILE:=custom}"
: "${WINLATOR_PATCH_BATCH_SIZE:=5}"
: "${WINLATOR_PATCH_BATCH_FIRST:=1}"
: "${WINLATOR_PATCH_BATCH_LAST:=0}"

fail() { printf '[patch-batch-list][error] %s\n' "$*" >&2; exit 1; }

[[ -d "${PATCH_DIR}" ]] || fail "Patch dir not found: ${PATCH_DIR}"
[[ -f "${WINLATOR_PATCH_BATCH_PLAN_FILE}" ]] || fail "Plan file not found: ${WINLATOR_PATCH_BATCH_PLAN_FILE}"
[[ "${WINLATOR_PATCH_BATCH_PROFILE}" =~ ^(custom|standard|wide|single)$ ]] || fail "WINLATOR_PATCH_BATCH_PROFILE must be custom, standard, wide or single"
[[ "${WINLATOR_PATCH_BATCH_SIZE}" =~ ^[0-9]+$ ]] || fail "WINLATOR_PATCH_BATCH_SIZE must be numeric"
[[ "${WINLATOR_PATCH_BATCH_FIRST}" =~ ^[0-9]+$ ]] || fail "WINLATOR_PATCH_BATCH_FIRST must be numeric"
[[ "${WINLATOR_PATCH_BATCH_LAST}" =~ ^[0-9]+$ ]] || fail "WINLATOR_PATCH_BATCH_LAST must be numeric"

case "${WINLATOR_PATCH_BATCH_PROFILE}" in
  standard) WINLATOR_PATCH_BATCH_SIZE=5 ;;
  wide) WINLATOR_PATCH_BATCH_SIZE=7 ;;
  single) WINLATOR_PATCH_BATCH_SIZE=1 ;;
esac

(( 10#${WINLATOR_PATCH_BATCH_SIZE} > 0 )) || fail "WINLATOR_PATCH_BATCH_SIZE must be > 0"
(( 10#${WINLATOR_PATCH_BATCH_FIRST} > 0 )) || fail "WINLATOR_PATCH_BATCH_FIRST must be > 0"

mapfile -t patch_names < <(find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' -printf '%f\n' | sort)
(( ${#patch_names[@]} > 0 )) || fail "No patch files found in ${PATCH_DIR}"

patch_count="${#patch_names[@]}"
if [[ -n "${WINLATOR_PATCH_BATCH_PHASE}" ]]; then
  declare -A phase_map=()
  while IFS='=' read -r key value; do
    phase_map["${key}"]="${value}"
  done < <(bash "${ROOT_DIR}/ci/winlator/resolve-patch-phase.sh" "${WINLATOR_PATCH_BATCH_PHASE}" "${WINLATOR_PATCH_BATCH_PLAN_FILE}")
  first=$((10#${phase_map[first]}))
  last=$((10#${phase_map[last]}))
else
  first=$((10#${WINLATOR_PATCH_BATCH_FIRST}))
  last=$((10#${WINLATOR_PATCH_BATCH_LAST}))
fi
if (( last == 0 )); then
  last="${patch_count}"
fi

(( first <= patch_count )) || fail "WINLATOR_PATCH_BATCH_FIRST exceeds patch count (${patch_count})"
(( last >= first )) || fail "WINLATOR_PATCH_BATCH_LAST must be >= WINLATOR_PATCH_BATCH_FIRST"
(( last <= patch_count )) || fail "WINLATOR_PATCH_BATCH_LAST exceeds patch count (${patch_count})"

printf 'batch\tfirst_idx\tlast_idx\tfirst_patch\tlast_patch\tsize\n'
idx="${first}"
batch_no=0
while (( idx <= last )); do
  batch_no=$((batch_no + 1))
  end=$((idx + 10#${WINLATOR_PATCH_BATCH_SIZE} - 1))
  if (( end > last )); then
    end="${last}"
  fi
  first_name="${patch_names[$((idx - 1))]}"
  last_name="${patch_names[$((end - 1))]}"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${batch_no}" "${idx}" "${end}" "${first_name}" "${last_name}" "$((end - idx + 1))"
  idx=$((end + 1))
done
