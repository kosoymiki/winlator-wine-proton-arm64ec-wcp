#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible entrypoint.
# Legacy callers can still invoke ci/proton10/ci-build-proton10-wcp.sh,
# while the canonical implementation now lives under ci/proton-ge10/.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WCP_NAME:=proton-ge10-arm64ec}"
: "${WCP_OUTPUT_DIR:=${ROOT_DIR}/out/proton-ge10}"

exec bash "${ROOT_DIR}/ci/proton-ge10/ci-build-proton-ge10-wcp.sh" "$@"
