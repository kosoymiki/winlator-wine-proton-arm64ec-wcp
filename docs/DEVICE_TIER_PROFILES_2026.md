# Device Tier Profiles 2026

## Why this exists

Runtime tuning had drifted into ad-hoc presets and raw env editing. That created
non-reproducible behavior and made forensic comparisons noisy. The profile model
now separates concerns into:

1. **Common runtime profile** (backend-agnostic; independent from FEX/Box)
2. **FEX overlay** (emulator-specific knobs)
3. **Box64/WoWBox64 overlay** (emulator-specific knobs)

This document defines the 2026 device tiers and tuning intent.

## 2026 device tiers

- **legacy_low_2026**: older big.LITTLE SoCs, thermal-limited, low sustained clocks  
  Goal: stability over throughput.
- **mid_2026**: mainstream 6/7-class SoCs, mixed CPU/GPU bottlenecks  
  Goal: avoid stutter spikes and cache/memory thrash.
- **upper_mid_2026**: strong CPU, moderate GPU headroom under sustained load  
  Goal: balanced latency and throughput.
- **flagship_2026**: 8-class modern SoCs with stronger sustained clocks  
  Goal: maximize throughput while preserving frame pacing.

## Special profile: Snapdragon 8+ Gen 1 (12/256)

`s8g1_super` is intentionally aggressive and assumes active cooling or short
sustained sessions:

- common profile leans toward high throughput and reduced guardrails
- FEX overlay favors translation throughput and larger hot-path windows
- Box64/WoWBox64 overlay favors aggressive dynarec/caching behavior

Use only when thermal throttling is acceptable and input-latency regression is
within game tolerance.

## Profile composition model

Effective env for launch is built in this order:

1. base runtime defaults
2. **common profile** env overlay
3. emulator overlay (**FEX** or **Box64/WoWBox64**)
4. container/shortcut explicit overrides
5. runtime guardrails (suitability-based downgrade if required)

This order is deliberate: common profile is stable policy, emulator profile is
mechanism, guardrails are safety.

## Operational rules

- Keep common profile independent from emulator internals.
- Do not encode FEX-only keys into Box overlays or vice versa.
- Changes to tier defaults require before/after forensic traces on:
  - `n2` baseline container
  - at least one modern bionic-native package
  - `scaleforce on/off` matrix

## Validation checklist

- `RUNTIME_COMMON_PROFILE_APPLIED` appears with expected profile id
- launch env includes common keys and emulator overlay keys (no cross-leakage)
- no silent fallback: downgrade must be visible in forensic events
- profile-selected runs are reproducible across two consecutive launches
