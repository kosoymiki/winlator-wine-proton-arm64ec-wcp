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

require_contains_any() {
  local pattern="$1"
  shift
  local file
  for file in "$@"; do
    [[ -f "${file}" ]] || continue
    if grep -qE -- "${pattern}" "${file}"; then
      return 0
    fi
  done
  fail "Missing pattern '${pattern}' in any of: $*"
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

  python3 ci/winlator/patch-stack-reflective-audit.py --output "${tmp_reflective}" >/dev/null
  python3 ci/winlator/patch-stack-runtime-contract-audit.py --output "${tmp_runtime}" >/dev/null

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
schema = (data.get("schema") or "").strip()
if schema != "bionic-source-map/v2":
    print("[urc-check][error] Invalid bionic source map:")
    print(f"[urc-check][error] - expected schema bionic-source-map/v2, got: {schema or '<missing>'}")
    sys.exit(1)
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
    for key in ("launcherSourceSha256Alternates", "unixSourceSha256Alternates"):
        value = entry.get(key)
        if value is None:
            continue
        if not isinstance(value, list):
            errors.append(f"packages.{name}.{key} must be an array when set")
            continue
        for idx, alt in enumerate(value):
            if not isinstance(alt, str) or not re.fullmatch(r"[0-9a-f]{64}", alt.strip().lower()):
                errors.append(f"packages.{name}.{key}[{idx}] must be 64 lowercase hex chars")
    launcher_url = (entry.get("launcherSourceWcpUrl") or "").strip()
    unix_url = (entry.get("unixSourceWcpUrl") or "").strip()
    launcher_sha = (entry.get("launcherSourceSha256") or "").strip().lower()
    unix_sha = (entry.get("unixSourceSha256") or "").strip().lower()
    launcher_alt = [str(x).strip().lower() for x in (entry.get("launcherSourceSha256Alternates") or []) if str(x).strip()]
    unix_alt = [str(x).strip().lower() for x in (entry.get("unixSourceSha256Alternates") or []) if str(x).strip()]
    if launcher_url and not (launcher_sha or launcher_alt):
        errors.append(f"packages.{name}: launcher URL requires launcherSourceSha256 or launcherSourceSha256Alternates")
    if unix_url and not (unix_sha or unix_alt):
        errors.append(f"packages.{name}: unix URL requires unixSourceSha256 or unixSourceSha256Alternates")
    if (launcher_sha or launcher_alt) and not launcher_url:
        errors.append(f"packages.{name}: launcher SHA data requires launcherSourceWcpUrl")
    if (unix_sha or unix_alt) and not unix_url:
        errors.append(f"packages.{name}: unix SHA data requires unixSourceWcpUrl")
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
  patch="$(detect_winlator_version_patch)"
  [[ -n "${patch}" ]] || fail "Unable to detect Winlator release line from patch stack"
  python3 - "${patch}" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
# Prefer added lines in unified patches to avoid matching removed upstream versionName.
match = re.search(r'^\+\s*versionName\s+"([^"]+)"', text, flags=re.MULTILINE)
if not match:
    match = re.search(r'versionName\s+"([^"]+)"', text)
if not match:
    raise SystemExit(1)
print(re.sub(r'\+$', '', match.group(1)))
PY
}

detect_winlator_version_patch() {
  local patch
  patch="$(grep -l 'versionName "' ci/winlator/patches/*.patch 2>/dev/null | sort | head -n1 || true)"
  [[ -n "${patch}" ]] || fail "Unable to locate a Winlator version patch in ci/winlator/patches"
  printf '%s\n' "${patch}"
}

check_winlator_patch_base_mode() {
  local patch_dir="ci/winlator/patches"
  mapfile -t patch_files < <(find "${patch_dir}" -maxdepth 1 -type f -name '*.patch' -printf '%f\n' | sort)
  (( ${#patch_files[@]} > 0 )) || fail "No patch files found in ${patch_dir}"
  [[ "${patch_files[0]}" == "0001-mainline-full-stack-consolidated.patch" ]] || \
    fail "Unexpected first mainline patch name: ${patch_files[0]}"
  # During patch-base cycles we allow temporary 0002+ slices, but numbering must stay contiguous.
  bash ci/winlator/validate-patch-sequence.sh "${patch_dir}" >/dev/null
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

  check_winlator_patch_base_mode
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
  require_file "ci/gamenative/check-manifest-contract.py"
  [[ -x "ci/gamenative/selftest-normalizers.sh" ]] || fail "ci/gamenative/selftest-normalizers.sh must be executable"
  bash "ci/gamenative/selftest-normalizers.sh"
  python3 "ci/gamenative/check-manifest-contract.py"

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
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_CAPTURE_ONLINE_INTAKE'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_REQUIRED'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_SNAPSHOT_FAIL_MODE'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_USE_HIGH_CYCLE'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_PROFILE'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_FETCH'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_MODE'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_TRANSPORT'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_GIT_DEPTH'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_ALIASES'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_CMD_TIMEOUT_SEC'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_REQUIRED_MEDIUM_MARKERS'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_REQUIRED_HIGH_MARKERS'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_REQUIRED_LOW_MARKERS'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_REQUIRE_LOW_READY_VALIDATED'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_BACKLOG_STRICT'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_CAPTURE_RELEASE_PREP'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_RELEASE_PREP_REQUIRED'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'prepare-release-patch-base\.sh'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'ci/reverse/online-intake\.sh'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'run-high-priority-cycle\.sh'
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
  require_file "ci/winlator/forensic-adb-complete-matrix.sh"
  require_file "ci/winlator/adb-network-source-diagnostics.sh"
  require_file "ci/winlator/adb-container-seed-matrix.sh"
  require_file "ci/winlator/adb-ensure-artifacts-latest.sh"
  require_file "ci/reverse/online-intake.sh"
  require_file "ci/reverse/run-high-priority-cycle.sh"
  require_file "ci/reverse/online_intake.py"
  require_file "ci/reverse/generate-online-backlog.py"
  require_file "ci/reverse/check-online-backlog.py"
  require_file "ci/reverse/harvest_transfer.py"
  require_file "ci/reverse/snapshot-contract-audit.py"
  require_file "ci/reverse/sync-repo-branches-from-harvest.py"
  require_file "ci/reverse/harvest-transfer.sh"
  require_file "ci/reverse/transfer_map.json"
  require_contains "ci/reverse/harvest-transfer.sh" 'HARVEST_TRANSFER_AUTO_FOCUS_SYNC'
  require_contains "ci/reverse/harvest-transfer.sh" 'HARVEST_TRANSFER_INCLUDE_UNMAPPED'
  require_contains "ci/reverse/harvest-transfer.sh" 'HARVEST_TRANSFER_FAIL_ON_REPO_ERRORS'
  require_contains "ci/reverse/harvest-transfer.sh" '--auto-focus-sync'
  require_contains "ci/reverse/harvest-transfer.sh" '--include-unmapped'
  require_contains "ci/reverse/harvest-transfer.sh" '--fail-on-repo-errors'
  require_contains "ci/reverse/harvest_transfer.py" '--auto-focus-sync'
  require_contains "ci/reverse/harvest_transfer.py" '--include-unmapped'
  require_contains "ci/reverse/harvest_transfer.py" '--fail-on-repo-errors'
  require_contains "ci/reverse/harvest_transfer.py" 'build_auto_focus_sync_rules'
  require_contains "ci/reverse/harvest_transfer.py" 'add_unmapped_specs'
  require_contains "ci/reverse/harvest_transfer.py" 'ci/reverse/upstream_snapshots/'
  require_contains "ci/reverse/harvest_transfer.py" 'repo_errors'
  [[ -x "ci/reverse/snapshot-contract-audit.py" ]] || fail "ci/reverse/snapshot-contract-audit.py must be executable"
  [[ -x "ci/reverse/sync-repo-branches-from-harvest.py" ]] || fail "ci/reverse/sync-repo-branches-from-harvest.py must be executable"
  require_file "ci/reverse/online_intake_repos.json"
  require_file "ci/winlator/artifact-source-map.json"
  require_file "ci/winlator/forensic-runtime-mismatch-matrix.py"
  require_file "ci/winlator/forensic-runtime-conflict-contour.py"
  require_file "ci/winlator/selftest-runtime-mismatch-matrix.sh"
  [[ -x "ci/winlator/forensic-adb-runtime-contract.sh" ]] || fail "ci/winlator/forensic-adb-runtime-contract.sh must be executable"
  [[ -x "ci/winlator/forensic-adb-harvard-suite.sh" ]] || fail "ci/winlator/forensic-adb-harvard-suite.sh must be executable"
  [[ -x "ci/winlator/adb-network-source-diagnostics.sh" ]] || fail "ci/winlator/adb-network-source-diagnostics.sh must be executable"
  [[ -x "ci/winlator/adb-container-seed-matrix.sh" ]] || fail "ci/winlator/adb-container-seed-matrix.sh must be executable"
  [[ -x "ci/winlator/adb-ensure-artifacts-latest.sh" ]] || fail "ci/winlator/adb-ensure-artifacts-latest.sh must be executable"
  [[ -x "ci/winlator/selftest-runtime-mismatch-matrix.sh" ]] || fail "ci/winlator/selftest-runtime-mismatch-matrix.sh must be executable"
  require_contains "ci/winlator/forensic-adb-harvard-suite.sh" 'forensic-adb-complete-matrix\.sh'
  require_contains "ci/winlator/forensic-adb-harvard-suite.sh" 'forensic-runtime-mismatch-matrix\.py'
  require_contains "ci/winlator/forensic-adb-harvard-suite.sh" 'forensic-runtime-conflict-contour\.py'
  require_contains "ci/winlator/forensic-adb-harvard-suite.sh" 'adb-container-seed-matrix\.sh'
  require_contains "ci/winlator/forensic-adb-harvard-suite.sh" 'adb-ensure-artifacts-latest\.sh'
  require_contains "ci/winlator/forensic-adb-harvard-suite.sh" 'adb-network-source-diagnostics\.sh'
  require_contains "ci/winlator/forensic-adb-harvard-suite.sh" 'WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE'
  require_contains "ci/winlator/adb-ensure-artifacts-latest.sh" 'artifact-source-map\.json'
  require_contains "ci/winlator/artifact-source-map.json" 'wine11'
  require_contains "ci/winlator/artifact-source-map.json" 'protonwine10'
  require_contains "ci/winlator/artifact-source-map.json" 'protonge10'
  require_contains "ci/winlator/artifact-source-map.json" 'gamenative104'
  require_contains "ci/winlator/forensic-adb-runtime-contract.sh" 'Actionable drift rows'
  require_contains "ci/winlator/forensic-adb-runtime-contract.sh" 'Actionable conflict rows'
  require_contains "ci/winlator/forensic-adb-runtime-contract.sh" 'WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE'
  require_contains "ci/winlator/forensic-adb-runtime-contract.sh" 'WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE'
  require_contains "ci/winlator/forensic-adb-runtime-contract.sh" 'forensic-runtime-conflict-contour\.py'
  require_contains "ci/winlator/forensic-adb-complete-matrix.sh" 'WLT_CAPTURE_CONFLICT_LOGS'
  require_contains "ci/winlator/forensic-adb-complete-matrix.sh" 'logcat-runtime-conflict-contour\.txt'
  require_contains "ci/winlator/forensic-adb-complete-matrix.sh" 'runtime-conflict-contour.summary.txt'
  require_contains "ci/winlator/forensic-runtime-mismatch-matrix.py" 'patch_hint'
  require_contains "ci/winlator/forensic-runtime-mismatch-matrix.py" 'runtime_guard_blocked'
  require_contains "ci/winlator/forensic-runtime-mismatch-matrix.py" 'severity_rank'
  require_contains "ci/winlator/forensic-runtime-mismatch-matrix.py" '--fail-on-severity-at-or-above'
  require_contains "ci/reverse/online-intake.sh" 'MAX_FOCUS_FILES'
  require_contains "ci/reverse/online-intake.sh" 'GH_RETRIES'
  require_contains "ci/reverse/online-intake.sh" 'GH_RETRY_DELAY_SEC'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_INTAKE_MODE'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_INTAKE_SCOPE'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_INTAKE_TRANSPORT'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_INTAKE_TRANSPORT="\$\{ONLINE_INTAKE_TRANSPORT:-gh\}"'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_INTAKE_GIT_DEPTH'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_INTAKE_CMD_TIMEOUT_SEC'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_INTAKE_FETCH'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_INTAKE_ALIASES'
  require_contains "ci/reverse/online-intake.sh" 'fail-on-intake-errors'
  require_contains "ci/reverse/online-intake.sh" 'require-ready-validated'
  require_contains "ci/reverse/online-intake.sh" 'require-medium-ready-validated'
  require_contains "ci/reverse/online-intake.sh" 'require-low-ready-validated'
  require_contains "ci/reverse/online-intake.sh" 'require-high-markers'
  require_contains "ci/reverse/online-intake.sh" 'require-medium-markers'
  require_contains "ci/reverse/online-intake.sh" 'require-low-markers'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_REQUIRED_HIGH_MARKERS'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_REQUIRED_MEDIUM_MARKERS'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_REQUIRED_LOW_MARKERS'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_REQUIRE_LOW_READY_VALIDATED'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_INCLUDE_COMMIT_SCAN'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_COMMIT_SCAN_AUTO'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_COMMIT_SCAN_PROFILE'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_COMMIT_SCAN_COMMITS_PER_REPO'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_COMMIT_SCAN_JSON'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_RUN_HARVEST'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_HARVEST_PROFILE'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_HARVEST_MAX_COMMITS_PER_REPO'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_HARVEST_APPLY'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_HARVEST_SKIP_NO_SYNC'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_HARVEST_AUTO_FOCUS_SYNC'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_HARVEST_INCLUDE_UNMAPPED'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_HARVEST_FAIL_ON_REPO_ERRORS'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_SYNC_BRANCH_PINS'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_RUN_SNAPSHOT_AUDIT'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_SNAPSHOT_AUDIT_STRICT'
  require_contains "ci/reverse/online-intake.sh" 'ONLINE_BACKLOG_STRICT'
  require_contains "ci/reverse/online-intake.sh" 'generate-online-backlog\.py'
  require_contains "ci/reverse/online-intake.sh" 'check-online-backlog\.py'
  require_contains "ci/reverse/online-intake.sh" 'online-commit-scan\.sh'
  require_contains "ci/reverse/online-intake.sh" 'harvest-transfer\.sh'
  require_contains "ci/reverse/online-intake.sh" 'sync-repo-branches-from-harvest\.py'
  require_contains "ci/reverse/online-intake.sh" 'snapshot-contract-audit\.py'
  require_contains "ci/reverse/online-intake.sh" 'harvest_repo_errors='
  require_contains "ci/reverse/online-intake.sh" 'harvest_sync_changed='
  require_contains "ci/reverse/online-intake.sh" 'harvest_sync_errors='
  require_contains "ci/reverse/online-intake.sh" 'PATCH_TRANSFER_BACKLOG\.json'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_BACKLOG_STRICT'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_TRANSPORT:=gh'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_PROFILE:=all'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_MODE:=code-only'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_SCOPE:=focused'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_MAX_FOCUS_FILES:=6'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_REQUIRED_HIGH_MARKERS'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_REQUIRED_MEDIUM_MARKERS'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_REQUIRED_LOW_MARKERS'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_REQUIRE_LOW_READY_VALIDATED'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_RUN_COMMIT_SCAN'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_INCLUDE_COMMIT_SCAN'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_COMMIT_SCAN_JSON'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_RUN_HARVEST'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_HARVEST_PROFILE'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_HARVEST_MAX_COMMITS_PER_REPO'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_HARVEST_APPLY'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_HARVEST_SKIP_NO_SYNC'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_HARVEST_AUTO_FOCUS_SYNC'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_HARVEST_INCLUDE_UNMAPPED'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_SYNC_BRANCH_PINS'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_HARVEST_FAIL_ON_REPO_ERRORS'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_RUN_SNAPSHOT_AUDIT'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_SNAPSHOT_AUDIT_STRICT'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'snapshot-contract-audit\.py'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'sync-repo-branches-from-harvest\.py'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'harvest_repo_errors='
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'harvest_sync_changed='
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'harvest_sync_errors='
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'harvest-transfer\.sh'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_COMMIT_SCAN_PROFILE'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_COMMIT_SCAN_COMMITS_PER_REPO'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_ALL_REPOS'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_ALIASES'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_PROFILE'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'WLT_HIGH_CYCLE_PROFILE=custom requires WLT_HIGH_CYCLE_ALIASES'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'ONLINE_BACKLOG_STRICT="\$\{WLT_HIGH_CYCLE_BACKLOG_STRICT\}"'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'medium_rows='
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'medium_status='
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'low_rows='
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'low_status='
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'check-manifest-contract\.py'
  require_contains "ci/reverse/run-high-priority-cycle.sh" 'check-urc-mainline-policy\.sh'
  [[ -x "ci/reverse/run-high-priority-cycle.sh" ]] || fail "ci/reverse/run-high-priority-cycle.sh must be executable"
  require_contains "ci/reverse/online_intake.py" '"errors"'
  require_contains "ci/reverse/online_intake.py" 'enabled_default'
  require_contains "ci/reverse/online_intake.py" '--scope'
  require_contains "ci/reverse/online_intake.py" 'default="focused"'
  require_contains "ci/reverse/online_intake.py" 'resolve_effective_branch_gh'
  require_contains "ci/reverse/online_intake.py" 'resolve_effective_branch_git'
  require_contains "ci/reverse/online_intake.py" 'requested_branch'
  require_contains "ci/reverse/online_intake.py" 'default_branch'
  require_contains "ci/reverse/online_intake.py" 'froggingfamily_wine_tkg_git'
  require_contains "ci/reverse/generate-online-backlog.py" '"status"'
  require_contains "ci/reverse/generate-online-backlog.py" 'commit_scan_used'
  require_contains "ci/reverse/generate-online-backlog.py" '--commit-scan-json'
  require_contains "ci/reverse/check-online-backlog.py" 'missing_required_markers'
  require_contains "ci/reverse/check-online-backlog.py" 'missing_required_medium_markers'
  require_contains "ci/reverse/check-online-backlog.py" 'missing_required_low_markers'
  require_contains "ci/reverse/check-online-backlog.py" 'commit_scan_errors'
  require_contains "ci/reverse/check-online-backlog.py" '--require-high-markers'
  require_contains "ci/reverse/check-online-backlog.py" '--require-medium-markers'
  require_contains "ci/reverse/check-online-backlog.py" '--require-low-markers'
  require_contains "ci/reverse/check-online-backlog.py" '--fail-on-commit-scan-errors'
  require_contains "ci/reverse/check-online-backlog.py" '--require-medium-ready-validated'
  require_contains "ci/reverse/check-online-backlog.py" '--require-low-ready-validated'
  require_file "ci/reverse/online_commit_scan.py"
  require_file "ci/reverse/online-commit-scan.sh"
  [[ -x "ci/reverse/online-commit-scan.sh" ]] || fail "ci/reverse/online-commit-scan.sh must be executable"
  require_contains "ci/reverse/online-commit-scan.sh" 'ONLINE_COMMIT_SCAN_PROFILE'
  require_contains "ci/reverse/online-commit-scan.sh" 'ONLINE_COMMIT_SCAN_COMMITS_PER_REPO'
  require_contains "ci/reverse/online-commit-scan.sh" 'online_commit_scan\.py'
  require_contains "ci/reverse/online_commit_scan.py" 'fetch_commits_with_branch_fallback'
  require_contains "ci/reverse/online_commit_scan.py" 'branch_requested'
  require_contains "ci/reverse/online_commit_scan.py" 'default_branch'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_TRANSPORT:=gh'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_PROFILE:=all'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_SCOPE:=focused'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" '\$\{WLT_ONLINE_INTAKE_PROFILE\}" == "core"'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" '\$\{WLT_ONLINE_INTAKE_PROFILE\}" == "all"'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" '\$\{WLT_ONLINE_INTAKE_PROFILE\}" == "custom"'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_ALL_REPOS=1'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'requires WLT_ONLINE_INTAKE_ALIASES'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'online_medium_rows'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'online_medium_not_ready_validated'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'online_low_rows'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'online_low_not_ready_validated'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_CAPTURE_COMMIT_SCAN'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_COMMIT_SCAN_REQUIRED'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_COMMIT_SCAN_PROFILE'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_COMMIT_SCAN_COMMITS_PER_REPO'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_RUN_HARVEST'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_HARVEST_PROFILE'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_HARVEST_MAX_COMMITS_PER_REPO'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_HARVEST_APPLY'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_HARVEST_SKIP_NO_SYNC'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_HARVEST_AUTO_FOCUS_SYNC'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_HARVEST_INCLUDE_UNMAPPED'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_SYNC_BRANCH_PINS'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_ONLINE_INTAKE_HARVEST_FAIL_ON_REPO_ERRORS'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'WLT_CAPTURE_URC'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'commit_scan_rc'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'online-commit-scan\.sh'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'ONLINE_COMMIT_SCAN_AUTO=0'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'ONLINE_RUN_HARVEST'
  require_contains "ci/validation/collect-mainline-forensic-snapshot.sh" 'ONLINE_RUN_SNAPSHOT_AUDIT'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_RUN_URC'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_RUN_HARVEST'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_HARVEST_PROFILE'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_HARVEST_MAX_COMMITS_PER_REPO'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_HARVEST_APPLY'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_HARVEST_SKIP_NO_SYNC'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_HARVEST_AUTO_FOCUS_SYNC'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_HARVEST_INCLUDE_UNMAPPED'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_SYNC_BRANCH_PINS'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_HARVEST_FAIL_ON_REPO_ERRORS'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'ONLINE_COMMIT_SCAN_AUTO=0'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'ONLINE_RUN_HARVEST=0'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_RUN_URC'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_RUN_HARVEST'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_HARVEST_PROFILE'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_HARVEST_MAX_COMMITS_PER_REPO'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_HARVEST_APPLY'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_HARVEST_SKIP_NO_SYNC'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_HARVEST_AUTO_FOCUS_SYNC'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_HARVEST_INCLUDE_UNMAPPED'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_SYNC_BRANCH_PINS'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_HARVEST_FAIL_ON_REPO_ERRORS'
  require_contains "ci/validation/run-final-stage-gates.sh" 'ONLINE_COMMIT_SCAN_AUTO=0'
  require_contains "ci/validation/run-final-stage-gates.sh" 'ONLINE_RUN_HARVEST=0'
  [[ -x "ci/reverse/harvest-transfer.sh" ]] || fail "ci/reverse/harvest-transfer.sh must be executable"
  require_contains "docs/reverse/ONLINE_INTAKE_WORKFLOW.md" 'PATCH_TRANSFER_BACKLOG\.md'
  require_contains "docs/reverse/ONLINE_INTAKE_WORKFLOW.md" 'PATCH_TRANSFER_BACKLOG\.json'
  require_contains "docs/reverse/ONLINE_INTAKE_WORKFLOW.md" 'ONLINE_REQUIRED_MEDIUM_MARKERS'
  require_contains "docs/reverse/ONLINE_INTAKE_WORKFLOW.md" 'ONLINE_REQUIRED_LOW_MARKERS'
  require_contains "docs/reverse/ONLINE_INTAKE_WORKFLOW.md" 'ONLINE_REQUIRE_LOW_READY_VALIDATED'
  require_contains "docs/reverse/ONLINE_INTAKE_WORKFLOW.md" 'online-commit-scan\.sh'
  require_contains "docs/reverse/ONLINE_INTAKE_WORKFLOW.md" 'commit-scan\.json'
  require_contains "docs/README.md" 'online-commit-scan\.sh'
  python3 - "ci/reverse/online_intake_repos.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
if not isinstance(data, list) or not data:
    raise SystemExit("[urc-check][error] online_intake_repos.json must be a non-empty array")
if len(data) < 25:
    raise SystemExit("[urc-check][error] online_intake_repos.json must keep at least 25 default-enabled repos")
bad = []
aliases = set()
for idx, row in enumerate(data):
    if not isinstance(row, dict):
        bad.append(f"row[{idx}] must be object")
        continue
    alias = str(row.get("alias", "")).strip()
    if alias:
        aliases.add(alias)
    for key in ("alias", "owner", "repo"):
        val = str(row.get(key, "")).strip()
        if not val:
            bad.append(f"row[{idx}].{key} is required")
    if row.get("enabled_default") is not True:
        bad.append(f"row[{idx}].enabled_default must be true")
    focus = row.get("focus_paths", [])
    if focus is not None and not isinstance(focus, list):
        bad.append(f"row[{idx}].focus_paths must be array when set")
    elif isinstance(focus, list):
        if not focus:
            bad.append(f"row[{idx}].focus_paths must not be empty")
        for j, item in enumerate(focus):
            if not str(item).strip():
                bad.append(f"row[{idx}].focus_paths[{j}] must be non-empty string")
    pinned = row.get("pinned_commits", [])
    if pinned is not None and not isinstance(pinned, list):
        bad.append(f"row[{idx}].pinned_commits must be array when set")
    elif isinstance(pinned, list):
        for j, item in enumerate(pinned):
            s = str(item).strip().lower()
            if not s:
                bad.append(f"row[{idx}].pinned_commits[{j}] must be non-empty sha")
            elif any(ch not in '0123456789abcdef' for ch in s) or len(s) < 7:
                bad.append(f"row[{idx}].pinned_commits[{j}] must be hex sha (>=7 chars)")
required_aliases = {
    "coffin_winlator",
    "coffin_wine",
    "gamenative_protonwine",
    "froggingfamily_wine_tkg_git",
    "utkarsh_gamenative",
    "tkashkin_gamehub",
    "gamehublite_oss",
    "producdevity_gamehub_lite",
    "desms_termux_fex",
    "cheadrian_termux_chroot_wine_box",
    "olegos2_termux_box",
    "gamextra4u_fexdroid",
    "xhyn_exagear_302",
    "termux_x11",
    "termux_pacman_glibc_packages",
    "olegos2_mobox",
    "ilya114_box64droid",
    "ahmad1abbadi_darkos",
    "christianhaitian_darkos",
    "stevenmxz_turnip_ci",
    "whitebelyash_turnip_ci",
    "mrpurple_turnip",
    "horizonemu_horizon_emu",
    "kreitinn_micewine_application",
    "kreitinn_micewine",
    "kreitinn_micewine_rootfs_generator",
}
missing_aliases = sorted(required_aliases - aliases)
if missing_aliases:
    bad.append("missing required aliases: " + ", ".join(missing_aliases))
if bad:
    print("[urc-check][error] Invalid online intake repo contract:")
    for item in bad:
        print(f"[urc-check][error] - {item}")
    raise SystemExit(1)
PY
  WLT_HIGH_CYCLE_FETCH=0 \
  WLT_HIGH_CYCLE_PROFILE=all \
  WLT_HIGH_CYCLE_TRANSPORT=gh \
  WLT_HIGH_CYCLE_RUN_URC=0 \
  bash "ci/reverse/run-high-priority-cycle.sh" >/dev/null
  bash "ci/winlator/selftest-runtime-mismatch-matrix.sh"
  python3 "ci/validation/audit-nvapi-layout-shim.py" \
    --strict \
    --output /tmp/nvapi_layout_shim_audit.md >/dev/null
  python3 "ci/validation/audit-turnip-strict-bind-fallback.py" \
    --strict \
    --output /tmp/turnip_strict_bind_audit.md >/dev/null
  local mainline_patch="ci/winlator/patches/0001-mainline-full-stack-consolidated.patch"
  local turnip_bind_patch="ci/winlator/patches/0003-aeturnip-runtime-bind-and-forensics.patch"
  local upscaler_patch="ci/winlator/patches/0004-upscaler-adrenotools-control-plane-x11-bind.patch"
  local upscaler_matrix_patch="ci/winlator/patches/0005-upscaler-dxvk-proton-fsr-x11-turnip-runtime-matrix.patch"
  local upscaler_directs_patch="ci/winlator/patches/0006-upscaler-x11-turnip-dx-all-directs-memory-policy.patch"
  local upscaler_module_patch="ci/winlator/patches/0007-upscaler-module-forensics-dx8assist-contract.patch"
  local upscaler_policy_patch="ci/winlator/patches/0008-upscaler-dx-policy-order-and-artifact-sources.patch"
  local launch_graphics_patch="ci/winlator/patches/0009-launch-graphics-packet-dx-upscaler-x11-turnip-bundle.patch"
  local dxvk_caps_patch="ci/winlator/patches/0010-dxvk-capability-envelope-proton-fsr-gate-upscaler-matrix.patch"
  require_file "${mainline_patch}"
  require_contains_any 'RuntimeSignalContract' \
    "${mainline_patch}" \
    "docs/PATCH_STACK_RUNTIME_CONTRACT_AUDIT.md"
  require_contains_any 'WINLATOR_SIGNAL_POLICY' \
    "${mainline_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md" \
    "docs/EXTERNAL_SIGNAL_CONTRACT.md"
  require_contains_any 'WINLATOR_SIGNAL_INPUT_ROUTE' \
    "${mainline_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md" \
    "docs/EXTERNAL_SIGNAL_CONTRACT.md"
  require_contains_any 'internalType' \
    "${mainline_patch}" \
    "docs/CONTENT_PACKAGES_ARCHITECTURE.md"
  require_contains_any 'resolveInternalTypeName|normalizeInternalTypeName|MARK_INTERNAL_TYPE|internalType' \
    "${mainline_patch}" \
    "docs/CONTENT_PACKAGES_ARCHITECTURE.md"
  require_contains_any 'WINLATOR_VK_POLICY' \
    "${mainline_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'WINLATOR_VK_EFFECTIVE' \
    "${mainline_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'vulkanPolicy=force_latest' \
    "${mainline_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_TURNIP_PROVIDER' \
    "${mainline_patch}" \
    "${turnip_bind_patch}"
  require_contains_any 'AERO_TURNIP_BIND_MODE' \
    "${mainline_patch}" \
    "${turnip_bind_patch}"
  require_contains_any 'AERO_TURNIP_BIND_VERDICT' \
    "${mainline_patch}" \
    "${turnip_bind_patch}"
  require_contains_any 'TURNIP_RUNTIME_BOUND' \
    "${mainline_patch}" \
    "${turnip_bind_patch}"
  require_contains_any 'AERO_UPSCALE_PROFILE' \
    "${mainline_patch}" \
    "${upscaler_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_MEM_POLICY' \
    "${mainline_patch}" \
    "${upscaler_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_MODULES_ACTIVE' \
    "${mainline_patch}" \
    "${upscaler_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_MODULES_REQUESTED' \
    "${mainline_patch}" \
    "${launch_graphics_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'UPSCALE_PROFILE_RESOLVED' \
    "${mainline_patch}" \
    "${upscaler_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_PROTON_FSR_MODE' \
    "${mainline_patch}" \
    "${upscaler_matrix_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_PROTON_FSR_REQUESTED' \
    "${mainline_patch}" \
    "${upscaler_module_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DXVK_VERSION_SELECTED' \
    "${mainline_patch}" \
    "${upscaler_matrix_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DXVK_VERSION_REQUESTED' \
    "${mainline_patch}" \
    "${upscaler_policy_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DXVK_CAPS' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DXVK_ARTIFACT_ARCH' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DXVK_NVAPI_CONFIG' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DXVK_NVAPI_EFFECTIVE' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DXVK_NVAPI_ARCH_GATE' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DXVK_NVAPI_ARCH_REASON' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_VKD3D_VERSION_SELECTED' \
    "${mainline_patch}" \
    "${upscaler_matrix_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_VKD3D_VERSION_REQUESTED' \
    "${mainline_patch}" \
    "${upscaler_policy_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DX_DIRECT_MAP' \
    "${mainline_patch}" \
    "${upscaler_matrix_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DX_DIRECT_MAP_EXTENDED' \
    "${mainline_patch}" \
    "${upscaler_directs_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_RUNTIME_DISTRIBUTION' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_RUNTIME_FLAVOR' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_WINE_ARCH' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DX_DIRECT_MAP_REQUESTED' \
    "${mainline_patch}" \
    "${launch_graphics_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DX_ROUTE_DX8' \
    "${mainline_patch}" \
    "${upscaler_directs_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DX_ROUTE_DX1_REQUESTED' \
    "${mainline_patch}" \
    "${launch_graphics_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DX_ROUTE_DX12_REQUESTED' \
    "${mainline_patch}" \
    "${launch_graphics_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_D8VK_VERSION_SELECTED' \
    "${mainline_patch}" \
    "${upscaler_module_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_D8VK_VERSION_EFFECTIVE' \
    "${mainline_patch}" \
    "${launch_graphics_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_D8VK_VERSION_REQUESTED' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DDRAW_WRAPPER_REQUESTED' \
    "${mainline_patch}" \
    "${upscaler_policy_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DX8_ASSIST_REQUESTED' \
    "${mainline_patch}" \
    "${upscaler_module_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_DX8_ASSIST_REASON' \
    "${mainline_patch}" \
    "${upscaler_module_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_VKBASALT_REASON' \
    "${mainline_patch}" \
    "${upscaler_module_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_PROTON_FSR_REASON' \
    "${mainline_patch}" \
    "${upscaler_module_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_MEM_POLICY_EFFECTIVE' \
    "${mainline_patch}" \
    "${upscaler_directs_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DX_POLICY_ORDER' \
    "${mainline_patch}" \
    "${upscaler_policy_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DX_POLICY_STACK' \
    "${mainline_patch}" \
    "${upscaler_policy_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_DXVK_ARTIFACT_SOURCE' \
    "${mainline_patch}" \
    "${upscaler_policy_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'UPSCALE_MEMORY_POLICY_APPLIED' \
    "${mainline_patch}" \
    "${upscaler_directs_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'DX_WRAPPER_GRAPH_RESOLVED' \
    "${mainline_patch}" \
    "${upscaler_matrix_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'DX_WRAPPER_ARTIFACTS_APPLIED' \
    "${mainline_patch}" \
    "${upscaler_policy_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'UPSCALE_MODULE_APPLIED' \
    "${mainline_patch}" \
    "${upscaler_module_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'UPSCALE_MODULE_SKIPPED' \
    "${mainline_patch}" \
    "${upscaler_module_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_LAUNCH_GRAPHICS_PACKET_SHA256' \
    "${mainline_patch}" \
    "${launch_graphics_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_RUNTIME_MATRIX' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_LAYOUT_MODE' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_LAYOUT_NVAPI' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_LAYOUT_RUNTIME_FLAVOR' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_UPSCALE_LAYOUT_WINEDLLOVERRIDES_SHA256' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_LIBRARY_CONFLICTS' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_LIBRARY_CONFLICT_COUNT' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_LIBRARY_CONFLICT_SHA256' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_LIBRARY_REPRO_ID' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_RUNTIME_EMULATOR' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_RUNTIME_TRANSLATOR_CHAIN' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_RUNTIME_HODLL' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_RUNTIME_SUBSYSTEMS' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_RUNTIME_SUBSYSTEMS_SHA256' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_LIBRARY_COMPONENT_STREAM' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_LIBRARY_COMPONENT_STREAM_SHA256' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_LIBRARY_FASTPATH' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_RUNTIME_LOGGING_MODE' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_RUNTIME_LOGGING_REQUIRED' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_RUNTIME_LOGGING_COVERAGE' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'AERO_RUNTIME_LOGGING_COVERAGE_SHA256' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'LAUNCH_GRAPHICS_PACKET_READY' \
    "${mainline_patch}" \
    "${launch_graphics_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'DXVK_CAPS_RESOLVED' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'PROTON_FSR_HACK_RESOLVED' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'UPSCALE_RUNTIME_MATRIX_READY' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'UPSCALE_LIBRARY_LAYOUT_APPLIED' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'RUNTIME_LIBRARY_CONFLICT_SNAPSHOT' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'RUNTIME_LIBRARY_CONFLICT_DETECTED' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'RUNTIME_SUBSYSTEM_SNAPSHOT' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'RUNTIME_LOGGING_CONTRACT_SNAPSHOT' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'RUNTIME_LIBRARY_COMPONENT_SIGNAL' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'RUNTIME_LIBRARY_COMPONENT_CONFLICT' \
    "${mainline_patch}" \
    "${dxvk_caps_patch}" \
    "docs/UNIFIED_RUNTIME_CONTRACT.md"
  require_contains_any 'launch_graphics_packet_sha256' \
    "${mainline_patch}" \
    "${launch_graphics_patch}"
  require_contains "${mainline_patch}" 'SESSION_EXIT_REQUESTED'
  require_contains "${mainline_patch}" 'SESSION_EXIT_COMPLETED'
  require_contains "ci/winlator/ci-build-winlator-ludashi.sh" 'run-reflective-audits\.sh'
  require_contains "ci/winlator/ci-build-winlator-ludashi.sh" 'WINLATOR_PATCH_PREFLIGHT'
  require_contains "ci/winlator/ci-build-winlator-ludashi.sh" 'check-patch-stack\.sh'
  require_contains ".github/workflows/ci-winlator.yml" 'WINLATOR_PATCH_PREFLIGHT: "1"'
  require_contains ".github/workflows/ci-winlator.yml" 'patch-stack-preflight\.log'
  require_contains "ci/winlator/run-reflective-audits.sh" 'validate-patch-sequence\.sh'
  require_contains "ci/winlator/run-reflective-audits.sh" 'patch-stack-reflective-audit\.py'
  require_contains "ci/winlator/run-reflective-audits.sh" 'patch-stack-runtime-contract-audit\.py'
  require_contains "docs/README.md" 'PATCH_STACK_REFLECTIVE_AUDIT\.md'
  require_contains "docs/README.md" 'PATCH_STACK_RUNTIME_CONTRACT_AUDIT\.md'
  require_contains "docs/README.md" 'EXTERNAL_SIGNAL_CONTRACT\.md'
  require_contains "docs/README.md" 'forensic-adb-harvard-suite\.sh'
  require_contains "docs/README.md" 'adb-container-seed-matrix\.sh'
  require_contains "docs/README.md" 'adb-ensure-artifacts-latest\.sh'
  require_contains "docs/README.md" 'adb-network-source-diagnostics\.sh'
  require_contains "docs/README.md" 'forensic-runtime-conflict-contour\.py'
  require_contains "docs/README.md" 'HARVARD_RUNTIME_CONFLICT_BOARD\.md'
  require_contains "docs/README.md" 'check-patch-batches\.sh'
  require_contains "docs/README.md" 'run-patch-base-cycle\.sh'
  require_contains "docs/README.md" 'list-patch-phases\.sh'
  require_contains "docs/README.md" 'resolve-patch-phase\.sh'
  require_contains "docs/README.md" 'list-patch-batches\.sh'
  require_contains "docs/README.md" 'next-patch-batch\.sh'
  require_contains "docs/README.md" 'next-patch-number\.sh'
  require_contains "docs/README.md" 'prepare-release-patch-base\.sh'
  require_contains "docs/README.md" 'run-final-stage-gates\.sh'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'prepare-release-patch-base\.sh'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'WLT_ONLINE_REQUIRED_MEDIUM_MARKERS'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'WLT_ONLINE_REQUIRED_LOW_MARKERS'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'WLT_ONLINE_REQUIRE_LOW_READY_VALIDATED'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'WLT_CAPTURE_COMMIT_SCAN'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'WLT_COMMIT_SCAN_PROFILE'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'WLT_COMMIT_SCAN_COMMITS_PER_REPO'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'check-patch-batches\.sh'
  require_not_contains "docs/CI_FAILURE_PLAYBOOK.md" 'legacy `0008-contents-wcphub-overlay-single-track-wine-proton.patch`'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'run-patch-base-cycle\.sh'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'list-patch-phases\.sh'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'resolve-patch-phase\.sh'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'list-patch-batches\.sh'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'next-patch-batch\.sh'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'next-patch-number\.sh'
  require_contains "docs/README.md" 'reverse-compare-gamenative-baseline\.sh'
  require_contains "docs/README.md" 'reverse-wcp-package\.py'
  require_contains "docs/README.md" 'run-gamenative-proton104-reverse\.sh'
  require_file "docs/HARVARD_RUNTIME_CONFLICT_BOARD.md"
  require_contains "docs/HARVARD_RUNTIME_CONFLICT_BOARD.md" '^# Harvard Runtime Conflict Board'
  require_contains "docs/HARVARD_RUNTIME_CONFLICT_BOARD.md" 'Inbox -> Ready -> Doing -> Done'
  require_contains "docs/HARVARD_RUNTIME_CONFLICT_BOARD.md" 'Execution Report Snapshot'
  require_contains "docs/HARVARD_RUNTIME_CONFLICT_BOARD.md" 'Checklist \(Global Remaining\)'
  require_contains "AGENTS.md" 'Runtime Conflict Board'
  require_contains "AGENTS.md" 'HARVARD_RUNTIME_CONFLICT_BOARD\.md'
  require_contains "README.md" 'HARVARD_RUNTIME_CONFLICT_BOARD\.md'
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
  require_contains "docs/ADB_HARVARD_DEVICE_FORENSICS.md" 'runtime-conflict-contour\.'
  require_contains "docs/ADB_HARVARD_DEVICE_FORENSICS.md" 'WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE'
  check_winlator_audit_docs_sync
  require_file "ci/validation/inspect-wcp-runtime-contract.sh"
  [[ -x "ci/validation/inspect-wcp-runtime-contract.sh" ]] || fail "inspect-wcp-runtime-contract.sh must be executable"
  require_file "ci/validation/prepare-release-patch-base.sh"
  [[ -x "ci/validation/prepare-release-patch-base.sh" ]] || fail "prepare-release-patch-base.sh must be executable"
  require_contains "ci/validation/prepare-release-patch-base.sh" 'run-reflective-audits\.sh'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'check-urc-mainline-policy\.sh'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'online-intake\.sh'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'run-high-priority-cycle\.sh'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_RUN_PATCH_BASE'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_PATCH_BASE_PROFILE'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_PATCH_BASE_PHASE'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'run-patch-base-cycle\.sh'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'check-patch-stack\.sh'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'ONLINE_INTAKE_FETCH=0'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'ONLINE_INTAKE_TRANSPORT=gh'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'ONLINE_INTAKE_MODE=code-only'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'ONLINE_INTAKE_SCOPE='
  require_contains "ci/validation/prepare-release-patch-base.sh" 'ONLINE_BACKLOG_STRICT=1'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'ONLINE_REQUIRED_HIGH_MARKERS=x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'ONLINE_REQUIRED_MEDIUM_MARKERS=ContentProfile,REMOTE_PROFILES'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'ONLINE_REQUIRED_LOW_MARKERS='
  require_contains "ci/validation/prepare-release-patch-base.sh" 'ONLINE_REQUIRE_LOW_READY_VALIDATED='
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_HIGH_CYCLE_FETCH=0'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_HIGH_CYCLE_PROFILE=all'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_HIGH_CYCLE_TRANSPORT=gh'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_HIGH_CYCLE_REQUIRED_HIGH_MARKERS=x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_HIGH_CYCLE_REQUIRED_MEDIUM_MARKERS=ContentProfile,REMOTE_PROFILES'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_HIGH_CYCLE_REQUIRED_LOW_MARKERS='
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_HIGH_CYCLE_REQUIRE_LOW_READY_VALIDATED='
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_HIGH_CYCLE_RUN_URC=0'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_RUN_COMMIT_SCAN'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_COMMIT_SCAN_PROFILE'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'WLT_RELEASE_PREP_COMMIT_SCAN_COMMITS_PER_REPO'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'online-commit-scan\.sh'
  require_contains "ci/validation/prepare-release-patch-base.sh" 'summary\.meta'
  require_file "ci/validation/run-final-stage-gates.sh"
  [[ -x "ci/validation/run-final-stage-gates.sh" ]] || fail "run-final-stage-gates.sh must be executable"
  require_contains "ci/validation/run-final-stage-gates.sh" 'run-reflective-audits\.sh'
  require_contains "ci/validation/run-final-stage-gates.sh" 'check-manifest-contract\.py'
  require_contains "ci/validation/run-final-stage-gates.sh" 'check-urc-mainline-policy\.sh'
  require_contains "ci/validation/run-final-stage-gates.sh" 'online-intake\.sh'
  require_contains "ci/validation/run-final-stage-gates.sh" 'run-high-priority-cycle\.sh'
  require_contains "ci/validation/run-final-stage-gates.sh" 'prepare-release-patch-base\.sh'
  require_contains "ci/validation/run-final-stage-gates.sh" 'collect-mainline-forensic-snapshot\.sh'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_SCOPE'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_REQUIRED_LOW_MARKERS'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_RUN_COMMIT_SCAN'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_COMMIT_SCAN_PROFILE'
  require_contains "ci/validation/run-final-stage-gates.sh" 'WLT_FINAL_STAGE_COMMIT_SCAN_COMMITS_PER_REPO'
  require_contains "ci/validation/run-final-stage-gates.sh" 'commit_scan_rc'
  require_contains "ci/validation/run-final-stage-gates.sh" 'online-commit-scan\.sh'
  require_file "ci/winlator/check-patch-batches.sh"
  [[ -x "ci/winlator/check-patch-batches.sh" ]] || fail "check-patch-batches.sh must be executable"
  require_contains "ci/winlator/check-patch-batches.sh" 'WINLATOR_PATCH_BATCH_PLAN_FILE'
  require_contains "ci/winlator/check-patch-batches.sh" 'WINLATOR_PATCH_BATCH_PHASE'
  require_contains "ci/winlator/check-patch-batches.sh" 'WINLATOR_PATCH_BATCH_PROFILE'
  require_contains "ci/winlator/check-patch-batches.sh" 'WINLATOR_PATCH_BATCH_SIZE'
  require_contains "ci/winlator/check-patch-batches.sh" 'WINLATOR_PATCH_BATCH_MODE'
  require_contains "ci/winlator/check-patch-batches.sh" 'WINLATOR_PATCH_BATCH_OUT_FILE'
  require_contains "ci/winlator/check-patch-batches.sh" 'apply-repo-patches\.sh'
  require_contains "ci/winlator/check-patch-batches.sh" 'WINLATOR_PATCH_FROM'
  require_contains "ci/winlator/check-patch-batches.sh" 'WINLATOR_PATCH_TO'
  require_file "ci/winlator/patch-batch-plan.tsv"
  require_contains "ci/winlator/patch-batch-plan.tsv" '^foundation[[:space:]]'
  require_contains "ci/winlator/patch-batch-plan.tsv" '^runtime_policy[[:space:]]'
  require_contains "ci/winlator/patch-batch-plan.tsv" '^contracts_finish[[:space:]]'
  require_contains "ci/winlator/patch-batch-plan.tsv" '^harvard_followup[[:space:]]'
  require_file "ci/winlator/run-patch-base-cycle.sh"
  [[ -x "ci/winlator/run-patch-base-cycle.sh" ]] || fail "run-patch-base-cycle.sh must be executable"
  require_contains "ci/winlator/run-patch-base-cycle.sh" 'WINLATOR_PATCH_BASE_PROFILE'
  require_contains "ci/winlator/run-patch-base-cycle.sh" 'WINLATOR_PATCH_BASE_PHASE'
  require_contains "ci/winlator/run-patch-base-cycle.sh" 'WINLATOR_PATCH_BASE_SANITIZE'
  require_contains "ci/winlator/run-patch-base-cycle.sh" 'phase-summary\.tsv'
  require_contains "ci/winlator/run-patch-base-cycle.sh" 'check-patch-batches\.sh'
  require_contains "ci/winlator/run-patch-base-cycle.sh" 'sanitize-patch-stack\.sh'
  require_contains "ci/winlator/run-patch-base-cycle.sh" 'patch-batch-plan\.tsv'
  require_file "ci/winlator/sanitize-patch-stack.sh"
  [[ -x "ci/winlator/sanitize-patch-stack.sh" ]] || fail "sanitize-patch-stack.sh must be executable"
  require_contains "ci/winlator/sanitize-patch-stack.sh" 'WINLATOR_PATCH_SANITIZE_DRY_RUN'
  require_contains "ci/winlator/sanitize-patch-stack.sh" '\.rej/\.orig'
  require_file "ci/winlator/list-patch-phases.sh"
  [[ -x "ci/winlator/list-patch-phases.sh" ]] || fail "list-patch-phases.sh must be executable"
  require_contains "ci/winlator/list-patch-phases.sh" 'phase[[:space:]]+first[[:space:]]+last'
  require_file "ci/winlator/resolve-patch-phase.sh"
  [[ -x "ci/winlator/resolve-patch-phase.sh" ]] || fail "resolve-patch-phase.sh must be executable"
  require_contains "ci/winlator/resolve-patch-phase.sh" 'phase='
  require_contains "ci/winlator/resolve-patch-phase.sh" 'first='
  require_contains "ci/winlator/resolve-patch-phase.sh" 'last='
  require_file "ci/winlator/list-patch-batches.sh"
  [[ -x "ci/winlator/list-patch-batches.sh" ]] || fail "list-patch-batches.sh must be executable"
  require_contains "ci/winlator/list-patch-batches.sh" 'WINLATOR_PATCH_BATCH_PLAN_FILE'
  require_contains "ci/winlator/list-patch-batches.sh" 'WINLATOR_PATCH_BATCH_PHASE'
  require_contains "ci/winlator/list-patch-batches.sh" 'WINLATOR_PATCH_BATCH_PROFILE'
  require_contains "ci/winlator/list-patch-batches.sh" 'WINLATOR_PATCH_BATCH_SIZE'
  require_contains "ci/winlator/list-patch-batches.sh" 'batch(\\t|[[:space:]])+first_idx'
  require_file "ci/winlator/next-patch-batch.sh"
  [[ -x "ci/winlator/next-patch-batch.sh" ]] || fail "next-patch-batch.sh must be executable"
  require_contains "ci/winlator/next-patch-batch.sh" 'WINLATOR_PATCH_BATCH_CURSOR'
  require_contains "ci/winlator/next-patch-batch.sh" 'list-patch-batches\.sh'
  require_contains "ci/winlator/next-patch-batch.sh" 'cursor_next='
  require_file "ci/winlator/next-patch-number.sh"
  [[ -x "ci/winlator/next-patch-number.sh" ]] || fail "next-patch-number.sh must be executable"
  require_contains "ci/winlator/next-patch-number.sh" 'next_number='
  require_contains "ci/winlator/next-patch-number.sh" 'suggested_file='
  require_file "ci/winlator/create-slice-patch.sh"
  [[ -x "ci/winlator/create-slice-patch.sh" ]] || fail "create-slice-patch.sh must be executable"
  require_contains "ci/winlator/create-slice-patch.sh" 'rsync -a --delete --exclude'
  require_contains "ci/winlator/create-slice-patch.sh" 'apply-repo-patches\.sh'
  require_contains "ci/winlator/create-slice-patch.sh" 'next-patch-number\.sh'
  require_contains "ci/winlator/create-slice-patch.sh" 'validate-patch-sequence\.sh'
  require_file "ci/winlator/fold-into-mainline.sh"
  [[ -x "ci/winlator/fold-into-mainline.sh" ]] || fail "fold-into-mainline.sh must be executable"
  require_contains "ci/winlator/fold-into-mainline.sh" 'WINLATOR_FOLD_DROP_SLICES'
  require_contains "ci/winlator/fold-into-mainline.sh" '0001-mainline-full-stack-consolidated.patch'
  require_contains "ci/winlator/check-patch-stack.sh" 'WINLATOR_PATCH_PLAN_FILE'
  require_contains "ci/winlator/check-patch-stack.sh" 'WINLATOR_PATCH_PHASE'
  require_contains "ci/winlator/check-patch-stack.sh" 'WINLATOR_PATCH_FROM'
  require_contains "ci/winlator/check-patch-stack.sh" 'WINLATOR_PATCH_TO'
  require_contains "ci/winlator/check-patch-stack.sh" 'WINLATOR_PATCH_SANITIZE'
  require_contains "ci/winlator/check-patch-stack.sh" 'sanitize-patch-stack\.sh'
  require_contains "ci/winlator/apply-repo-patches.sh" 'WINLATOR_PATCH_FROM'
  require_contains "ci/winlator/apply-repo-patches.sh" 'WINLATOR_PATCH_TO'
  require_not_contains "ci/winlator/apply-repo-patches.sh" '0008-contents-wcphub-overlay-single-track-wine-proton.patch'
  require_file "ci/runtime-sources/resolve-bionic-donor.sh"
  [[ -x "ci/runtime-sources/resolve-bionic-donor.sh" ]] || fail "resolve-bionic-donor.sh must be executable"
  require_contains "ci/validation/inspect-wcp-runtime-contract.sh" '--strict-gamenative'
  require_contains "ci/validation/inspect-wcp-runtime-contract.sh" 'gamenativeBaseline'
  require_contains "docs/UNIFIED_RUNTIME_CONTRACT.md" '--strict-gamenative'
  require_contains "docs/PROTON10_WCP.md" '--strict-gamenative'
  require_contains "docs/PROTON10_WCP.md" 'inspect-wcp-runtime-contract.sh'
  require_contains "docs/CI_FAILURE_PLAYBOOK.md" 'adb-network-source-diagnostics\.sh'

  require_file "docs/REFLECTIVE_HARVARD_LEDGER.md"
  require_contains "docs/REFLECTIVE_HARVARD_LEDGER.md" 'Hypothesis'
  require_contains "docs/REFLECTIVE_HARVARD_LEDGER.md" 'Counter-evidence'
  require_contains "docs/REFLECTIVE_HARVARD_LEDGER.md" 'bionic-donor-contract-hardening'

  local winlator_line version_patch
  winlator_line="$(detect_winlator_release_line)"
  version_patch="$(detect_winlator_version_patch)"
  require_file "${version_patch}"
  require_contains "${version_patch}" "versionName \"${winlator_line}(\\+)?\""

  require_file "ci/release/publish-${winlator_line}.sh"
  require_file "ci/release/prepare-${winlator_line}-notes.sh"

  grep -qF "${winlator_line}" ".github/workflows/ci-winlator.yml" || fail "Missing ${winlator_line} in .github/workflows/ci-winlator.yml"
  grep -qF "v${winlator_line}" "README.md" || fail "Missing v${winlator_line} in README.md"
  require_file "docs/assets/winlator-cmod-aesolator-logo.png"
  [[ ! -f "docs/assets/winlator-cmod-aeroso-logo.png" ]] || fail "Legacy logo file must be removed: docs/assets/winlator-cmod-aeroso-logo.png"
  require_contains "README.md" 'docs/assets/winlator-cmod-aesolator-logo\.png'
  require_contains "README.md" '^# Ae\.solator$'
  require_contains "README.md" 'unix-module-abi.tsv'
  require_contains "README.md" 'inspect-wcp-runtime-contract.sh'

  log "URC mainline policy checks passed"
}

main "$@"
