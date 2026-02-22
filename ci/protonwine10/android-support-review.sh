#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${WCP_OUTPUT_DIR:-${ROOT_DIR}/out/protonwine10}"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work/protonwine10}"
LOG_DIR="${OUT_DIR}/logs/protonwine10/inspect-upstreams"
ANDROID_SUPPORT_DIR="${WORK_DIR}/upstreams/android-support"
SERIES_FILE="${LOG_DIR}/android-support-series.txt"
REVIEW_FILE="${ROOT_DIR}/docs/PROTONWINE_ANDROID_SUPPORT_REVIEW.md"
SELECTED_FILE="${LOG_DIR}/android-support-selected-commits.txt"

log() { printf '[protonwine10][review] %s\n' "$*"; }
fail() { printf '[protonwine10][review][error] %s\n' "$*" >&2; exit 1; }

commit_category() {
  local files="$1" subject_lc="$2"

  if printf '%s\n%s\n' "${subject_lc}" "${files}" | grep -Eiq 'arm64ec|wow64|loader/|dlls/ntdll/|configure'; then
    printf 'MUST'
    return
  fi

  if printf '%s\n%s\n' "${subject_lc}" "${files}" | grep -Eiq '^dlls/|^server/|^tools/|android'; then
    printf 'SHOULD'
    return
  fi

  printf 'MAY'
}

main() {
  local hash subject author date files diffstat file_count category risk purpose effect subject_lc

  [[ -d "${ANDROID_SUPPORT_DIR}" ]] || fail "Android-support repo is missing: ${ANDROID_SUPPORT_DIR}"
  [[ -s "${SERIES_FILE}" ]] || fail "Series file is missing or empty: ${SERIES_FILE}"

  mkdir -p "$(dirname "${REVIEW_FILE}")"
  : > "${SELECTED_FILE}"

  {
    echo "# ProtonWine Android Support Review"
    echo
    echo "Generated at: \`$(date -u +"%Y-%m-%dT%H:%M:%SZ")\`"
    echo
    echo "- Source: \`$(git -C "${ANDROID_SUPPORT_DIR}" remote get-url origin)\`"
    echo "- Head: \`$(git -C "${ANDROID_SUPPORT_DIR}" rev-parse --short HEAD)\`"
    echo "- Series file: \`${SERIES_FILE#${ROOT_DIR}/}\`"
    echo
    echo "## Reflective analysis"
  } > "${REVIEW_FILE}"

  while IFS= read -r hash; do
    [[ -n "${hash}" ]] || continue

    subject="$(git -C "${ANDROID_SUPPORT_DIR}" show -s --format='%s' "${hash}")"
    author="$(git -C "${ANDROID_SUPPORT_DIR}" show -s --format='%an <%ae>' "${hash}")"
    date="$(git -C "${ANDROID_SUPPORT_DIR}" show -s --format='%aI' "${hash}")"
    files="$(git -C "${ANDROID_SUPPORT_DIR}" show --name-only --pretty=format: "${hash}" | sed '/^$/d')"
    diffstat="$(git -C "${ANDROID_SUPPORT_DIR}" show --stat --format= "${hash}")"
    file_count="$(printf '%s\n' "${files}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"

    subject_lc="$(printf '%s' "${subject}" | tr '[:upper:]' '[:lower:]')"
    category="$(commit_category "${files}" "${subject_lc}")"

    risk="LOW"
    if printf '%s\n' "${files}" | grep -Eiq '^loader/|^dlls/ntdll/|wow64'; then
      risk="MED"
    fi
    if [[ "${file_count}" -gt 40 ]] && [[ "${risk}" == "MED" ]]; then
      risk="HIGH"
      category="RISKY"
    fi

    if printf '%s\n%s\n' "${subject_lc}" "${files}" | grep -Eiq 'android'; then
      purpose="Adds or adjusts Android support logic in proton-wine."
    elif printf '%s\n%s\n' "${subject_lc}" "${files}" | grep -Eiq 'wow64|arm64ec'; then
      purpose="Improves ARM64EC/WoW64 compatibility."
    else
      purpose="Applies runtime or foundation compatibility support."
    fi

    case "${category}" in
      MUST) effect="Critical for the target profile and should be carried over." ;;
      SHOULD) effect="Recommended for stability/compatibility when conflict-free." ;;
      RISKY) effect="Potentially useful but high conflict risk; require separate validation." ;;
      *) effect="Optional carry-over; no direct blocker if skipped." ;;
    esac

    if [[ "${category}" == "MUST" || "${category}" == "SHOULD" ]]; then
      printf '%s\n' "${hash}" >> "${SELECTED_FILE}"
    fi

    {
      echo
      echo "### ${subject}"
      echo
      echo "- Hash: \`${hash}\`"
      echo "- Author: \`${author}\`"
      echo "- Date: \`${date}\`"
      echo "- Category: \`${category}\`"
      echo "- Risk: \`${risk}\`"
      echo "- Purpose: ${purpose}"
      echo "- Applicability: ${effect}"
      echo
      echo "#### Diffstat"
      echo
      echo '```text'
      echo "${diffstat}"
      echo '```'
      echo
      echo "#### Files"
      printf '%s\n' "${files}" | sed 's#^#- `#;s#$#`#'
      echo
    } >> "${REVIEW_FILE}"
  done < "${SERIES_FILE}"

  log "Review generated: ${REVIEW_FILE}"
  log "Selected commits (MUST/SHOULD): ${SELECTED_FILE}"
}

main "$@"
