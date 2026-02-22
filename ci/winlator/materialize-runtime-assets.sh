#!/usr/bin/env bash
set -euo pipefail

ASSETS_DIR="${1:-}"
WORK_DIR="${2:-}"

log() { printf '[winlator-assets] %s\n' "$*"; }
fail() { printf '[winlator-assets][error] %s\n' "$*" >&2; exit 1; }

[[ -n "${ASSETS_DIR}" ]] || fail "usage: $0 <assets-dir> [work-dir]"

: "${RUNTIME_RELEASE_REPO:=kosoymiki/winlator-wine-proton-arm64ec-wcp}"
: "${RUNTIME_RELEASE_TAG:=wcp-latest}"

if [[ -z "${WORK_DIR}" ]]; then
  WORK_DIR="$(mktemp -d)"
  CLEANUP_WORK_DIR=1
else
  mkdir -p "${WORK_DIR}"
  CLEANUP_WORK_DIR=0
fi

cleanup() {
  if [[ "${CLEANUP_WORK_DIR}" == "1" ]]; then
    rm -rf "${WORK_DIR}"
  fi
}
trap cleanup EXIT

mkdir -p "${ASSETS_DIR}" "${WORK_DIR}/downloads" "${WORK_DIR}/extract"

api_url="https://api.github.com/repos/${RUNTIME_RELEASE_REPO}/releases/tags/${RUNTIME_RELEASE_TAG}"
release_json="${WORK_DIR}/release.json"

curl_args=(--fail --location --retry 5 --retry-delay 2 -H "Accept: application/vnd.github+json")
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_args+=( -H "Authorization: Bearer ${GITHUB_TOKEN}" )
fi

log "Fetching release metadata: ${RUNTIME_RELEASE_REPO} (${RUNTIME_RELEASE_TAG})"
curl "${curl_args[@]}" "${api_url}" -o "${release_json}"

required_map_json='{"wine-11.1-arm64ec.wcp":"wine-11.1-arm64ec.txz","proton-ge10-arm64ec.wcp":"proton-ge10-arm64ec.txz","protonwine10-gamenative-arm64ec.wcp":"protonwine10-gamenative-arm64ec.txz"}'

python3 - "$release_json" "$required_map_json" "$WORK_DIR/assets.tsv" <<'PY'
import json
import pathlib
import sys

release_path = pathlib.Path(sys.argv[1])
required = json.loads(sys.argv[2])
out_tsv = pathlib.Path(sys.argv[3])

release = json.loads(release_path.read_text(encoding='utf-8'))
assets = {a.get('name'): a.get('browser_download_url') for a in release.get('assets', [])}

missing = [name for name in required if name not in assets]
if missing:
    print("Missing release assets: " + ", ".join(missing), file=sys.stderr)
    sys.exit(2)

lines = []
for src, dst in required.items():
    lines.append(f"{src}\t{dst}\t{assets[src]}")
out_tsv.write_text("\n".join(lines) + "\n", encoding='utf-8')
PY

extract_archive() {
  local archive="$1" dst="$2"
  mkdir -p "${dst}"
  if tar -xJf "${archive}" -C "${dst}" >/dev/null 2>&1; then
    return 0
  fi
  if tar --zstd -xf "${archive}" -C "${dst}" >/dev/null 2>&1; then
    return 0
  fi
  tar -xf "${archive}" -C "${dst}"
}

while IFS=$'\t' read -r src_name dst_name src_url; do
  [[ -n "${src_name}" ]] || continue

  src_archive="${WORK_DIR}/downloads/${src_name}"
  runtime_root="${WORK_DIR}/extract/${dst_name%.txz}"

  log "Downloading ${src_name}"
  curl "${curl_args[@]}" "${src_url}" -o "${src_archive}"

  rm -rf "${runtime_root}"
  mkdir -p "${runtime_root}"
  extract_archive "${src_archive}" "${runtime_root}"

  log "Packing ${dst_name}"
  tar -cJf "${ASSETS_DIR}/${dst_name}" -C "${runtime_root}" .
done < "${WORK_DIR}/assets.tsv"

(
  cd "${ASSETS_DIR}"
  sha256sum wine-11.1-arm64ec.txz proton-ge10-arm64ec.txz protonwine10-gamenative-arm64ec.txz > embedded-runtime-SHA256SUMS
)

log "Embedded runtime assets prepared in ${ASSETS_DIR}"
