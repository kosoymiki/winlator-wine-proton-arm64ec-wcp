#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-${ROOT_DIR}/out/release-notes}"
mkdir -p "${OUT_DIR}"

cp "${ROOT_DIR}/ci/release/templates/winlator-v0.2b.ru-en.md" "${OUT_DIR}/winlator-v0.2b.md"
cp "${ROOT_DIR}/ci/release/templates/wcp-v0.2b.ru-en.md" "${OUT_DIR}/wcp-v0.2b.md"

{
  echo
  echo "Build metadata"
  echo "- Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "- Commit: $(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
} >> "${OUT_DIR}/winlator-v0.2b.md"

{
  echo
  echo "Build metadata"
  echo "- Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "- Commit: $(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
} >> "${OUT_DIR}/wcp-v0.2b.md"

printf '[release-notes] Wrote %s and %s\n' "${OUT_DIR}/winlator-v0.2b.md" "${OUT_DIR}/wcp-v0.2b.md"
