# Online Intake: `GameNative/proton-wine`

- Transport: `gh`
- Scope: `focused`
- Branch analyzed: `proton_10.0`
- Intake mode: `code-only`
- Default branch: `proton_10.0`
- Updated at: `2026-02-28T00:28:13Z`
- Commits scanned: `0`

## Top categories

- `misc`: **2**
- `arm64ec_core`: **2**
- `graphics_xserver`: **1**
- `build_ci`: **1**

## Tree-wide categories (all files)

- files scanned: **6**
- `misc`: **2**
- `arm64ec_core`: **2**
- `graphics_xserver`: **1**
- `build_ci`: **1**

## Top touched files

- commit diff scan disabled in code-only mode

## Recent commit subjects

- commit scan disabled in code-only mode

## Focus file markers

- `dlls/winex11.drv/mouse.c` -> NtUserSendHardwareInput, SEND_HWMSG_NO_RAW, xinput2_available, x11drv_xinput2_enable
  - `L133` `xinput2_available`: `static BOOL xinput2_available;`
  - `L343` `x11drv_xinput2_enable`: `*              x11drv_xinput2_enable`
  - `L643` `NtUserSendHardwareInput`: `NtUserSendHardwareInput( hwnd, SEND_HWMSG_NO_RAW, input, 0 );`
  - `L667` `SEND_HWMSG_NO_RAW`: `NtUserSendHardwareInput( hwnd, SEND_HWMSG_NO_RAW, input, 0 );`
- `programs/winebrowser/main.c` -> -
- `android/patches/programs_winebrowser_main_c.patch` -> WINE_OPEN_WITH_ANDROID_BROWSER
  - `L134` `WINE_OPEN_WITH_ANDROID_BROWSER`: `+    wine_open_with_android_browser = getenv("WINE_OPEN_WITH_ANDROID_BROWSER") && atoi(getenv("WINE_OPEN_WITH_ANDROID_BROWSER"));`
- `android/patches/dlls_ntdll_loader_c.patch` -> Wow64SuspendLocalThread, libarm64ecfex.dll
  - `L10` `libarm64ecfex.dll`: `+    WCHAR module[64] = L"C:\\windows\\system32\\libarm64ecfex.dll";`
  - `L18` `Wow64SuspendLocalThread`: `+NTSTATUS (WINAPI *pWow64SuspendLocalThread)( HANDLE thread, ULONG *count ) = NULL;`
- `build-scripts/build-step-arm64ec.sh` -> -
- `.github/workflows/build-proton.yml` -> -
