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
  grep -qE -- "${pattern}" "${file}" || fail "Missing pattern '${pattern}' in ${file}"
}

require_not_contains() {
  local file="$1" pattern="$2"
  if grep -qE -- "${pattern}" "${file}"; then
    fail "Forbidden pattern '${pattern}' found in ${file}"
  fi
}

check_winlator_audit_docs_sync() {
  local tmp_reflective tmp_runtime norm_reflective norm_runtime
  tmp_reflective="$(mktemp /tmp/winlator_reflective_audit.XXXXXX.md)"
  tmp_runtime="$(mktemp /tmp/winlator_runtime_audit.XXXXXX.md)"
  norm_reflective="$(mktemp /tmp/winlator_reflective_audit_norm.XXXXXX.md)"
  norm_runtime="$(mktemp /tmp/winlator_runtime_audit_norm.XXXXXX.md)"

  python3 ci/winlator/patch-stack-reflective-audit.py --strict --output "${tmp_reflective}" >/dev/null
  python3 ci/winlator/patch-stack-runtime-contract-audit.py --strict --output "${tmp_runtime}" >/dev/null

  sed '/^Generated: /d' "${tmp_reflective}" > "${norm_reflective}"
  sed '/^Generated: /d' docs/PATCH_STACK_REFLECTIVE_AUDIT.md > "${norm_reflective}.repo"
  sed '/^Generated: /d' "${tmp_runtime}" > "${norm_runtime}"
  sed '/^Generated: /d' docs/PATCH_STACK_RUNTIME_CONTRACT_AUDIT.md > "${norm_runtime}.repo"

  cmp -s "${norm_reflective}" "${norm_reflective}.repo" || \
    fail "docs/PATCH_STACK_REFLECTIVE_AUDIT.md is stale; run ci/winlator/run-reflective-audits.sh"
  cmp -s "${norm_runtime}" "${norm_runtime}.repo" || \
    fail "docs/PATCH_STACK_RUNTIME_CONTRACT_AUDIT.md is stale; run ci/winlator/run-reflective-audits.sh"
  rm -f "${tmp_reflective}" "${tmp_runtime}" "${norm_reflective}" "${norm_reflective}.repo" "${norm_runtime}" "${norm_runtime}.repo"
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
baselines = data.get("baselines") or {}
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
        if value is None:
            continue
        if not isinstance(value, str):
            errors.append(f"packages.{name}.{key} must be a string when set")
            continue
        if key.endswith("Sha256") and value.strip() and not re.fullmatch(r"[0-9a-f]{64}", value.strip().lower()):
            errors.append(f"packages.{name}.{key} must be 64 lowercase hex chars when set")
    launcher_url = (entry.get("launcherSourceWcpUrl") or "").strip()
    unix_url = (entry.get("unixSourceWcpUrl") or "").strip()
    launcher_sha = (entry.get("launcherSourceSha256") or "").strip().lower()
    unix_sha = (entry.get("unixSourceSha256") or "").strip().lower()
    if bool(launcher_url) != bool(launcher_sha):
        errors.append(f"packages.{name}: launcher URL/SHA must be both set or both empty")
    if bool(unix_url) != bool(unix_sha):
        errors.append(f"packages.{name}: unix URL/SHA must be both set or both empty")
    if launcher_url and unix_url and launcher_url != unix_url:
        errors.append(f"packages.{name}.launcherSourceWcpUrl and unixSourceWcpUrl must match when both set")
    if launcher_sha and unix_sha and launcher_sha != unix_sha:
        errors.append(f"packages.{name}.launcherSourceSha256 and unixSourceSha256 must match when both set")
    if int(entry.get("unixCoreAdopt", 0)) != 1:
        errors.append(f"packages.{name}.unixCoreAdopt must be 1")
    if launcher_url and "github.com/GameNative/proton-wine/releases/download/" not in launcher_url:
        errors.append(f"packages.{name}.launcherSourceWcpUrl must point to GameNative proton-wine release archive")
    modules = entry.get("unixCoreModules") or []
    if not isinstance(modules, list) or "ntdll.so" not in modules:
        errors.append(f"packages.{name}.unixCoreModules must include ntdll.so")

if errors:
    print("[urc-check][error] Invalid bionic source map:")
    for err in errors:
        print(f"[urc-check][error] - {err}")
    sys.exit(1)

baseline = baselines.get("gamenativeProton104Arm64ec")
if not isinstance(baseline, dict):
    print("[urc-check][error] Invalid bionic source map:")
    print("[urc-check][error] - missing baselines.gamenativeProton104Arm64ec")
    sys.exit(1)
archive_url = (baseline.get("archiveUrl") or "").strip()
if "github.com/GameNative/proton-wine/releases/download/" not in archive_url:
    print("[urc-check][error] Invalid bionic source map:")
    print("[urc-check][error] - baselines.gamenativeProton104Arm64ec.archiveUrl must point to GameNative release asset")
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
  require_contains "${wf}" 'CACHE_DIR: \$\{\{ github\.workspace \}\}/\.cache'
  require_contains "${wf}" 'WCP_RUNTIME_CLASS_TARGET: bionic-native'
  require_contains "${wf}" 'WCP_MAINLINE_BIONIC_ONLY: "1"'
  require_contains "${wf}" 'WCP_STRICT_RUNPATH_CONTRACT: "1"'
  require_contains "${wf}" 'WCP_RUNPATH_ACCEPT_REGEX: .*/data/data/com\\\.termux/files/usr/lib'
  require_contains "${wf}" 'WCP_MAINLINE_FEX_EXTERNAL_ONLY: "1"'
  require_contains "${wf}" 'WCP_ALLOW_GLIBC_EXPERIMENTAL: "0"'
  require_contains "${wf}" 'WCP_INCLUDE_FEX_DLLS: "0"'
  require_contains "${wf}" 'WCP_FEX_EXPECTATION_MODE: external'
  require_contains "${wf}" 'WCP_BIONIC_SOURCE_MAP_FORCE: "0"'
  require_contains "${wf}" 'WCP_BIONIC_SOURCE_MAP_REQUIRED: "0"'
  require_contains "${wf}" 'WCP_BIONIC_SOURCE_MAP_FILE:'
  require_contains "${wf}" 'WCP_BIONIC_DONOR_PREFLIGHT: "1"'
  require_contains "${wf}" 'WCP_STRICT_GAMENATIVE_BASELINE: "1"'
  require_contains "${wf}" 'WCP_GAMENATIVE_BASELINE_URL:'
  require_contains "${wf}" 'Inspect WCP runtime contract'
  require_contains "${wf}" 'inspect-wcp-runtime-contract\.sh'
  require_contains "${wf}" '--strict-gamenative'
  require_contains "${wf}" 'Reverse compare vs GameNative Proton 10\.4 baseline'
  require_contains "${wf}" 'reverse-compare-gamenative-baseline\.sh'
  require_contains "${wf}" 'runtime-contract-inspection\.txt'

  require_not_contains "${wf}" 'WCP_RUNTIME_CLASS_TARGET: glibc-wrapped'
  require_not_contains "${wf}" 'WCP_FEX_EXPECTATION_MODE: bundled'
  require_not_contains "${wf}" 'WCP_INCLUDE_FEX_DLLS: "1"'
}

main() {
  cd "${ROOT_DIR}"

  check_bionic_source_map
  check_workflow_env_contract ".github/workflows/ci-arm64ec-wine.yml"
  check_workflow_env_contract ".github/workflows/ci-proton-ge10-wcp.yml"
  check_workflow_env_contract ".github/workflows/ci-protonwine10-wcp.yml"

  require_file "ci/lib/wcp_common.sh"
  require_contains "ci/lib/wcp_common.sh" 'wcp_enforce_mainline_bionic_policy\(\)'
  require_contains "ci/lib/wcp_common.sh" 'wcp_enforce_mainline_external_runtime_policy\(\)'
  require_contains "ci/lib/wcp_common.sh" 'WCP_WRAPPER_POLICY_VERSION'
  require_contains "ci/lib/wcp_common.sh" 'WCP_POLICY_SOURCE'
  require_contains "ci/lib/wcp_common.sh" 'share/wcp-forensics/unix-module-abi.tsv'
  require_contains "ci/lib/wcp_common.sh" 'share/wcp-forensics/bionic-source-entry.json'
  require_contains "ci/lib/wcp_common.sh" '"unixModuleAbiIndex"'
  require_contains "ci/lib/wcp_common.sh" '"bionicSourceEntry"'
  require_contains "ci/lib/wcp_common.sh" 'WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_SHA256'
  require_contains "ci/lib/wcp_common.sh" 'WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_SHA256'
  require_contains "ci/lib/wcp_common.sh" 'WCP_BIONIC_SOURCE_MAP_SHA256'
  require_contains "ci/lib/wcp_common.sh" 'bionicSourceMapSha256'
  require_contains "ci/lib/wcp_common.sh" 'WCP_BIONIC_DONOR_PREFLIGHT_DONE'
  require_contains "ci/lib/wcp_common.sh" 'bionicDonorPreflightDone'
  require_contains "ci/lib/wcp_common.sh" 'winlator_preflight_bionic_source_contract'
  require_contains "ci/lib/wcp_common.sh" 'contains glibc-unix modules in strict bionic mode'
  require_contains "ci/lib/wcp_common.sh" 'missing bionic ntdll marker'
  require_contains "ci/lib/wcp_common.sh" 'wcp_validate_bionic_source_entry'
  require_contains "ci/lib/wcp_common.sh" 'contract validation failed in strict bionic mode'
  require_contains "ci/lib/winlator-runtime.sh" 'winlator_preflight_bionic_source_contract\(\)'
  require_contains "ci/lib/winlator-runtime.sh" 'WCP_BIONIC_DONOR_PREFLIGHT'
  require_contains "ci/lib/winlator-runtime.sh" 'WCP_BIONIC_LAUNCHER_SOURCE_WCP_RESOLVED_PATH'
  require_contains "ci/lib/winlator-runtime.sh" 'WCP_BIONIC_UNIX_SOURCE_WCP_RESOLVED_PATH'
  require_contains "ci/lib/winlator-runtime.sh" 'WCP_BIONIC_DONOR_PREFLIGHT_DONE'
  require_contains "ci/validation/inspect-wcp-runtime-contract.sh" 'donorPreflightDone'
  require_contains "ci/validation/inspect-wcp-runtime-contract.sh" 'bionic-source-entry.json'
  require_contains "ci/validation/inspect-wcp-runtime-contract.sh" 'donorPreflightDone must be 1 when donor source is configured'
  require_contains "ci/ci-build.sh" 'winlator_preflight_bionic_source_contract'
  require_contains "ci/proton-ge10/ci-build-proton-ge10-wcp.sh" 'winlator_preflight_bionic_source_contract'
  require_contains "ci/protonwine10/ci-build-protonwine10-wcp.sh" 'winlator_preflight_bionic_source_contract'
  require_file "ci/gamenative/apply-android-patchset.sh"
  require_file "ci/gamenative/selftest-normalizers.sh"
  [[ -x "ci/gamenative/selftest-normalizers.sh" ]] || fail "ci/gamenative/selftest-normalizers.sh must be executable"
  bash "ci/gamenative/selftest-normalizers.sh"

  require_file "docs/GN_GH_BACKLOG_MATRIX.md"
  require_contains "docs/GN_GH_BACKLOG_MATRIX.md" 'GameNative'
  require_contains "docs/GN_GH_BACKLOG_MATRIX.md" 'GameHub'
  require_file "ci/contents/validate-contents-json.py"
  require_file "ci/validation/gh-mainline-health.sh"
  require_file "ci/validation/gh-run-root-cause.sh"
  require_file "ci/validation/gh-latest-failures.sh"
  require_file "ci/validation/reverse-compare-gamenative-baseline.sh"
  [[ -x "ci/validation/reverse-compare-gamenative-baseline.sh" ]] || fail "ci/validation/reverse-compare-gamenative-baseline.sh must be executable"
  require_file "ci/validation/collect-mainline-forensic-snapshot.sh"
  [[ -x "ci/validation/gh-run-root-cause.sh" ]] || fail "ci/validation/gh-run-root-cause.sh must be executable"
  require_contains "ci/validation/gh-latest-failures.sh" 'WLT_AUTO_TRIAGE_FAILED_RUNS'
  require_contains "ci/validation/gh-latest-failures.sh" 'WLT_AUTO_TRIAGE_MAX_RUNS'
  require_contains "ci/validation/gh-latest-failures.sh" 'WLT_AUTO_TRIAGE_MAX_JOBS'
  require_contains "ci/validation/gh-latest-failures.sh" 'gh-run-root-cause\.sh'
  require_contains "ci/validation/gh-mainline-health.sh" 'Build Wine 11 ARM64EC \(WCP\)'
  require_contains "ci/validation/gh-mainline-health.sh" 'Build Proton GE10 ARM64EC \(WCP\)'
  require_contains "ci/validation/gh-mainline-health.sh" 'Build ProtonWine10 GameNative ARM64EC \(WCP\)'
  require_contains "ci/validation/gh-mainline-health.sh" 'Build Winlator ARM64EC \(no-embedded-runtimes\)'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'gh-mainline-health\.sh'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'gh-latest-failures\.sh'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'gh-run-root-cause\.sh'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'check-urc-mainline-policy\.sh'
  require_file "contents/contents.json"
  python3 "ci/contents/validate-contents-json.py" "contents/contents.json" >/dev/null
  require_file "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_file "docs/EXTERNAL_SIGNAL_CONTRACT.md"
  require_file "ci/research/reverse-wcp-package.py"
  require_file "ci/research/run-gamenative-proton104-reverse.sh"
  [[ -x "ci/research/run-gamenative-proton104-reverse.sh" ]] || fail "ci/research/run-gamenative-proton104-reverse.sh must be executable"
  require_file "docs/GAMENATIVE_PROTON104_WCP_REVERSE.md"
  require_file "docs/ADB_HARVARD_DEVICE_FORENSICS.md"
  require_file "docs/PATCH_STACK_REFLECTIVE_AUDIT.md"
  require_file "docs/PATCH_STACK_RUNTIME_CONTRACT_AUDIT.md"
  require_file "ci/winlator/patch-stack-reflective-audit.py"
  require_file "ci/winlator/patch-stack-runtime-contract-audit.py"
  require_file "ci/winlator/run-reflective-audits.sh"
  require_file "ci/winlator/validate-patch-sequence.sh"
  require_file "ci/winlator/forensic-adb-runtime-contract.sh"
  require_file "ci/winlator/forensic-adb-harvard-suite.sh"
  require_file "ci/winlator/adb-container-seed-matrix.sh"
  require_file "ci/winlator/adb-ensure-artifacts-latest.sh"
  require_file "ci/winlator/artifact-source-map.json"
  require_file "ci/winlator/forensic-runtime-mismatch-matrix.py"
  require_file "ci/winlator/selftest-runtime-mismatch-matrix.sh"
  [[ -x "ci/winlator/forensic-adb-runtime-contract.sh" ]] || fail "ci/winlator/forensic-adb-runtime-contract.sh must be executable"
  [[ -x "ci/winlator/forensic-adb-harvard-suite.sh" ]] || fail "ci/winlator/forensic-adb-harvard-suite.sh must be executable"
  [[ -x "ci/winlator/adb-container-seed-matrix.sh" ]] || fail "ci/winlator/adb-container-seed-matrix.sh must be executable"
  [[ -x "ci/winlator/adb-ensure-artifacts-latest.sh" ]] || fail "ci/winlator/adb-ensure-artifacts-latest.sh must be executable"
  [[ -x "ci/winlator/selftest-runtime-mismatch-matrix.sh" ]] || fail "ci/winlator/selftest-runtime-mismatch-matrix.sh must be executable"
  require_contains "ci/winlator/forensic-adb-harvard-suite.sh" 'forensic-adb-complete-matrix\.sh'
  require_contains "ci/winlator/forensic-adb-harvard-suite.sh" 'forensic-runtime-mismatch-matrix\.py'
  require_contains "ci/winlator/forensic-adb-harvard-suite.sh" 'adb-container-seed-matrix\.sh'
  require_contains "ci/winlator/forensic-adb-harvard-suite.sh" 'adb-ensure-artifacts-latest\.sh'
  require_contains "ci/winlator/adb-ensure-artifacts-latest.sh" 'artifact-source-map\.json'
  require_contains "ci/winlator/artifact-source-map.json" 'wine11'
  require_contains "ci/winlator/artifact-source-map.json" 'protonwine10'
  require_contains "ci/winlator/artifact-source-map.json" 'protonge10'
  require_contains "ci/winlator/artifact-source-map.json" 'gamenative104'
  require_contains "ci/winlator/forensic-adb-runtime-contract.sh" 'Actionable drift rows'
  require_contains "ci/winlator/forensic-adb-runtime-contract.sh" 'WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE'
  require_contains "ci/winlator/forensic-runtime-mismatch-matrix.py" 'patch_hint'
  require_contains "ci/winlator/forensic-runtime-mismatch-matrix.py" 'runtime_guard_blocked'
  require_contains "ci/winlator/forensic-runtime-mismatch-matrix.py" 'severity_rank'
  require_contains "ci/winlator/forensic-runtime-mismatch-matrix.py" '--fail-on-severity-at-or-above'
  bash "ci/winlator/selftest-runtime-mismatch-matrix.sh"
  require_file "ci/winlator/patches/0059-runtime-signal-contract-helper-and-adoption.patch"
  require_contains "ci/winlator/patches/0059-runtime-signal-contract-helper-and-adoption.patch" 'RuntimeSignalContract'
  require_contains "ci/winlator/patches/0059-runtime-signal-contract-helper-and-adoption.patch" 'WINLATOR_SIGNAL_POLICY'
  require_contains "ci/winlator/patches/0059-runtime-signal-contract-helper-and-adoption.patch" 'WINLATOR_SIGNAL_INPUT_ROUTE'
  require_file "ci/winlator/patches/0060-contents-internal-type-canonicalization.patch"
  require_contains "ci/winlator/patches/0060-contents-internal-type-canonicalization.patch" 'MARK_INTERNAL_TYPE'
  require_contains "ci/winlator/patches/0060-contents-internal-type-canonicalization.patch" 'internalType'
  require_contains "ci/winlator/patches/0060-contents-internal-type-canonicalization.patch" 'resolveInternalTypeName'
  require_contains "ci/winlator/ci-build-winlator-ludashi.sh" 'run-reflective-audits\.sh'
  require_contains "ci/winlator/run-reflective-audits.sh" 'validate-patch-sequence\.sh'
  require_contains "ci/winlator/run-reflective-audits.sh" 'patch-stack-reflective-audit\.py'
  require_contains "ci/winlator/run-reflective-audits.sh" 'patch-stack-runtime-contract-audit\.py'
  require_contains "docs/README.md" 'PATCH_STACK_REFLECTIVE_AUDIT\.md'
  require_contains "docs/README.md" 'PATCH_STACK_RUNTIME_CONTRACT_AUDIT\.md'
  require_contains "docs/README.md" 'EXTERNAL_SIGNAL_CONTRACT\.md'
  require_contains "docs/README.md" 'forensic-adb-harvard-suite\.sh'
  require_contains "docs/README.md" 'adb-container-seed-matrix\.sh'
  require_contains "docs/README.md" 'adb-ensure-artifacts-latest\.sh'
  require_contains "docs/README.md" 'reverse-compare-gamenative-baseline\.sh'
  require_contains "docs/README.md" 'reverse-wcp-package\.py'
  require_contains "docs/README.md" 'run-gamenative-proton104-reverse\.sh'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'share/wcp-forensics/unix-module-abi.tsv'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'share/wcp-forensics/bionic-source-entry.json'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'bionicLauncherSourceResolvedSha256'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'bionicDonorPreflightDone'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'inspect-wcp-runtime-contract.sh --strict-bionic'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'WINLATOR_SIGNAL_POLICY'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'WINLATOR_SIGNAL_SOURCES'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'WINLATOR_SIGNAL_DECISION_HASH'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'WINLATOR_SIGNAL_DECISION_COUNT'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'WINLATOR_SIGNAL_INPUT_ROUTE'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'WINLATOR_SIGNAL_INPUT_LAUNCH_KIND'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'WINLATOR_SIGNAL_INPUT_TARGET_EXECUTABLE'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'WINLATOR_SIGNAL_INPUT_PRECHECK_REASON'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" 'WINLATOR_SIGNAL_INPUT_PRECHECK_FALLBACK'
  require_contains "docs/EXTERNAL_SIGNAL_CONTRACT.md" 'external-only'
  require_contains "docs/EXTERNAL_SIGNAL_CONTRACT.md" 'WINLATOR_SIGNAL_POLICY'
  require_contains "docs/EXTERNAL_SIGNAL_CONTRACT.md" 'WINLATOR_SIGNAL_SOURCES'
  require_contains "docs/EXTERNAL_SIGNAL_CONTRACT.md" 'WINLATOR_SIGNAL_DECISION_HASH'
  require_contains "docs/EXTERNAL_SIGNAL_CONTRACT.md" 'WINLATOR_SIGNAL_DECISION_COUNT'
  require_contains "docs/EXTERNAL_SIGNAL_CONTRACT.md" 'WINLATOR_SIGNAL_INPUT_ROUTE'
  require_contains "docs/EXTERNAL_SIGNAL_CONTRACT.md" 'WINLATOR_SIGNAL_INPUT_LAUNCH_KIND'
  require_contains "docs/EXTERNAL_SIGNAL_CONTRACT.md" 'WINLATOR_SIGNAL_INPUT_TARGET_EXECUTABLE'
  require_contains "docs/EXTERNAL_SIGNAL_CONTRACT.md" 'WINLATOR_SIGNAL_INPUT_PRECHECK_REASON'
  require_contains "docs/EXTERNAL_SIGNAL_CONTRACT.md" 'WINLATOR_SIGNAL_INPUT_PRECHECK_FALLBACK'
  require_contains "docs/PATCH_STACK_RUNTIME_CONTRACT_AUDIT.md" 'external_signal_inputs'
  check_winlator_audit_docs_sync
  require_file "ci/validation/inspect-wcp-runtime-contract.sh"
  [[ -x "ci/validation/inspect-wcp-runtime-contract.sh" ]] || fail "inspect-wcp-runtime-contract.sh must be executable"
  require_contains "ci/validation/inspect-wcp-runtime-contract.sh" '--strict-gamenative'
  require_contains "ci/validation/inspect-wcp-runtime-contract.sh" 'gamenativeBaseline'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" '--strict-gamenative'
  require_contains "docs/PROTON10_WCP.md" '--strict-gamenative'
  require_contains "docs/PROTON10_WCP.md" 'inspect-wcp-runtime-contract.sh'

  require_file "docs/REFLECTIVE_HARVARD_LEDGER.md"
  require_contains "docs/REFLECTIVE_HARVARD_LEDGER.md" 'Hypothesis'
  require_contains "docs/REFLECTIVE_HARVARD_LEDGER.md" 'Counter-evidence'
  require_contains "docs/REFLECTIVE_HARVARD_LEDGER.md" 'bionic-donor-contract-hardening'

  local winlator_line
  winlator_line="$(detect_winlator_release_line)"
  local version_patch="ci/winlator/patches/0007-aeroso-version-${winlator_line}.patch"
  require_file "${version_patch}"
  require_contains "${version_patch}" "versionName \"${winlator_line}\""

  require_file "ci/release/publish-${winlator_line}.sh"
  require_file "ci/release/prepare-${winlator_line}-notes.sh"

  grep -qF "${winlator_line}" ".github/workflows/ci-winlator.yml" || fail "Missing ${winlator_line} in .github/workflows/ci-winlator.yml"
  grep -qF "v${winlator_line}" "README.md" || fail "Missing v${winlator_line} in README.md"
  require_contains "README.md" 'unix-module-abi.tsv'
  require_contains "README.md" 'inspect-wcp-runtime-contract.sh'

  log "URC mainline policy checks passed"
}

main "$@"
