# Online Intake: `GameNative/proton-wine`

- Branch analyzed: `proton_10.0`
- Default branch: `proton_10.0`
- Updated at: `2026-02-27T02:46:40Z`
- Commits scanned: `25`

## Top categories

- `misc`: **57**
- `arm64ec_core`: **31**
- `build_ci`: **12**
- `graphics_xserver`: **8**
- `input_stack`: **4**
- `audio_stack`: **2**

## Top touched files

- `dlls/appwiz.cpl/addons.c`: **4**
- `dlls/mscoree/mscoree_private.h`: **4**
- `tools/gitlab/test.yml`: **4**
- `build-scripts/build-step-arm64ec.sh`: **3**
- `configure.ac`: **3**
- `dlls/mf/session.c`: **3**
- `.github/workflows/build-proton.yml`: **2**
- `android/patches/dlls_ntdll_loader_c.patch`: **2**
- `android/patches/test-bylaws/dlls_wow64_process_c.patch`: **2**
- `build-scripts/build-step-x86_64.sh`: **2**
- `dlls/atiadlxx/atiadlxx.spec`: **2**
- `dlls/atiadlxx/atiadlxx_main.c`: **2**
- `android/patches/test-bylaws/dlls_ntdll_ntdll_spec.patch`: **1**
- `android/patches/programs_winemenubuilder_winemenubuilder_c.patch`: **1**
- `.github/workflows/README.md`: **1**
- `android/android_sysvshm/.gitignore`: **1**
- `android/android_sysvshm/INTEGRATION.md`: **1**
- `android/android_sysvshm/Makefile`: **1**
- `android/android_sysvshm/README.md`: **1**
- `android/android_sysvshm/android_sysvshm.c`: **1**
- `android/android_sysvshm/build-aarch64.sh`: **1**
- `android/android_sysvshm/build-x86_64.sh`: **1**
- `android/android_sysvshm/sys/shm.h`: **1**
- `android/patches/android_network.patch`: **1**
- `android/patches/dlls_advapi32_advapi_c.patch`: **1**

## Recent commit subjects

- `906c4d6a` Activates `test-bylaws` patches for ARM64EC builds
- `7b1c9dd7` Reverts and patches winemenubuilder for Winlator
- `28c3a06b` feature: add android support
- `b8fdff8e` atiadlxx: Add stub for ADL_Display_ODClockInfo_Get().
- `6d0ed7cb` atiadlxx: Add ADL_Display_MVPUStatus_Get().
- `895fae95` windows.media.speech: Add Vosk checks to autoconf.
- `b3724d19` Revert "win32u: Initialize surface with white colour on creation."
- `c373d92d` mscoree: Update Wine Mono to 10.4.1.
- `74f92cc4` gdi32: HACK: Force using Microsoft Sans Serif for Thai.
- `cfd8b1a2` mf: Prevent the session from starting invalid topologies.
- `a51874ce` gameinput: Introduce new DLL.
- `c22deaae` include: Add APP_LOCAL_DEVICE_ID definition.
- `0586050c` include: Add gameinput.idl.
- `13311158` Reapply "winex11.drv: Interpret mouse 6/7 as horiz scroll."
- `176e1b59` fixup! ntdll: Implement a new NtQueryInformationProcess ProcessWineUnixDebuggerPid class.
- `b0611f91` FAudio: Set default 7.1 channel mask to SDL3 and Windows defaults.
- `1b7e612d` mf: Fix crash when stream is null during sample request.
- `b4d0aee2` mf: Change SESSION_FLAG_RESTARTING to 0x40.
- `dd801a2e` mfsrcsnk: Check and set current stream position before reading.
- `6617e46f` HACK: winedmo: Ignore missing PNG decoders.
