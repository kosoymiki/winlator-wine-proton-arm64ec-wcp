#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

python3 ci/research/gamenative_forensic_audit.py "$@"
python3 ci/research/gamehub_provenance_audit.py

echo "[upstream-audits] Generated:"
echo "  - docs/GAMENATIVE_BRANCH_AUDIT_LOG.md"
echo "  - docs/GAMEHUB_PROVENANCE_REPORT.md"
echo "  - docs/research/*.json"
