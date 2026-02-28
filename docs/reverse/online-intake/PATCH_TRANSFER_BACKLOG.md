# Online Intake Patch Backlog

Generated from `docs/reverse/online-intake/combined-matrix.json`.

- scanned repos: **25**
- intake errors: **0**

## Category pressure (tree-wide)

- `misc`: **32**
- `graphics_xserver`: **6**
- `cpu_translation`: **5**
- `arm64ec_core`: **4**
- `container_flow`: **2**
- `launcher_runtime`: **2**
- `build_ci`: **2**
- `termux_runtime`: **1**

## Marker-driven patch queue

| Priority | Marker | Hits | Focus/Commits | Repos | Target | Status | Action |
| --- | --- | ---: | --- | --- | --- | --- | --- |
| `low` | `DXVK` | 27 | 16/11 | ahmad1abbadi_darkos, coffin_winlator, gamehublite_oss, horizonemu_horizon_emu, ilya114_box64droid, kreitinn_micewine_application, olegos2_mobox, olegos2_termux_box, utkarsh_gamenative, xhyn_exagear_302 | `docs/CONTENT_PACKAGES_ARCHITECTURE.md` | `ready_validated` | Keep DXVK path references consistent with external content packaging. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java:69` -> `import com.winlator.cmod.contentdialog.DXVKConfigDialog;`
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java:44` -> `import com.winlator.cmod.contentdialog.DXVKConfigDialog;`
| `low` | `VKD3D` | 18 | 10/8 | ahmad1abbadi_darkos, coffin_winlator, gamehublite_oss, horizonemu_horizon_emu, olegos2_mobox, olegos2_termux_box, utkarsh_gamenative | `docs/CONTENT_PACKAGES_ARCHITECTURE.md` | `ready_validated` | Keep VKD3D path references consistent with external content packaging. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java:73` -> `import com.winlator.cmod.contentdialog.VKD3DConfigDialog;`
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java:47` -> `import com.winlator.cmod.contentdialog.VKD3DConfigDialog;`
| `low` | `D8VK` | 18 | 10/8 | ahmad1abbadi_darkos, coffin_winlator, horizonemu_horizon_emu, ilya114_box64droid, olegos2_mobox, olegos2_termux_box, utkarsh_gamenative | `docs/CONTENT_PACKAGES_ARCHITECTURE.md` | `ready_validated` | Track DX8 wrapper-lane hints for later patch-base reconciliation. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java:2516` -> `TarCompressorUtils.extract(TarCompressorUtils.Type.ZSTD, this, "dxwrapper/d8vk-" + DefaultVersion.D8VK + ".tzst", windowsDir, onExtractFileListener);`
  - evidence[focus] `utkarsh_gamenative:app/src/main/java/app/gamenative/ui/screen/xserver/XServerScreen.kt:3163` -> `Timber.i("Extracting DXVK/D8VK DLLs for dxwrapper: $dxwrapper")`
| `medium` | `ContentProfile` | 12 | 4/8 | coffin_winlator, utkarsh_gamenative | `docs/CONTENT_PACKAGES_ARCHITECTURE.md` | `ready_validated` | Keep internal type canonicalization aligned with Wine-family aliases. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java:74` -> `import com.winlator.cmod.contents.ContentProfile;`
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java:48` -> `import com.winlator.cmod.contents.ContentProfile;`
| `low` | `TU_DEBUG` | 9 | 3/6 | kreitinn_micewine_application, olegos2_mobox, utkarsh_gamenative | `docs/UNIFIED_RUNTIME_CONTRACT.md` | `ready_validated` | Preserve TU_DEBUG routing for adreno device-tier diagnostics presets. |
  - evidence[focus] `utkarsh_gamenative:app/src/main/java/app/gamenative/ui/screen/xserver/XServerScreen.kt:1893` -> `var tuDebug = envVars.get("TU_DEBUG")`
  - evidence[focus] `olegos2_mobox:README.md:49` -> `If you have Snapdragon 8 Gen 1, 8+ Gen 1, 7+ Gen 2, enable the second option in `select a7xx flickering fix (TU_DEBUG)` in `System settings` menu.`
| `low` | `BOX64_DYNAREC` | 6 | 6/0 | ahmad1abbadi_darkos, coffin_winlator, ilya114_box64droid, kreitinn_micewine_application, utkarsh_gamenative | `ci/winlator/patches/0001-mainline-full-stack-consolidated.patch` | `ready_validated` | Track Box64 dynarec knobs against unified runtime profile defaults. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java:214` -> `envVars.put("BOX64_DYNAREC", "1");`
  - evidence[focus] `utkarsh_gamenative:app/src/main/java/com/winlator/xenvironment/components/GuestProgramLauncherComponent.java:359` -> `envVars.put("BOX64_DYNAREC", "1");`
| `low` | `WINEDEBUG` | 5 | 5/0 | ahmad1abbadi_darkos, coffin_wine, coffin_winlator, ilya114_box64droid, utkarsh_gamenative | `docs/UNIFIED_RUNTIME_CONTRACT.md` | `ready_validated` | Preserve canonical WINEDEBUG injection path and diagnostics envelope export. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java:1597` -> `envVars.put("WINEDEBUG", enableWineDebug && !wineDebugChannels.isEmpty()`
  - evidence[focus] `coffin_wine:dlls/ntdll/unix/loader.c:1937` -> `else if (!strcmp( var, "WINEDEBUGLOG" ))`
| `low` | `BOX64_LOG` | 5 | 5/0 | ahmad1abbadi_darkos, coffin_winlator, ilya114_box64droid, kreitinn_micewine_application, utkarsh_gamenative | `ci/winlator/patches/0001-mainline-full-stack-consolidated.patch` | `ready_validated` | Retain deterministic Box64 log controls for forensics capture presets. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java:217` -> `envVars.put("BOX64_LOG", "1");`
  - evidence[focus] `utkarsh_gamenative:app/src/main/java/com/winlator/xenvironment/components/GuestProgramLauncherComponent.java:364` -> `envVars.put("BOX64_LOG", "1");`
| `high` | `x11drv_xinput2_enable` | 4 | 2/2 | coffin_wine, gamenative_protonwine | `ci/gamenative/patchsets/28c3a06/manifest.tsv` | `ready_validated` | Keep no-XInput2 safeguards for X11 mouse/controller path. |
  - evidence[focus] `coffin_wine:dlls/winex11.drv/mouse.c:256` -> `*              x11drv_xinput2_enable`
  - evidence[focus] `gamenative_protonwine:dlls/winex11.drv/mouse.c:343` -> `*              x11drv_xinput2_enable`
| `low` | `MESA_VK_WSI_PRESENT_MODE` | 3 | 3/0 | coffin_winlator, kreitinn_micewine_application, utkarsh_gamenative | `docs/UNIFIED_RUNTIME_CONTRACT.md` | `ready_validated` | Keep present-mode negotiation deterministic for wrapper/upscaler integration. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java:2310` -> `envVars.put("MESA_VK_WSI_PRESENT_MODE", "mailbox");`
  - evidence[focus] `kreitinn_micewine_application:app/src/main/java/com/micewine/emu/activities/GeneralSettingsActivity.java:193` -> `public final static String SELECTED_MESA_VK_WSI_PRESENT_MODE = "MESA_VK_WSI_PRESENT_MODE";`
| `low` | `FEXCore` | 3 | 3/0 | coffin_winlator, utkarsh_gamenative | `ci/winlator/patches/0001-mainline-full-stack-consolidated.patch` | `ready_validated` | Cross-check FEX profile surface against external-only runtime contract. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java:95` -> `import com.winlator.cmod.fexcore.FEXCoreManager;`
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java:63` -> `import com.winlator.cmod.fexcore.FEXCoreManager;`
| `low` | `cnc-ddraw` | 2 | 2/0 | coffin_winlator, utkarsh_gamenative | `ci/winlator/patches/0001-mainline-full-stack-consolidated.patch` | `ready_validated` | Keep DX8 cnc-ddraw wrapper branch wired in runtime env assembly. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java:1551` -> `if (ddrawrapper.equals("cnc-ddraw")) envVars.put("CNC_DDRAW_CONFIG_FILE", "C:\\windows\\syswow64\\ddraw.ini");`
  - evidence[focus] `utkarsh_gamenative:app/src/main/java/app/gamenative/ui/screen/xserver/XServerScreen.kt:3007` -> `if (xServerState.value.dxwrapper == "cnc-ddraw") envVars.put("CNC_DDRAW_CONFIG_FILE", "C:\\ProgramData\\cnc-ddraw\\ddraw.ini")`
| `low` | `BOX64_NOBANNER` | 2 | 2/0 | coffin_winlator, utkarsh_gamenative | `ci/winlator/patches/0001-mainline-full-stack-consolidated.patch` | `ready_validated` | Keep startup-noise controls deterministic across profile presets. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java:213` -> `envVars.put("BOX64_NOBANNER", ProcessHelper.PRINT_DEBUG && enableLogs ? "0" : "1");`
  - evidence[focus] `utkarsh_gamenative:app/src/main/java/com/winlator/xenvironment/components/GuestProgramLauncherComponent.java:358` -> `envVars.put("BOX64_NOBANNER", ProcessHelper.PRINT_DEBUG && enableLogs ? "0" : "1");`
| `low` | `PROOT_TMP_DIR` | 2 | 2/0 | coffin_winlator, utkarsh_gamenative | `docs/EXTERNAL_SIGNAL_CONTRACT.md` | `ready_validated` | Capture proot/temp path assumptions as external signal inputs. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java:158` -> `envVars.put("PROOT_TMP_DIR", tmpDir);`
  - evidence[focus] `utkarsh_gamenative:app/src/main/java/com/winlator/xenvironment/components/GuestProgramLauncherComponent.java:285` -> `envVars.put("PROOT_TMP_DIR", tmpDir);`
| `medium` | `libarm64ecfex.dll` | 2 | 2/0 | coffin_winlator, gamenative_protonwine | `ci/validation/check-gamenative-patch-contract.sh` | `ready_validated` | Keep loader contract checks for external FEX dll naming and placement. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/contents/ContentsManager.java:36` -> `public static final String[] FEXCORE_TRUST_FILES = {"${system32}/libwow64fex.dll", "${system32}/libarm64ecfex.dll"};`
  - evidence[focus] `gamenative_protonwine:android/patches/dlls_ntdll_loader_c.patch:10` -> `+    WCHAR module[64] = L"C:\\windows\\system32\\libarm64ecfex.dll";`
| `high` | `NtUserSendHardwareInput` | 2 | 2/0 | coffin_wine, gamenative_protonwine | `ci/gamenative/patchsets/28c3a06/android/patches/dlls_winex11_drv_mouse_c_wm_input_fix.patch` | `ready_validated` | Verify WM_INPUT path keeps raw-input policy compatible with no-XInput2 builds. |
  - evidence[focus] `coffin_wine:dlls/winex11.drv/mouse.c:546` -> `NtUserSendHardwareInput( hwnd, 0, input, 0 );`
  - evidence[focus] `gamenative_protonwine:dlls/winex11.drv/mouse.c:643` -> `NtUserSendHardwareInput( hwnd, SEND_HWMSG_NO_RAW, input, 0 );`
| `high` | `xinput2_available` | 2 | 2/0 | coffin_wine, gamenative_protonwine | `ci/validation/check-gamenative-patch-contract.sh` | `ready_validated` | Enforce helper-gated NO_RAW behavior on xinput2_available builds. |
  - evidence[focus] `coffin_wine:dlls/winex11.drv/mouse.c:129` -> `static BOOL xinput2_available;`
  - evidence[focus] `gamenative_protonwine:dlls/winex11.drv/mouse.c:133` -> `static BOOL xinput2_available;`
| `low` | `BOX64_DYNAREC_STRONGMEM` | 2 | 2/0 | kreitinn_micewine_application, utkarsh_gamenative | `ci/winlator/patches/0001-mainline-full-stack-consolidated.patch` | `ready_validated` | Review strongmem toggles for device-tier overlays before promotion. |
  - evidence[focus] `utkarsh_gamenative:app/src/main/assets/box64_env_vars.json:7` -> `{"name" : "BOX64_DYNAREC_STRONGMEM", "values" : ["0", "1", "2", "3"], "defaultValue" : "0"},`
  - evidence[focus] `kreitinn_micewine_application:app/src/main/java/com/micewine/emu/activities/GeneralSettingsActivity.java:140` -> `public final static String BOX64_DYNAREC_STRONGMEM = "BOX64_DYNAREC_STRONGMEM";`
| `medium` | `REMOTE_PROFILES` | 1 | 1/0 | coffin_winlator | `ci/winlator/patches/0001-mainline-full-stack-consolidated.patch` | `ready_validated` | Harden profile source fallback chain for VPN/DNS transient failures. |
  - evidence[focus] `coffin_winlator:app/src/main/java/com/winlator/cmod/contents/ContentsManager.java:28` -> `public static final String REMOTE_PROFILES = "contents.json";`
| `high` | `SEND_HWMSG_NO_RAW` | 1 | 1/0 | gamenative_protonwine | `ci/validation/check-gamenative-patch-contract.sh` | `ready_validated` | Reject hardcoded NO_RAW dispatch unless helper or zero-flag fallback is present. |
  - evidence[focus] `gamenative_protonwine:dlls/winex11.drv/mouse.c:667` -> `NtUserSendHardwareInput( hwnd, SEND_HWMSG_NO_RAW, input, 0 );`
| `low` | `WINE_OPEN_WITH_ANDROID_BROWSER` | 1 | 1/0 | gamenative_protonwine | `ci/validation/check-gamenative-patch-contract.sh` | `ready_validated` | Keep android-browser env key canonicalized in winebrowser normalization path. |
  - evidence[focus] `gamenative_protonwine:android/patches/programs_winebrowser_main_c.patch:134` -> `+    wine_open_with_android_browser = getenv("WINE_OPEN_WITH_ANDROID_BROWSER") && atoi(getenv("WINE_OPEN_WITH_ANDROID_BROWSER"));`
| `medium` | `Wow64SuspendLocalThread` | 1 | 1/0 | gamenative_protonwine | `ci/validation/inspect-wcp-runtime-contract.sh` | `ready_validated` | Preserve wow64 export checks in strict runtime contract mode. |
  - evidence[focus] `gamenative_protonwine:android/patches/dlls_ntdll_loader_c.patch:18` -> `+NTSTATUS (WINAPI *pWow64SuspendLocalThread)( HANDLE thread, ULONG *count ) = NULL;`
| `high` | `WRAPPER_VK_VERSION` | 1 | 1/0 | utkarsh_gamenative | `ci/winlator/patches/0001-mainline-full-stack-consolidated.patch` | `ready_validated` | Track requested/detected/effective Vulkan negotiation markers and runtime env export. |

## Execution rule

- Apply `high` rows first, then rerun `ci/reverse/online-intake.sh` and regenerate this backlog.
- Keep `medium` rows gated behind existing runtime contract and URC checks.
- Treat `low` rows as backlog candidates for patch-base expansion after `high/medium` are clean.

