# Upscaler Forensic Validation

This document defines the ADB-only validation loop for the upscale/FG transfer (`0025+`).

## Scope

- **Winlator runtime** (`graphics/*`, `XServerDisplayActivity`, launcher env)
- **Container-level config** (`.container` extraData)
- **Forensic telemetry** (`RUNTIME_*`, `LAUNCH_*`, `SESSION_EXIT_*`)

It does **not** cover APK install/update. APK installation remains manual.

## Required Scenarios

Run on the same installed build for reproducibility:

1. `container #2` (Steven reference) with default/auto preset
2. Problem container (`Wine 11` / GE / GameNative) with default/auto preset
3. Same problem container with `safe`, `balanced`, `scaleforce` presets
4. If available, compare Turnip vs Qualcomm driver

## Required Events (minimum)

- `RUNTIME_CONTAINER_UPSCALE_CONFIG_APPLIED`
- `RUNTIME_GRAPHICS_SUITABILITY`
- `RUNTIME_PERF_PRESET_RESOLVED`
- `RUNTIME_PERF_PRESET_DOWNGRADED` (when applicable)
- `RUNTIME_SWFG_EFFECTIVE_CONFIG`
- `RUNTIME_SWFG_DISABLED_BY_GUARD` (when applicable)
- `RUNTIME_UPSCALE_LAUNCH_ENV_NORMALIZED`
- `LAUNCH_EXEC_SUBMIT`
- `LAUNCH_EXEC_EXIT`
- `SESSION_EXIT_*`

## ADB Capture (read-only orchestration)

Use the upscale matrix helper:

```bash
ADB_SERIAL=<device> \
WLT_CONTAINER_IDS="2 1" \
bash ci/winlator/forensic-adb-upscale-matrix.sh
```

Artifacts are written to `/tmp/winlator-upscale-forensics-<timestamp>/`.

## Acceptance Criteria

- Upscale preset resolution is deterministic for the same container/settings.
- Suitability downgrade is visible in logs with explicit reasons.
- `LAUNCH_EXEC_SUBMIT` contains normalized upscale env markers.
- No new early-exit regressions are introduced by `WINLATOR_SWFG_*`.

## Comparison Method

Treat differences as:

- **causal**: driver family, Vulkan suitability, preset guard downgrade, runtime class
- **noise**: timestamps, PIDs, trace IDs, window z-order, unrelated UI events

Compare reference vs target container by meaning, not exact log line order.
