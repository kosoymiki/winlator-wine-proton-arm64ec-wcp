# RC-005 Device Matrix Runbook

This runbook executes `RC-005` from `docs/HARVARD_RUNTIME_CONFLICT_BOARD.md`:

- device-side conflict contour validation,
- target matrix coverage (`wine11/protonwine10/protonge10/gamenative104`),
- `VPN on/off`, `NVAPI requested on/off`, `Proton FSR mode quality/balanced/performance/ultra`,
- per-scenario bundles with conflict markers and stable `AERO_LIBRARY_CONFLICT_SHA256`.

## Runner

Use:

- `ci/winlator/forensic-adb-rc005-matrix.sh`

It performs:

1. per-scenario configuration:
   - updates `.container` `dxwrapperConfig` (`nvapi=0|1`) for each lane container,
   - updates app `shared_prefs` keys:
     - `adrenotools_upscale_proton_fsr_mode`
     - `adrenotools_upscale_proton_fsr_strength`.
2. scenario capture via `ci/winlator/forensic-adb-complete-matrix.sh`.
3. report generation:
   - `runtime-mismatch-matrix.*`
   - `runtime-conflict-contour.*`
4. bundle export:
   - `bundles/index.tsv`
   - `bundles/index.json`
   - per-scenario zip bundles.
5. RC-005 audit:
   - `ci/winlator/validate-rc005-device-matrix.py --strict`.

## Standard Command

```bash
ADB_SERIAL=<device> \
WLT_PACKAGE=by.aero.so.benchmark \
WLT_FLAVOR_MAP="wine11:1 protonwine10:2 protonge10:3 gamenative104:4" \
WLT_VPN_STATES="off on" \
WLT_NVAPI_STATES="0 1" \
WLT_FSR_MODES="quality balanced performance ultra" \
WLT_FSR_STRENGTH=2 \
WLT_RUN_NETWORK_DIAG=1 \
WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE=off \
WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE=off \
WLT_VALIDATE_RC005=1 \
bash ci/winlator/forensic-adb-rc005-matrix.sh
```

## VPN Handling

The runner can annotate both VPN states in one invocation and optionally execute a hook per state:

```bash
WLT_VPN_APPLY_HOOK='echo "switch to ${WLT_VPN_STATE}"'
```

For explicit control, run two separate passes (`WLT_VPN_STATES="off"` and then `WLT_VPN_STATES="on"`) after manual VPN switch.

## Outputs

`WLT_OUT_DIR` contains:

- scenario folders (`<label>/...`),
- `matrix-scenarios.tsv`,
- `runtime-mismatch-matrix.{tsv,md,json,summary.txt}`,
- `runtime-conflict-contour.{tsv,md,json,summary.txt}`,
- `rc005-validation.md`,
- `bundles/index.{tsv,json}` + `bundles/<label>.zip`,
- `session-meta.txt`.

## Acceptance

`RC-005` is ready to close when `rc005-validation.md` is `status: pass` and no threshold scripts returned non-zero.
