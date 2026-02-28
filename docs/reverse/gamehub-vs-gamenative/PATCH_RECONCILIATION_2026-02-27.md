# Patch Reconciliation: GameHub + GameNative vs Mainline Patch Stack

Date: 2026-02-27

## Inputs

- `docs/reverse/gamehub-5.3.5-native-cycle/*`
- `docs/reverse/gamenative-0.7.2-native-cycle/*`
- `docs/reverse/gamehub-vs-gamenative/CROSS_APK_NATIVE_COMPARISON.md`
- `docs/reverse/gamehub-vs-gamenative/FULL_CYCLE_REPORT_2026-02-27.md`

## Mainline patch alignment

- `0065-xserver-guest-exit-deferral-and-x11-zero-window-recovery.patch`
  - addresses lifecycle cluster seen in GameHub/WineActivity teardown traces.
- `0055-termux-x11-compat-contract-preflight-and-diagnostics.patch`
  - keeps X11 path diagnosable and deterministic.
- `0063-network-vpn-download-hardening.patch`
  - aligns with repeated timeout/DNS fault class in external launcher flows.
- `0064-vulkan-1-4-policy-and-negotiation.patch`
  - keeps runtime Vulkan contract explicit across mixed driver families.

## What is still not "100%"

- Full Java/Smali line-by-line decompilation and per-function semantic parity is not completed in this cycle.
- Hex-level per-instruction transfer was not applied; current cycle is native binary contract + runtime forensic parity.

## Next deterministic block

1. Build JNI callgraph extraction for both APKs and map to app-level classes.
2. Add contract tests for lifecycle guardrail events (`SESSION_EXIT_DEFERRED_ACTIVE_TREE`, `X11_ZERO_APP_WINDOWS_RECOVERABLE`).
3. Extend capture suite with scripted UI steps up to auth gate, then compare event envelopes between apps.
