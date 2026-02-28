# Winlator Patch Stack Runtime Contract Audit

Generated: `2026-02-28T16:45:14Z`

## Scope

- Patch files scanned: `10`
- Target groups: `XServerDisplayActivity`, `GuestProgramLauncherComponent`, `RuntimeSignalContract`
- Contract: forensic telemetry + reason markers + runtime guard markers

## Results

### XServerDisplayActivity

- `telemetry_calls`: `ok` (9 patches) -> `0001-mainline-full-stack-consolidated.patch`, `0003-aeturnip-runtime-bind-and-forensics.patch`, `0004-upscaler-adrenotools-control-plane-x11-bind.patch`, `0005-upscaler-dxvk-proton-fsr-x11-turnip-runtime-matrix.patch`, `0006-upscaler-x11-turnip-dx-all-directs-memory-policy.patch`, `0007-upscaler-module-forensics-dx8assist-contract.patch` ...
- `reason_markers`: `ok` (6 patches) -> `0001-mainline-full-stack-consolidated.patch`, `0003-aeturnip-runtime-bind-and-forensics.patch`, `0007-upscaler-module-forensics-dx8assist-contract.patch`, `0008-upscaler-dx-policy-order-and-artifact-sources.patch`, `0009-launch-graphics-packet-dx-upscaler-x11-turnip-bundle.patch`, `0010-dxvk-capability-envelope-proton-fsr-gate-upscaler-matrix.patch`
- `fallback_guardrails`: `ok` (5 patches) -> `0001-mainline-full-stack-consolidated.patch`, `0003-aeturnip-runtime-bind-and-forensics.patch`, `0004-upscaler-adrenotools-control-plane-x11-bind.patch`, `0008-upscaler-dx-policy-order-and-artifact-sources.patch`, `0010-dxvk-capability-envelope-proton-fsr-gate-upscaler-matrix.patch`
- `external_signal_inputs`: `missing`
- `launch_env_signal_fields`: `missing`
- `contract_helper_usage`: `missing`

### GuestProgramLauncherComponent

- `telemetry_calls`: `ok` (1 patches) -> `0001-mainline-full-stack-consolidated.patch`
- `reason_markers`: `ok` (2 patches) -> `0009-launch-graphics-packet-dx-upscaler-x11-turnip-bundle.patch`, `0010-dxvk-capability-envelope-proton-fsr-gate-upscaler-matrix.patch`
- `runtime_contract_markers`: `missing`
- `external_signal_markers`: `missing`
- `contract_helper_usage`: `missing`

### RuntimeSignalContract

- `policy_markers_constants`: `missing`
- `input_markers_constants`: `missing`
- `policy_hashing`: `missing`

## Contract Summary

- Missing checks: `9`
- Action: add follow-up patch preserving forensic reason-codes and runtime markers.

