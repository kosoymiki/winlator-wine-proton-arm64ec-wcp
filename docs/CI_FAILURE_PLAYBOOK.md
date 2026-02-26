# CI Failure Playbook (WCP)

Use this playbook for `wine`, `proton-ge10`, and `protonwine10` workflow failures.

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

## 7) Parse raw job logs quickly

When you have a raw GitHub Actions job log URL (or downloaded log file), extract the real failure lines with:

- `bash ci/validation/extract-gh-job-failures.sh "<raw-job-log-url>"`
- `bash ci/validation/extract-gh-job-failures.sh /path/to/job-logs.txt`

Use this before deep diffing so you do not chase secondary cascade errors.

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

For runtime startup/crash triage across `wine11`, `protonwine10`, and `steven104`:

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

Generated in snapshot dir:
- `mainline-health.tsv/.json`
- `active-failures.tsv/.meta`
- `health.log`, `active-failures.log`, `urc-check.log`
- `snapshot.meta`, `status.meta`, `git-head.txt`, `git-status.txt`
- If `WLT_TRIAGE_ACTIVE_RUNS=1`: `run-triage/run-<id>/` artifacts + `run-triage/run-<id>.log`
