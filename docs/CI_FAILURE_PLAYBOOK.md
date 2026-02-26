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
2. Ensure source contains `#ifdef HAVE_X11_EXTENSIONS_XFIXES_H` guards around both calls.
3. Re-run workflow after patchset normalization fix.

## 3) Runtime check fails: missing `winebus.so`

Symptom:
- `SDL2 runtime check failed: missing .../winebus.so`.

Action:
1. Treat as upstream compile/install failure, not SDL packaging root cause.
2. Inspect the first compile error in `out/*/logs/wine-build.log`.
3. Fix compile break, then re-run; `winebus.so` check should pass automatically.

## 4) Patchset conflicts / divergence

Action:
1. Generate overlap + manifest sanity report:
   - `python3 ci/gamenative/patchset-conflict-audit.py --output docs/PATCHSET_CONFLICT_REPORT.md`
2. Keep file-level patch ownership only in `ci/gamenative/apply-android-patchset.sh`.
3. Remove ad-hoc per-package source edits if they duplicate manifest-owned files.

## 5) Fast triage checklist

- Check workflow input `gn_patchset_enable`.
- Check patchset mode in logs (`full` vs `normalize-only`).
- Check first real compile error (ignore cascading missing artifact errors).
- Confirm `gamenative-patchset-*.tsv` report artifact is uploaded.
