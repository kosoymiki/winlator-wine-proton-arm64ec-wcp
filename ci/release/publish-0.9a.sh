#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO="${GITHUB_REPOSITORY:-$(git -C "${ROOT_DIR}" config --get remote.origin.url | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')}"
APPLY=0
WINLATOR_TAG="v0.9a"
WCP_TAG="wcp-v0.9a"
WINLATOR_NOTES="${ROOT_DIR}/out/release-notes/winlator-v0.9a.md"
WCP_NOTES="${ROOT_DIR}/out/release-notes/wcp-v0.9a.md"
STAGE_DIR="${ROOT_DIR}/out/release-staging"
WINLATOR_ASSETS=("${ROOT_DIR}/out/winlator"/*.apk "${ROOT_DIR}/out/winlator/SHA256SUMS")
WCP_ASSETS=()

log() { printf '[release-publish] %s\n' "$*"; }
fail() { printf '[release-publish][error] %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<USAGE
Usage: bash ci/release/publish-0.9a.sh [--apply] [--repo owner/repo] [--winlator-tag TAG] [--wcp-tag TAG]

Publishes or updates the stable 0.9a releases (dry-run by default).
USAGE
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --repo) REPO="$2"; shift ;;
    --winlator-tag) WINLATOR_TAG="$2"; shift ;;
    --wcp-tag) WCP_TAG="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
  shift
done

command -v gh >/dev/null 2>&1 || fail "gh CLI is required"
[[ -f "${WINLATOR_NOTES}" ]] || fail "Missing notes file: ${WINLATOR_NOTES} (run ci/release/prepare-0.9a-notes.sh)"
[[ -f "${WCP_NOTES}" ]] || fail "Missing notes file: ${WCP_NOTES} (run ci/release/prepare-0.9a-notes.sh)"

for f in "${WINLATOR_ASSETS[@]}"; do [[ -e "$f" ]] || fail "Missing Winlator asset: $f"; done
for f in \
  "${ROOT_DIR}/out/wine/wine-11-arm64ec.wcp" \
  "${ROOT_DIR}/out/wine/SHA256SUMS" \
  "${ROOT_DIR}/out/proton-ge10/proton-ge10-arm64ec.wcp" \
  "${ROOT_DIR}/out/proton-ge10/SHA256SUMS" \
  "${ROOT_DIR}/out/protonwine10/protonwine10-gamenative-arm64ec.wcp" \
  "${ROOT_DIR}/out/protonwine10/SHA256SUMS"; do
  [[ -e "$f" ]] || fail "Missing WCP asset: $f"
done

mkdir -p "${STAGE_DIR}/wcp-v0.9a"
cp -f "${ROOT_DIR}/out/wine/wine-11-arm64ec.wcp" "${STAGE_DIR}/wcp-v0.9a/"
cp -f "${ROOT_DIR}/out/proton-ge10/proton-ge10-arm64ec.wcp" "${STAGE_DIR}/wcp-v0.9a/"
cp -f "${ROOT_DIR}/out/protonwine10/protonwine10-gamenative-arm64ec.wcp" "${STAGE_DIR}/wcp-v0.9a/"
cp -f "${ROOT_DIR}/out/wine/SHA256SUMS" "${STAGE_DIR}/wcp-v0.9a/SHA256SUMS-wine-11-arm64ec.txt"
cp -f "${ROOT_DIR}/out/proton-ge10/SHA256SUMS" "${STAGE_DIR}/wcp-v0.9a/SHA256SUMS-proton-ge10-arm64ec.txt"
cp -f "${ROOT_DIR}/out/protonwine10/SHA256SUMS" "${STAGE_DIR}/wcp-v0.9a/SHA256SUMS-protonwine10-gamenative-arm64ec.txt"
WCP_ASSETS=(
  "${STAGE_DIR}/wcp-v0.9a/wine-11-arm64ec.wcp"
  "${STAGE_DIR}/wcp-v0.9a/proton-ge10-arm64ec.wcp"
  "${STAGE_DIR}/wcp-v0.9a/protonwine10-gamenative-arm64ec.wcp"
  "${STAGE_DIR}/wcp-v0.9a/SHA256SUMS-wine-11-arm64ec.txt"
  "${STAGE_DIR}/wcp-v0.9a/SHA256SUMS-proton-ge10-arm64ec.txt"
  "${STAGE_DIR}/wcp-v0.9a/SHA256SUMS-protonwine10-gamenative-arm64ec.txt"
)

log "Repository: ${REPO}"
log "Winlator tag: ${WINLATOR_TAG}"
log "WCP tag: ${WCP_TAG}"
log "Winlator assets: ${#WINLATOR_ASSETS[@]}"
log "WCP assets: ${#WCP_ASSETS[@]}"

if [[ "${APPLY}" != "1" ]]; then
  log "Dry-run only. Re-run with --apply to publish releases."
  exit 0
fi

if gh release view "${WCP_TAG}" --repo "${REPO}" >/dev/null 2>&1; then
  gh release edit "${WCP_TAG}" --repo "${REPO}" --title "WCP Bundle 0.9a (Wine/Proton ARM64EC)" --notes-file "${WCP_NOTES}"
else
  gh release create "${WCP_TAG}" --repo "${REPO}" --title "WCP Bundle 0.9a (Wine/Proton ARM64EC)" --notes-file "${WCP_NOTES}"
fi
gh release upload "${WCP_TAG}" --repo "${REPO}" --clobber "${WCP_ASSETS[@]}"

if gh release view "${WINLATOR_TAG}" --repo "${REPO}" >/dev/null 2>&1; then
  gh release edit "${WINLATOR_TAG}" --repo "${REPO}" --title "Winlator CMOD Aero.so 0.9a" --notes-file "${WINLATOR_NOTES}"
else
  gh release create "${WINLATOR_TAG}" --repo "${REPO}" --title "Winlator CMOD Aero.so 0.9a" --notes-file "${WINLATOR_NOTES}"
fi
gh release upload "${WINLATOR_TAG}" --repo "${REPO}" --clobber "${WINLATOR_ASSETS[@]}"

log "Release publish completed."
