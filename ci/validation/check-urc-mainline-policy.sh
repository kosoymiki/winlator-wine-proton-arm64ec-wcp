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

check_bionic_source_map() {
  local map_file="ci/runtime-sources/bionic-source-map.json"
  require_file "${map_file}"
  python3 - "${map_file}" <<'PY'
import json
import re
import sys
from pathlib import Path

map_path = Path(sys.argv[1])
data = json.loads(map_path.read_text(encoding="utf-8"))
packages = data.get("packages") or {}
required = (
    "wine-11-arm64ec",
    "proton-ge10-arm64ec",
    "protonwine10-gamenative-arm64ec",
)
errors = []

for name in required:
    entry = packages.get(name)
    if not isinstance(entry, dict):
        errors.append(f"missing packages.{name}")
        continue
    for key in ("launcherSourceWcpUrl", "unixSourceWcpUrl", "launcherSourceSha256", "unixSourceSha256"):
        value = entry.get(key)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"packages.{name}.{key} must be a non-empty string")
    for key in ("launcherSourceSha256", "unixSourceSha256"):
        value = (entry.get(key) or "").lower()
        if not re.fullmatch(r"[0-9a-f]{64}", value):
            errors.append(f"packages.{name}.{key} must be 64 lowercase hex chars")
    if (entry.get("launcherSourceWcpUrl") or "") != (entry.get("unixSourceWcpUrl") or ""):
        errors.append(f"packages.{name}.launcherSourceWcpUrl and unixSourceWcpUrl must match in mainline")
    if (entry.get("launcherSourceSha256") or "").lower() != (entry.get("unixSourceSha256") or "").lower():
        errors.append(f"packages.{name}.launcherSourceSha256 and unixSourceSha256 must match in mainline")
    if int(entry.get("unixCoreAdopt", 0)) != 1:
        errors.append(f"packages.{name}.unixCoreAdopt must be 1")
    modules = entry.get("unixCoreModules") or []
    if not isinstance(modules, list) or "ntdll.so" not in modules:
        errors.append(f"packages.{name}.unixCoreModules must include ntdll.so")

if errors:
    print("[urc-check][error] Invalid bionic source map:")
    for err in errors:
        print(f"[urc-check][error] - {err}")
    sys.exit(1)
PY
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
  require_contains "${wf}" 'cancel-in-progress: false'
  require_contains "${wf}" 'ci/runtime-sources/\*\*'
  require_contains "${wf}" 'WCP_RUNTIME_CLASS_TARGET: bionic-native'
  require_contains "${wf}" 'WCP_MAINLINE_BIONIC_ONLY: "1"'
  require_contains "${wf}" 'WCP_MAINLINE_FEX_EXTERNAL_ONLY: "1"'
  require_contains "${wf}" 'WCP_ALLOW_GLIBC_EXPERIMENTAL: "0"'
  require_contains "${wf}" 'WCP_INCLUDE_FEX_DLLS: "0"'
  require_contains "${wf}" 'WCP_FEX_EXPECTATION_MODE: external'
  require_contains "${wf}" 'WCP_BIONIC_SOURCE_MAP_FORCE: "1"'
  require_contains "${wf}" 'WCP_BIONIC_SOURCE_MAP_REQUIRED: "1"'
  require_contains "${wf}" 'WCP_BIONIC_LAUNCHER_SOURCE_WCP_URL:'
  require_contains "${wf}" 'WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256:'
  require_contains "${wf}" 'WCP_BIONIC_UNIX_SOURCE_WCP_URL:'
  require_contains "${wf}" 'WCP_BIONIC_UNIX_SOURCE_WCP_SHA256:'
  require_contains "${wf}" 'Cache bionic donor archives'
  require_contains "${wf}" 'bionic-donor-\$\{\{ env\.WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256 \}\}-\$\{\{ env\.WCP_BIONIC_UNIX_SOURCE_WCP_SHA256 \}\}'

  require_not_contains "${wf}" 'WCP_RUNTIME_CLASS_TARGET: glibc-wrapped'
  require_not_contains "${wf}" 'WCP_FEX_EXPECTATION_MODE: bundled'
  require_not_contains "${wf}" 'WCP_INCLUDE_FEX_DLLS: "1"'
}

main() {
  cd "${ROOT_DIR}"

  check_workflow_env_contract ".github/workflows/ci-arm64ec-wine.yml"
  check_workflow_env_contract ".github/workflows/ci-proton-ge10-wcp.yml"
  check_workflow_env_contract ".github/workflows/ci-protonwine10-wcp.yml"
  check_bionic_source_map

  require_file "ci/lib/wcp_common.sh"
  require_contains "ci/lib/wcp_common.sh" 'wcp_enforce_mainline_bionic_policy\(\)'
  require_contains "ci/lib/wcp_common.sh" 'wcp_enforce_mainline_external_runtime_policy\(\)'
  require_contains "ci/lib/wcp_common.sh" 'WCP_WRAPPER_POLICY_VERSION'
  require_contains "ci/lib/wcp_common.sh" 'WCP_POLICY_SOURCE'
  require_contains "ci/lib/wcp_common.sh" 'share/wcp-forensics/unix-module-abi.tsv'
  require_contains "ci/lib/wcp_common.sh" '"unixModuleAbiIndex"'
  require_contains "ci/lib/wcp_common.sh" 'WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256'
  require_contains "ci/lib/wcp_common.sh" 'WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256'
  require_contains "ci/lib/wcp_common.sh" 'contains glibc-unix modules in strict bionic mode'
  require_contains "ci/lib/wcp_common.sh" 'missing bionic ntdll marker'
  require_contains "ci/lib/winlator-runtime.sh" 'winlator_preflight_bionic_source_contract\(\)'
  require_contains "ci/lib/winlator-runtime.sh" 'Strict bionic mainline requires WCP_BIONIC_LAUNCHER_SOURCE_WCP_SHA256'
  require_contains "ci/lib/winlator-runtime.sh" 'Strict bionic mainline requires WCP_BIONIC_UNIX_SOURCE_WCP_SHA256'
  require_contains "ci/ci-build.sh" 'winlator_preflight_bionic_source_contract'
  require_contains "ci/proton-ge10/ci-build-proton-ge10-wcp.sh" 'winlator_preflight_bionic_source_contract'
  require_contains "ci/protonwine10/ci-build-protonwine10-wcp.sh" 'winlator_preflight_bionic_source_contract'

  require_file "docs/GN_GH_BACKLOG_MATRIX.md"
  require_contains "docs/GN_GH_BACKLOG_MATRIX.md" 'GameNative'
  require_contains "docs/GN_GH_BACKLOG_MATRIX.md" 'GameHub'
  require_file "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'share/wcp-forensics/unix-module-abi.tsv'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'bionicLauncherSourceResolvedSha256'

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
