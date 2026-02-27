# Winlator Patch Stack Runtime Contract Audit

Generated: `2026-02-27T01:31:05Z`

## Scope

- Patch files scanned: `64`
- Target groups: `XServerDisplayActivity`, `GuestProgramLauncherComponent`, `RuntimeSignalContract`
- Contract: forensic telemetry + reason markers + runtime guard markers

## Results

### XServerDisplayActivity

- `telemetry_calls`: `ok` (11 patches) -> `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch`, `0010-driver-probe-hardening-runtime-fallback-telemetry.patch`, `0011-xserver-session-exit-no-restart-on-guest-termination.patch`, `0025-upscale-runtime-guardrails-and-swfg-contract.patch`, `0026-upscale-container-bridge-launch-normalization-and-ui.patch`, `0031-upscale-runtime-binding-gate-service-processes.patch` ...
- `reason_markers`: `ok` (12 patches) -> `0010-driver-probe-hardening-runtime-fallback-telemetry.patch`, `0011-xserver-session-exit-no-restart-on-guest-termination.patch`, `0025-upscale-runtime-guardrails-and-swfg-contract.patch`, `0031-upscale-runtime-binding-gate-service-processes.patch`, `0036-upscale-binding-defer-shell-to-child-graphics.patch`, `0044-runtime-launch-precheck-and-forensic-guardrails.patch` ...
- `fallback_guardrails`: `ok` (15 patches) -> `0010-driver-probe-hardening-runtime-fallback-telemetry.patch`, `0025-upscale-runtime-guardrails-and-swfg-contract.patch`, `0026-upscale-container-bridge-launch-normalization-and-ui.patch`, `0031-upscale-runtime-binding-gate-service-processes.patch`, `0036-upscale-binding-defer-shell-to-child-graphics.patch`, `0044-runtime-launch-precheck-and-forensic-guardrails.patch` ...
- `external_signal_inputs`: `ok` (2 patches) -> `0057-signal-input-markers-from-launch-precheck.patch`, `0058-launch-env-forensics-include-signal-input-envelope.patch`
- `launch_env_signal_fields`: `ok` (3 patches) -> `0057-signal-input-markers-from-launch-precheck.patch`, `0058-launch-env-forensics-include-signal-input-envelope.patch`, `0059-runtime-signal-contract-helper-and-adoption.patch`
- `contract_helper_usage`: `ok` (1 patches) -> `0059-runtime-signal-contract-helper-and-adoption.patch`

### GuestProgramLauncherComponent

- `telemetry_calls`: `ok` (10 patches) -> `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch`, `0019-glibc-rseq-compat-for-wrapped-wine-launchers.patch`, `0020-glibc-wrapper-strip-bionic-ldpreload.patch`, `0026-upscale-container-bridge-launch-normalization-and-ui.patch`, `0029-runtime-launcher-wrapper-preexec-forensics.patch`, `0040-runtime-common-profile-ui-and-launcher-integration.patch` ...
- `reason_markers`: `ok` (4 patches) -> `0026-upscale-container-bridge-launch-normalization-and-ui.patch`, `0044-runtime-launch-precheck-and-forensic-guardrails.patch`, `0055-termux-x11-compat-contract-preflight-and-diagnostics.patch`, `0056-external-signal-policy-markers-and-forensics.patch`
- `runtime_contract_markers`: `ok` (2 patches) -> `0044-runtime-launch-precheck-and-forensic-guardrails.patch`, `0056-external-signal-policy-markers-and-forensics.patch`
- `external_signal_markers`: `ok` (1 patches) -> `0056-external-signal-policy-markers-and-forensics.patch`
- `contract_helper_usage`: `ok` (1 patches) -> `0059-runtime-signal-contract-helper-and-adoption.patch`

### RuntimeSignalContract

- `policy_markers_constants`: `ok` (1 patches) -> `0059-runtime-signal-contract-helper-and-adoption.patch`
- `input_markers_constants`: `ok` (1 patches) -> `0059-runtime-signal-contract-helper-and-adoption.patch`
- `policy_hashing`: `ok` (1 patches) -> `0059-runtime-signal-contract-helper-and-adoption.patch`

## Contract Summary

- All required runtime-contract checks are present in current patch stack.

