# Snapshot Contract Audit

| Check | File | Status | Missing Tokens |
| --- | --- | --- | --- |
| `coffin_mouse_snapshot_markers` | `/home/mikhail/winlator-wine-proton-arm64ec-wcp/ci/reverse/upstream_snapshots/coffin_wine/dlls/winex11.drv/mouse.c` | `ready` | - |
| `coffin_winebrowser_snapshot_markers` | `/home/mikhail/winlator-wine-proton-arm64ec-wcp/ci/reverse/upstream_snapshots/coffin_wine/programs/winebrowser/main.c` | `missing_tokens` | `WINE_OPEN_WITH_ANDROID_BROWSER`, `send(` |
| `coffin_loader_snapshot_markers` | `/home/mikhail/winlator-wine-proton-arm64ec-wcp/ci/reverse/upstream_snapshots/coffin_wine/dlls/ntdll/unix/loader.c` | `missing_tokens` | `Wow64SuspendLocalThread`, `RtlWow64SuspendThread` |
| `gn_patch_mouse_contract` | `/home/mikhail/winlator-wine-proton-arm64ec-wcp/ci/gamenative/patchsets/28c3a06/android/patches/dlls_winex11_drv_mouse_c_wm_input_fix.patch` | `ready` | - |
| `gn_patch_winebrowser_contract` | `/home/mikhail/winlator-wine-proton-arm64ec-wcp/ci/gamenative/patchsets/28c3a06/android/patches/programs_winebrowser_main_c.patch` | `ready` | - |
| `gn_patch_loader_contract` | `/home/mikhail/winlator-wine-proton-arm64ec-wcp/ci/gamenative/patchsets/28c3a06/android/patches/dlls_ntdll_loader_c.patch` | `ready` | - |
