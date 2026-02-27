#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

OUT_DIR="${OUT_DIR:-docs/reverse/online-intake}"
LIMIT="${LIMIT:-25}"

command -v gh >/dev/null 2>&1 || { echo "[online-intake][error] gh is required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "[online-intake][error] python3 is required" >&2; exit 1; }

echo "[online-intake] running online GitHub API intake (limit=${LIMIT})"
python3 ci/reverse/online_intake.py --out-dir "${OUT_DIR}" --limit "${LIMIT}"
echo "[online-intake] done: ${OUT_DIR}"
