# CI Failure Playbook (WCP)

Use this playbook for `wine`, `proton-ge10`, and `protonwine10` workflow failures.

## 0) Freeze patch-base before release work

Before touching runtime fixes for a release line, run:

- `bash ci/validation/prepare-release-patch-base.sh`
- `bash ci/validation/run-final-stage-gates.sh`

This produces one local bundle with:
- reflective audits,
- URC mainline checks,
- strict no-fetch online intake,
- strict no-fetch high-priority cycle,
- optional online commit-scan (GitHub API, no clone),
- optional Winlator patch-stack preflight when `work/winlator-ludashi/src` is present,
- optional named patch-base phase cycle (`WLT_RELEASE_PREP_RUN_PATCH_BASE=1`).

`run-final-stage-gates.sh` wraps the same gates plus GN manifest contract and optional snapshot capture in one pre-push run.

For day-to-day patch-base bring-up, prefer the lighter local flow first:

- `bash ci/winlator/check-patch-stack.sh /path/to/upstream/winlator/checkout` (single-patch base sanity)
- `bash ci/winlator/check-patch-batches.sh /path/to/upstream/winlator/checkout`
- `WINLATOR_PATCH_BATCH_SIZE=7 bash ci/winlator/check-patch-batches.sh /path/to/upstream/winlator/checkout`
- `WINLATOR_PATCH_BATCH_MODE=single bash ci/winlator/check-patch-batches.sh /path/to/upstream/winlator/checkout`
- `WINLATOR_PATCH_BASE_PROFILE=wide bash ci/winlator/run-patch-base-cycle.sh /path/to/upstream/winlator/checkout`
- `WINLATOR_PATCH_BASE_PHASE=runtime_policy bash ci/winlator/run-patch-base-cycle.sh /path/to/upstream/winlator/checkout`
- `WINLATOR_PATCH_BATCH_PHASE=runtime_policy bash ci/winlator/check-patch-batches.sh /path/to/upstream/winlator/checkout`
- `WINLATOR_PATCH_PHASE=runtime_policy bash ci/winlator/check-patch-stack.sh /path/to/upstream/winlator/checkout`
- `bash ci/winlator/list-patch-phases.sh`
- `bash ci/winlator/resolve-patch-phase.sh runtime_policy`
- `WINLATOR_PATCH_BATCH_PROFILE=wide bash ci/winlator/list-patch-batches.sh`
- `WINLATOR_PATCH_BATCH_CURSOR=1 bash ci/winlator/next-patch-batch.sh`
- `bash ci/winlator/next-patch-number.sh ci/winlator/patches <slug>`
- `bash ci/winlator/create-slice-patch.sh /path/to/upstream/winlator/checkout <slug>` (create temporary `0002+` slice from local tree delta)
- `bash ci/winlator/fold-into-mainline.sh /path/to/upstream/winlator/checkout` (fold temporary `0002+` slices back into `0001`)

## 1) Build fails in `programs/winebrowser/main.c`

Symptom:
- `send(..., &net_requestcode, ...)` incompatible pointer type errors.

Action:
1. Ensure patchset stage ran (`GameNative patchset mode` is logged).
2. Verify mode:
   - `WCP_GN_PATCHSET_ENABLE=1` -> `full`
   - `WCP_GN_PATCHSET_ENABLE=0` -> `normalize-only` (still applies safety normalization).
3. Re-run local normalization by invoking:
   - `bash ci/gamenative/apply-android-patchset.sh --target wine --source-dir <wine-src>`

## 2) Build fails in `dlls/winex11.drv/mouse.c`

Symptom:
- `pXFixesHideCursor` / `pXFixesShowCursor` undeclared.

Action:
1. Confirm `normalize_winex11_mouse_xfixes_calls` executed in patchset logs.
2. Confirm guard upgrade executed (`xfixes-soname-guard-fix` in patchset TSV report).
3. Ensure source uses the combined guard around both calls:
   - `#if defined(HAVE_X11_EXTENSIONS_XFIXES_H) && defined(SONAME_LIBXFIXES)`
4. Re-run workflow after patchset normalization fix.

## 3) Patchset normalization contract fails early

Symptom:
- `post-normalization contract checks failed` from `apply-android-patchset.sh`.

Action:
1. Inspect the failing items printed by the script (`winebrowser`, `winex11`, `winnt` checks).
2. Verify `programs/winebrowser/main.c` no longer has:
   - `send(..., &net_requestcode, ...)`
   - `send(..., &net_data_length, ...)`
   - typo `WINE_OPEN_WITH_ANDROID_BROwSER`
3. Re-run patchset stage locally, then retry CI.
4. Run the normalizer selftest to catch script-level regressions quickly:
   - `bash ci/gamenative/selftest-normalizers.sh`

## 4) Runtime check fails: missing `winebus.so`

Symptom:
- `SDL2 runtime check failed: missing .../winebus.so`.

Action:
1. Treat as upstream compile/install failure, not SDL packaging root cause.
2. Inspect the first compile error in `out/*/logs/wine-build.log`.
3. Fix compile break, then re-run; `winebus.so` check should pass automatically.

## 5) Patchset conflicts / divergence

Action:
1. Generate overlap + manifest sanity report:
   - `python3 ci/gamenative/patchset-conflict-audit.py --output docs/PATCHSET_CONFLICT_REPORT.md`
2. Keep file-level patch ownership only in `ci/gamenative/apply-android-patchset.sh`.
3. Remove ad-hoc per-package source edits if they duplicate manifest-owned files.

## 6) Fast triage checklist

- Check workflow input `gn_patchset_enable`.
- Check patchset mode in logs (`full` vs `normalize-only`).
- Run `bash ci/gamenative/selftest-normalizers.sh` before expensive re-runs.
- Check first real compile error (ignore cascading missing artifact errors).
- Confirm `gamenative-patchset-*.tsv` report artifact is uploaded.
- Check `out/*/logs/gamenative-baseline-reverse.md` (if present) for binary-level drift vs GameNative Proton 10.4 baseline.

## 7) Parse raw job logs quickly

When you have a raw GitHub Actions job log URL (or downloaded log file), extract the real failure lines with:

- `bash ci/validation/extract-gh-job-failures.sh "<raw-job-log-url>"`
- `bash ci/validation/extract-gh-job-failures.sh /path/to/job-logs.txt`

Use this before deep diffing so you do not chase secondary cascade errors.

## 7.1) Reverse-compare target artifact vs GameNative Proton 10.4 baseline

When build succeeds but runtime behavior drifts, run:

- `bash ci/validation/reverse-compare-gamenative-baseline.sh out/wine/wine-11-arm64ec.wcp out/wine/logs`
- `bash ci/validation/reverse-compare-gamenative-baseline.sh out/proton-ge10/proton-ge10-arm64ec.wcp out/proton-ge10/logs`
- `bash ci/validation/reverse-compare-gamenative-baseline.sh out/protonwine10/protonwine10-gamenative-arm64ec.wcp out/protonwine10/logs`

Outputs:
- `gamenative-baseline-reverse.md` - compact diff report (`runtimeClass`, launcher runpaths, key DLL symbol/export deltas).
- `gamenative-baseline-reverse.json` - machine-readable diff for automation.

If reverse diff shows launcher runpath drift (`/data/data/com.winlator.cmod/files/imagefs/usr/lib` etc.), run strict check locally:

- `WCP_STRICT_RUNPATH_CONTRACT=1 WCP_RUNPATH_ACCEPT_REGEX='^/data/data/com\.termux/files/usr/lib$' bash ci/validation/inspect-wcp-runtime-contract.sh <artifact.wcp> --strict-bionic --strict-gamenative`

## 7.2) Inspect step fails with `llvm-readobj/readelf unavailable`

Symptom:
- `Strict gamenative check failed: llvm-readobj/readelf unavailable` in `Inspect WCP runtime contract`.

Action:
1. Ensure llvm-mingw toolchain has been restored before inspect step.
2. Verify one of these exists:
   - `${TOOLCHAIN_DIR}/bin/llvm-readobj`
   - `${TOOLCHAIN_DIR}/bin/llvm-readelf`
   - `${CACHE_DIR}/llvm-mingw/bin/llvm-readobj`
   - `${CACHE_DIR}/llvm-mingw/bin/llvm-readelf`
   - `.cache/llvm-mingw/bin/llvm-readobj`
   - `.cache/llvm-mingw/bin/llvm-readelf`
3. Re-run failed workflow only after cache/toolchain restore is healthy.

## 8) Pull latest failed runs automatically

To fetch recent failed runs and auto-parse their first failed job logs:

- `bash ci/validation/gh-latest-failures.sh`
- `bash ci/validation/gh-latest-failures.sh 5`
- `bash ci/validation/gh-latest-failures.sh 20 main 24`
- `WLT_FAILURES_OUTPUT_PREFIX=/tmp/gh-active-failures bash ci/validation/gh-latest-failures.sh 20 main 24`
- `WLT_AUTO_TRIAGE_FAILED_RUNS=1 WLT_AUTO_TRIAGE_MAX_RUNS=3 WLT_AUTO_TRIAGE_MAX_JOBS=3 bash ci/validation/gh-latest-failures.sh 20 main 24`

This is the fast path before manual `gh run view ... --log` triage.

Use the third argument (`since_hours`) to filter stale failures and focus only on fresh regressions.
The command now reports only workflows whose latest run is still failed (active failure state).
With `WLT_FAILURES_OUTPUT_PREFIX`, it also writes `.tsv` + `.meta` snapshots for automation.
With `WLT_AUTO_TRIAGE_FAILED_RUNS=1`, it also runs run-scoped root-cause triage for active failed runs.

## 8.1) Check mainline workflow health before deep triage

- `bash ci/validation/gh-mainline-health.sh`
- `bash ci/validation/gh-mainline-health.sh main 24`
- `WLT_HEALTH_OUTPUT_PREFIX=/tmp/mainline-health bash ci/validation/gh-mainline-health.sh main 24`

This validates the latest run status of the four critical workflows and fails if any is not `fresh + success`.

## 8.2) Triage a specific failed run in one command

When you already have a run ID/URL and need job-level root causes:

- `bash ci/validation/gh-run-root-cause.sh 22446750044`
- `bash ci/validation/gh-run-root-cause.sh "https://github.com/<org>/<repo>/actions/runs/22446750044"`
- `WLT_RUN_TRIAGE_DIR=/tmp/gh-run-triage bash ci/validation/gh-run-root-cause.sh 22446750044 5`

Outputs include:
- `failed-jobs.tsv` with failed/cancelled/timed_out jobs.
- per-job `*.analysis.txt` generated via `extract-gh-job-failures.sh`.
- `root-cause-summary.tsv` for fast patch routing.
- `root-cause-summary.json` with machine-readable `category/root_cause/first_hard_marker_line`.

## 9) Runtime crash matrix (device-side)

For runtime startup/crash triage across `wine11`, `protonwine10`, and `gamenative104`:

- `bash ci/winlator/forensic-adb-runtime-contract.sh`
- `WLT_FAIL_ON_MISMATCH=1 bash ci/winlator/forensic-adb-runtime-contract.sh`
- `bash ci/winlator/selftest-runtime-mismatch-matrix.sh`

Outputs:
- Complete per-scenario forensic capture (`logcat`, `wait-status`, `forensics tail`).
- `runtime-mismatch-matrix.tsv`, `runtime-mismatch-matrix.md`, and `runtime-mismatch-matrix.json` with baseline comparison.
- `runtime-mismatch-matrix.summary.txt` with status/severity aggregate counters.
- Matrix rows include `patch_hint` (file-level fix target) to speed direct patch routing.
- Matrix rows include `severity_rank` for deterministic severity threshold gates.
- Runtime orchestrator console now prints non-baseline actionable rows as `status|severity|label|patch_hint|mismatch_keys`.
- With `WLT_FAIL_ON_MISMATCH=1`, exits non-zero when non-baseline scenarios drift from baseline contract.
- With `WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE=medium|high`, exits non-zero when drift severity reaches threshold.
- `selftest-runtime-mismatch-matrix.sh` validates classifier behavior and exit contract without adb/device.
- Scenario format in `WLT_SCENARIOS` is strict: `label:containerId` (numeric container id).
- Labels are sanitized to safe folder names in output artifacts (`safe_label` stored in `scenario_meta.txt`).

## 10) One-shot forensic snapshot (mainline)

To collect a single consolidated snapshot (`health + active failures + urc check + git state`):

- `bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_TRIAGE_ACTIVE_RUNS=1 WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_ONLINE_INTAKE=1 WLT_ONLINE_INTAKE_REQUIRED=1 WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_ONLINE_INTAKE=1 WLT_ONLINE_INTAKE_FETCH=0 WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_ONLINE_INTAKE=1 WLT_ONLINE_INTAKE_FETCH=1 WLT_ONLINE_INTAKE_MODE=code-only WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_ONLINE_INTAKE=1 WLT_ONLINE_INTAKE_TRANSPORT=gh WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_ONLINE_INTAKE=1 WLT_ONLINE_INTAKE_TRANSPORT=git WLT_ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC=600 WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_ONLINE_INTAKE=1 WLT_ONLINE_BACKLOG_STRICT=1 WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_ONLINE_INTAKE=1 WLT_ONLINE_BACKLOG_STRICT=1 WLT_ONLINE_REQUIRED_HIGH_MARKERS=x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_ONLINE_INTAKE=1 WLT_ONLINE_BACKLOG_STRICT=1 WLT_ONLINE_REQUIRED_MEDIUM_MARKERS=ContentProfile,REMOTE_PROFILES WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_ONLINE_INTAKE=1 WLT_ONLINE_INTAKE_USE_HIGH_CYCLE=1 WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_ONLINE_INTAKE=1 WLT_ONLINE_INTAKE_PROFILE=all WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_ONLINE_INTAKE=1 WLT_ONLINE_INTAKE_PROFILE=core WLT_ONLINE_INTAKE_ALIASES=coffin_wine,gamenative_protonwine WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_ONLINE_INTAKE=1 WLT_ONLINE_INTAKE_ALIASES=coffin_wine,gamenative_protonwine WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_CAPTURE_COMMIT_SCAN=1 WLT_COMMIT_SCAN_PROFILE=core WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_SNAPSHOT_FAIL_MODE=capture-only WLT_SNAPSHOT_DIR=/tmp/mainline-forensic-snapshot bash ci/validation/collect-mainline-forensic-snapshot.sh`
- `WLT_HIGH_CYCLE_FETCH=0 ci/reverse/run-high-priority-cycle.sh` (strict backlog + high/medium marker gate without network fetch)

Generated in snapshot dir:
- `mainline-health.tsv/.json`
- `active-failures.tsv/.meta`
- `health.log`, `active-failures.log`, `urc-check.log`
- `snapshot.meta`, `status.meta`, `git-head.txt`, `git-status.txt`
- If `WLT_TRIAGE_ACTIVE_RUNS=1`: `run-triage/run-<id>/` artifacts + `run-triage/run-<id>.log`
- If `WLT_CAPTURE_ONLINE_INTAKE=1`: `online-intake/combined-matrix.{md,json}` + per-repo online reports.
- `WLT_ONLINE_INTAKE_REQUIRED=1` upgrades online-intake from best-effort to required gate.
- `WLT_ONLINE_INTAKE_FETCH=0` skips network pull and only regenerates backlog from existing combined matrix.
- With `WLT_ONLINE_INTAKE_FETCH=0`, snapshot run seeds `online-intake/combined-matrix.json`
  from repo baseline (`docs/reverse/online-intake/combined-matrix.json`) when snapshot dir is empty.
- `WLT_ONLINE_INTAKE_MODE=code-only` keeps intake focused on raw file parsing; `full` adds commit-diff scan.
- `WLT_ONLINE_INTAKE_SCOPE=focused` is default (only per-repo `focus_paths[]` + fallback); `tree` forces full tree scan.
- `WLT_ONLINE_INTAKE_TRANSPORT=gh` keeps no-clone API intake (default); `git` enables targeted shallow git fetch mode.
- `WLT_ONLINE_INTAKE_GIT_DEPTH` controls shallow history window for commit-centric scans.
- `WLT_ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC` controls fetch timeout for slow upstream links.
- `WLT_ONLINE_INTAKE_ALIASES` limits intake to selected aliases from `ci/reverse/online_intake_repos.json`.
- `WLT_ONLINE_INTAKE_USE_HIGH_CYCLE=1` routes snapshot intake via `ci/reverse/run-high-priority-cycle.sh`.
- `WLT_ONLINE_INTAKE_PROFILE=core|all|custom` controls high-cycle repo selection strategy.
- `WLT_ONLINE_INTAKE_PROFILE=custom` requires `WLT_ONLINE_INTAKE_ALIASES` (comma-separated).
- `WLT_CAPTURE_COMMIT_SCAN=1` runs online commit-scan into `online-intake/commit-scan.{md,json}`.
- `WLT_COMMIT_SCAN_REQUIRED=1` upgrades commit-scan from best-effort to required gate.
- `WLT_COMMIT_SCAN_PROFILE=core|all|custom` controls repo selection for commit scan.
- `WLT_COMMIT_SCAN_COMMITS_PER_REPO` controls commit window depth per repo.
- `WLT_CAPTURE_URC=0` (default) keeps snapshot path focused on intake/triage speed; set `1` only when policy drift is suspected.
- When commit scan is available, backlog rows now include `Focus/Commits` hit split and source-tagged evidence (`focus` vs `commit_scan`).
- `PATCH_TRANSFER_BACKLOG.json` exports `commit_scan_used` and `commit_scan_errors` for strict gating/reporting.
- `WLT_ONLINE_BACKLOG_STRICT=1` makes intake fail if high rows stay in `needs_review`, high/medium rows are not `ready_validated`, or intake reports contain errors.
- `WLT_ONLINE_REQUIRED_HIGH_MARKERS` enforces presence of mandatory high-priority markers during strict gate.
- `WLT_ONLINE_REQUIRED_MEDIUM_MARKERS` enforces presence of mandatory medium-priority markers during strict gate.
- `WLT_ONLINE_REQUIRED_LOW_MARKERS` optionally enforces presence of low-priority markers during strict gate.
- `WLT_ONLINE_REQUIRE_LOW_READY_VALIDATED=1` enforces `ready_validated` status for low-priority rows.
- With commit-scan merged (`ONLINE_INCLUDE_COMMIT_SCAN=1`), strict mode also fails on `commit_scan_errors > 0`.
- `status.meta` now includes `online_high_rows`, `online_high_not_ready_validated`, `online_medium_rows`, `online_medium_not_ready_validated`, `online_low_rows`, and `online_low_not_ready_validated` for quick strict-gate visibility.
- `check-urc-mainline-policy.sh` runs a no-fetch smoke of `run-high-priority-cycle.sh` (`profile=all`) to keep intake gate wiring healthy.
- `WLT_SNAPSHOT_FAIL_MODE=strict|capture-only` controls whether snapshot command exits non-zero on failed checks.

### Targeted integration harvest (commit-driven transfer)

Use this when patch-base work should prioritize upstream commit deltas over extra policy gates:

- `HARVEST_TRANSFER_PROFILE=core HARVEST_TRANSFER_APPLY=1 bash ci/reverse/harvest-transfer.sh`
- `HARVEST_TRANSFER_PROFILE=custom HARVEST_TRANSFER_ALIASES=gamenative_protonwine HARVEST_TRANSFER_APPLY=1 bash ci/reverse/harvest-transfer.sh`
- map file: `ci/reverse/transfer_map.json`
- outputs: `docs/reverse/online-intake/harvest/transfer-report.{md,json}` + per-commit harvested artifacts

Example strict intake with low-priority gate:

```bash
WLT_CAPTURE_ONLINE_INTAKE=1 \
WLT_ONLINE_INTAKE_REQUIRED=1 \
WLT_ONLINE_BACKLOG_STRICT=1 \
WLT_ONLINE_INTAKE_SCOPE=focused \
WLT_ONLINE_REQUIRED_LOW_MARKERS=DXVK,D8VK,VKD3D,PROOT_TMP_DIR,BOX64_LOG,WINEDEBUG,MESA_VK_WSI_PRESENT_MODE,TU_DEBUG,WINE_OPEN_WITH_ANDROID_BROWSER \
WLT_ONLINE_REQUIRE_LOW_READY_VALIDATED=1 \
bash ci/validation/collect-mainline-forensic-snapshot.sh
```

## 11) Device VPN/source diagnostics (contents/adrenotools outages)

When users report empty source lists or stalled downloads under VPN/DNS changes:

- `ADB_SERIAL=<device> WLT_PACKAGE=by.aero.so.benchmark bash ci/winlator/adb-network-source-diagnostics.sh`
- Artifacts:
  - `endpoint-probes.tsv` (per-endpoint HTTP/DNS/TLS timings + curl status),
  - `endpoint-probes.summary.json` (status/code aggregates),
  - connectivity/proxy/private-DNS snapshots (`dumpsys-connectivity.txt`, `global-http-proxy.txt`, `global-private-dns-*.txt`).
- For full scenario capture, keep `WLT_CAPTURE_NETWORK_DIAG=1` in `ci/winlator/forensic-adb-harvard-suite.sh`.

## 12) Winlator patch-stack drift before Gradle

Symptom:
- `Build Winlator Ludashi fork APK` fails before Gradle with patch apply errors.

Action:
1. Check `out/winlator/logs/patch-stack-preflight.log` first.
2. If preflight fails, treat it as upstream drift in the Winlator patch stack, not a Gradle failure.
3. Re-run `bash ci/winlator/check-patch-stack.sh <winlator-src-git-dir>` locally against the pinned upstream ref and fix the first rejected patch.
4. If the first rejection is the contents-branding block inside `0001-mainline-full-stack-consolidated.patch` and only `strings.xml` drifts, prefer updating the bounded reject-heal in `ci/winlator/apply-repo-patches.sh` instead of broadening patch context across the whole file.
