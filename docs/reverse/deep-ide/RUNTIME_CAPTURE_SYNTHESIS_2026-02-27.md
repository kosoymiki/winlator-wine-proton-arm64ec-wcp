# Runtime Capture Synthesis (Deep IDE Cycle)

Date: 2026-02-27
Device: `edb0acd0`

## Capture set

- `out/app-forensics/20260227_141652_gamenative_deep_ide`
- `out/app-forensics/20260227_141906_gamehub_deep_ide`
- `out/app-forensics/20260227_142125_aerosolator_deep_ide`

## Metrics snapshot

- `20260227_141652_gamenative_deep_ide`: wineserver=0, wine=0, auth_markers=31, x11_markers=15, net_markers=14
- `20260227_141906_gamehub_deep_ide`: wineserver=0, wine=0, auth_markers=3239, x11_markers=1381, net_markers=983
- `20260227_142125_aerosolator_deep_ide`: wineserver=37, wine=37, auth_markers=183, x11_markers=49, net_markers=68

## High-signal findings

1. `GameHub` external log stream confirms container preparation and selected Wine path:
   - `winePath=/data/user/0/com.miHoYo.GenshinImpact/files/usr/opt/wine_proton10.0-arm64x-2`
   - `winePath=/data/user/0/com.miHoYo.GenshinImpact/files/usr/opt/wine_wine10.6-arm64x-2`
2. `GameNative` capture window does not show `wine/wineserver` process activity in `ps_samples.txt`.
3. `Ae.solator` capture shows active `wine/wineserver`, so runtime launch path is alive on current build.
4. `GameHub` log volume is dominated by persisted app logs (historical + current), so marker counts are noisy and should be treated as envelope, not exact per-launch counters.

## Reflective interpretation

- Static package parity is now deep-indexed (ELF+PE), but runtime parity still differs at launch gating stage between apps.
- `GameHub` exposes useful operational traces via external storage logs, while its private container tree remains non-readable without root.
- `Ae.solator` has direct process-level evidence for active Wine runtime; this is the baseline path for contract validation.

## Next patch-oriented actions

1. Keep `0063-network-vpn-download-hardening.patch` and `0064-vulkan-1-4-policy-and-negotiation.patch` as mandatory gates for device-side fetch/runtime consistency.
2. Extend forensic parser to classify `GameHub` external logs separately from real-time `logcat`, to remove count inflation in regression gates.
3. Add CI/runtime check to assert `wine` + `wineserver` process emergence within launch window for selected container profiles.
