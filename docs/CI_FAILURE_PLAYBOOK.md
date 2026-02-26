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

This is the fast path before manual `gh run view ... --log` triage.
