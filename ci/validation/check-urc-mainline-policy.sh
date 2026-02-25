#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { printf '[urc-check] %s\n' "$*"; }
fail() { printf '[urc-check][error] %s\n' "$*" >&2; exit 1; }

require_file() {
  [[ -f "$1" ]] || fail "Missing file: $1"
}

require_contains() {
  local file="$1" pattern="$2"
  grep -qE "${pattern}" "${file}" || fail "Missing pattern '${pattern}' in ${file}"
}

require_not_contains() {
  local file="$1" pattern="$2"
  if grep -qE "${pattern}" "${file}"; then
    fail "Forbidden pattern '${pattern}' found in ${file}"
  fi
}

detect_winlator_release_line() {
  local patch
  patch="$(ls ci/winlator/patches/0007-aeroso-version-*.patch 2>/dev/null | head -n1 || true)"
  [[ -n "${patch}" ]] || fail "Unable to detect Winlator release line from 0007 patch"
  basename "${patch}" | sed -E 's/^0007-aeroso-version-(.+)\.patch$/\1/'
}

check_workflow_env_contract() {
  local wf="$1"
  require_file "${wf}"
  require_contains "${wf}" 'WCP_RUNTIME_CLASS_TARGET: bionic-native'
  require_contains "${wf}" 'WCP_MAINLINE_BIONIC_ONLY: "1"'
  require_contains "${wf}" 'WCP_MAINLINE_FEX_EXTERNAL_ONLY: "1"'
  require_contains "${wf}" 'WCP_ALLOW_GLIBC_EXPERIMENTAL: "0"'
  require_contains "${wf}" 'WCP_INCLUDE_FEX_DLLS: "0"'
  require_contains "${wf}" 'WCP_FEX_EXPECTATION_MODE: external'

  require_not_contains "${wf}" 'WCP_RUNTIME_CLASS_TARGET: glibc-wrapped'
  require_not_contains "${wf}" 'WCP_FEX_EXPECTATION_MODE: bundled'
  require_not_contains "${wf}" 'WCP_INCLUDE_FEX_DLLS: "1"'
}

main() {
  cd "${ROOT_DIR}"

  check_workflow_env_contract ".github/workflows/ci-arm64ec-wine.yml"
  check_workflow_env_contract ".github/workflows/ci-proton-ge10-wcp.yml"
  check_workflow_env_contract ".github/workflows/ci-protonwine10-wcp.yml"

  require_file "ci/lib/wcp_common.sh"
  require_contains "ci/lib/wcp_common.sh" 'wcp_enforce_mainline_bionic_policy\(\)'
  require_contains "ci/lib/wcp_common.sh" 'wcp_enforce_mainline_external_runtime_policy\(\)'
  require_contains "ci/lib/wcp_common.sh" 'WCP_WRAPPER_POLICY_VERSION'
  require_contains "ci/lib/wcp_common.sh" 'WCP_POLICY_SOURCE'

  require_file "docs/GN_GH_BACKLOG_MATRIX.md"
  require_contains "docs/GN_GH_BACKLOG_MATRIX.md" 'GameNative'
  require_contains "docs/GN_GH_BACKLOG_MATRIX.md" 'GameHub'

  require_file "docs/REFLECTIVE_HARVARD_LEDGER.md"
  require_contains "docs/REFLECTIVE_HARVARD_LEDGER.md" 'Hypothesis'
  require_contains "docs/REFLECTIVE_HARVARD_LEDGER.md" 'Counter-evidence'

  local winlator_line
  winlator_line="$(detect_winlator_release_line)"
  local version_patch="ci/winlator/patches/0007-aeroso-version-${winlator_line}.patch"
  require_file "${version_patch}"
  require_contains "${version_patch}" "versionName \"${winlator_line}\""

  require_file "ci/release/publish-${winlator_line}.sh"
  require_file "ci/release/prepare-${winlator_line}-notes.sh"

  grep -qF "${winlator_line}" ".github/workflows/ci-winlator.yml" || fail "Missing ${winlator_line} in .github/workflows/ci-winlator.yml"
  grep -qF "v${winlator_line}" "README.md" || fail "Missing v${winlator_line} in README.md"

  log "URC mainline policy checks passed"
}

main "$@"
