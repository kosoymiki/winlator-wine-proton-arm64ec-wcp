# Deep IDE Reflective Cycle Report

- Date: 2026-02-27T15:31:04+03:00
- Device: edb0acd0
- Sources analyzed: **13**

## Source list

- `proton104_wcp_local`: `/home/mikhail/Загрузки/proton-10-4-arm64ec.wcp.xz`
- `gamehub_apk_local`: `/home/mikhail/GameHub+5.3.5.Lite_RM.mod_DocProv_mod.apk`
- `gamenative_apk_local`: `/home/mikhail/gamenative-v0.7.2.apk`
- `app_gamenative_apk_device`: `out/reverse/sources/device/app_gamenative.base.apk`
- `com_miHoYo_GenshinImpact_apk_device`: `out/reverse/sources/device/com_miHoYo_GenshinImpact.base.apk`
- `by_aero_so_benchmark_apk_device`: `out/reverse/sources/device/by_aero_so_benchmark.base.apk`
- `device_proton_10_0_4_arm64ec_wcp`: `out/reverse/sources/device/proton-10.0-4-arm64ec.wcp`
- `device_protonwine10_gamenative_arm64ec_wcp`: `out/reverse/sources/device/protonwine10-gamenative-arm64ec.wcp`
- `device_vkd3d_proton_3_0b_wcp`: `out/reverse/sources/device/vkd3d-proton-3.0b.wcp`
- `device_vkd3d_proton_arm64ec_3_0b_wcp`: `out/reverse/sources/device/vkd3d-proton-arm64ec-3.0b.wcp`
- `device_proton_10_4_arm64ec_wcp_xz`: `out/reverse/sources/device/proton-10-4-arm64ec.wcp.xz`
- `aerosolator_contents_10_0_4_arm64ec_1`: `out/reverse/sources/device/by_aero_so_benchmark_10.0-4-arm64ec-1/10.0-4-arm64ec-1`
- `aerosolator_contents_11_arm64ec_1`: `out/reverse/sources/device/by_aero_so_benchmark_11-arm64ec-1/11-arm64ec-1`

## Outputs

- Per-source reports: `docs/reverse/deep-ide/<label>/IDE_REFLECTIVE_REPORT.md`
- Per-source matrix: `docs/reverse/deep-ide/<label>/LIBRARY_MATRIX.tsv`
- Per-library raw IDE artifacts: `docs/reverse/deep-ide/<label>/libs/*`
- Cross-source comparison: `docs/reverse/deep-ide/CROSS_SOURCE_IDE_COMPARISON.md`

## Runtime capture correlation (latest deep_ide runs)

- GameNative capture: `out/app-forensics/20260227_150751_gamenative_deep_ide`
- GameHub capture: `out/app-forensics/20260227_150905_gamehub_deep_ide`
- Ae.solator capture: `out/app-forensics/20260227_151017_aerosolator_deep_ide`
- Capture contract reports: `docs/reverse/deep-ide/capture-contracts/*.md`
- Capture contract rc: `1`

- `20260227_150751_gamenative_deep_ide`: wineserver=0, wine=0, auth_logcat=93, auth_external=0, x11_logcat=18, x11_external=0, net_logcat=15, net_external=0, container_setup_external=0
- `20260227_150905_gamehub_deep_ide`: wineserver=0, wine=0, auth_logcat=20, auth_external=2535, x11_logcat=22, x11_external=1268, net_logcat=18, net_external=690, container_setup_external=1827
- `20260227_151017_aerosolator_deep_ide`: wineserver=0, wine=0, auth_logcat=16, auth_external=0, x11_logcat=16, x11_external=0, net_logcat=25, net_external=0, container_setup_external=0

## Constraint notes

- Non-debuggable third-party app private data is not accessed directly.
- No authentication/account bypass is performed in this cycle.
