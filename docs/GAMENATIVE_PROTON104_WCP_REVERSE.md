# WCP Reverse Analysis

- Input: `/home/mikhail/Загрузки/proton-10-4-arm64ec.wcp.xz`
- Input SHA256: `b1a7e056d91ba6ee72215b2114c26eff07cb75c4537b010d11f728dafcd3a682`
- Runtime class: `bionic-native`
- ELF glibc refs present: `False`
- Top-level: `bin/, lib/, prefixPack.txz, profile.json, share/`
- Stats: files `2182`, ELF `34`, PE-like `1500`

## Launchers

- `wine`: kind `elf`, interpreter `/system/bin/linker64`, runpath `/data/data/com.termux/files/usr/lib`
- `wineserver`: kind `elf`, interpreter `/system/bin/linker64`, runpath `/data/data/com.termux/files/usr/lib`

## Marker Counts

- `fex`: 0
- `glibc`: 0
- `wow64`: 3
- `box64`: 0
- `hangover`: 0

## Key Export Presence

- `lib/wine/aarch64-windows/kernel32.dll`: exports `1343`, key present `none`
- `lib/wine/aarch64-windows/kernelbase.dll`: exports `1417`, key present `none`
- `lib/wine/aarch64-windows/ntdll.dll`: exports `1418`, key present `NtCreateUserProcess, RtlCreateUserThread, RtlWow64GetThreadContext, RtlWow64SetThreadContext`
- `lib/wine/aarch64-windows/user32.dll`: exports `796`, key present `none`
- `lib/wine/aarch64-windows/win32u.dll`: exports `1542`, key present `NtUserSendInput, NtUserGetRawInputData`
- `lib/wine/aarch64-windows/wow64.dll`: exports `28`, key present `Wow64SuspendLocalThread`
- `lib/wine/aarch64-windows/wow64win.dll`: exports `1`, key present `none`

## Full Inventory

- Rows: `1049`
- Prefixes: `bin, lib/wine/aarch64-unix, lib/wine/aarch64-windows`
- `elf`: 34
- `other`: 257
- `pe`: 758

## Compare

- Runtime class: base `bionic-native` vs other `bionic-native`
- NTDLL export diff: base-only `31`, other-only `2`
- `wine` runpath: base `/data/data/com.termux/files/usr/lib` vs other `/data/data/com.winlator.cmod/files/imagefs/usr/lib`
- `wineserver` runpath: base `/data/data/com.termux/files/usr/lib` vs other `/data/data/com.winlator.cmod/files/imagefs/usr/lib`
- Inventory diff: common `1032`, changed sha `859`, base-only `17`, other-only `37`

## Interesting Library Delta

| Path | Kind | SHA equal | Base size | Other size | Extra |
| --- | --- | --- | ---: | ---: | --- |
| `bin/wine` | `elf` | `False` | `11216` | `15800` | runpath `/data/data/com.termux/files/usr/lib` -> `/data/data/com.winlator.cmod/files/imagefs/usr/lib` |
| `bin/wineserver` | `elf` | `False` | `1044624` | `3471656` | runpath `/data/data/com.termux/files/usr/lib` -> `/data/data/com.winlator.cmod/files/imagefs/usr/lib` |
| `lib/wine/aarch64-unix/ntdll.so` | `elf` | `False` | `914976` | `3169328` | runpath `/data/data/com.termux/files/usr/lib` -> `/data/data/com.winlator.cmod/files/imagefs/usr/lib` |
| `lib/wine/aarch64-unix/win32u.so` | `elf` | `False` | `1966352` | `6350696` | runpath `/data/data/com.termux/files/usr/lib` -> `/data/data/com.winlator.cmod/files/imagefs/usr/lib` |
| `lib/wine/aarch64-unix/winevulkan.so` | `elf` | `False` | `1253920` | `3558104` | runpath `/data/data/com.termux/files/usr/lib` -> `/data/data/com.winlator.cmod/files/imagefs/usr/lib` |
| `lib/wine/aarch64-unix/winex11.so` | `elf` | `False` | `643496` | `2395008` | runpath `/data/data/com.termux/files/usr/lib` -> `/data/data/com.winlator.cmod/files/imagefs/usr/lib` |
| `lib/wine/aarch64-unix/winebus.so` | `elf` | `False` | `89048` | `220176` | runpath `/data/data/com.termux/files/usr/lib` -> `/data/data/com.winlator.cmod/files/imagefs/usr/lib` |
| `lib/wine/aarch64-unix/winepulse.so` | `elf` | `False` | `120696` | `235376` | runpath `/data/data/com.termux/files/usr/lib` -> `/data/data/com.winlator.cmod/files/imagefs/usr/lib` |
| `lib/wine/aarch64-windows/ntdll.dll` | `pe` | `False` | `6221824` | `1769472` | exports 1418 -> 1389; keydiff RtlWow64SuspendThread |
| `lib/wine/aarch64-windows/wow64.dll` | `pe` | `False` | `688128` | `1245184` | exports 28 -> 28; keydiff - |
| `lib/wine/aarch64-windows/wow64win.dll` | `pe` | `False` | `561152` | `1507328` | exports 1 -> 1; keydiff - |
| `lib/wine/aarch64-windows/win32u.dll` | `pe` | `False` | `749568` | `651264` | exports 1542 -> 1319; keydiff - |
| `lib/wine/aarch64-windows/kernel32.dll` | `pe` | `False` | `2854912` | `3604480` | exports 1343 -> 1348; keydiff - |
| `lib/wine/aarch64-windows/kernelbase.dll` | `pe` | `False` | `7217152` | `7864320` | exports 1417 -> 1420; keydiff - |
| `lib/wine/aarch64-windows/user32.dll` | `pe` | `False` | `9166848` | `9895936` | exports 796 -> 831; keydiff - |

## Full Inventory Delta (samples)

- Changed SHA sample: `bin/msidb, bin/msiexec, bin/notepad, bin/regedit, bin/regsvr32, bin/wine, bin/wine-preloader, bin/wineboot, bin/winecfg, bin/wineconsole, bin/winedbg, bin/winefile, bin/winemine, bin/winepath, bin/wineserver, lib/wine/aarch64-unix/avicap32.so, lib/wine/aarch64-unix/bcrypt.so, lib/wine/aarch64-unix/crypt32.so, lib/wine/aarch64-unix/ctapi32.so, lib/wine/aarch64-unix/dnsapi.so, lib/wine/aarch64-unix/dwrite.so, lib/wine/aarch64-unix/kerberos.so, lib/wine/aarch64-unix/localspl.so, lib/wine/aarch64-unix/mountmgr.so, lib/wine/aarch64-unix/msv1_0.so`
- Base-only sample: `lib/wine/aarch64-unix/opencl.so, lib/wine/aarch64-unix/windows.media.speech.so, lib/wine/aarch64-windows/amdxc64.dll, lib/wine/aarch64-windows/atiadlxx.dll, lib/wine/aarch64-windows/audioses.dll, lib/wine/aarch64-windows/belauncher.exe, lib/wine/aarch64-windows/dotnetfx35.exe, lib/wine/aarch64-windows/getminidump.exe, lib/wine/aarch64-windows/icu.dll, lib/wine/aarch64-windows/libamdxc64.a, lib/wine/aarch64-windows/libdataexchange.a, lib/wine/aarch64-windows/libprofapi.a, lib/wine/aarch64-windows/nvcuda.dll, lib/wine/aarch64-windows/opencl.dll, lib/wine/aarch64-windows/sharedgpures.sys, lib/wine/aarch64-windows/tabtip.exe, lib/wine/aarch64-windows/twain_32.dll`
- Other-only sample: `bin/function_grep.pl, bin/widl, bin/wine64, bin/winebuild, bin/winecpp, bin/winedump, bin/wineg++, bin/winegcc, bin/winemaker, bin/wmc, bin/wrc, lib/wine/aarch64-unix/wine, lib/wine/aarch64-unix/wine-preloader, lib/wine/aarch64-windows/comctl32_v6.dll, lib/wine/aarch64-windows/cryptbase.dll, lib/wine/aarch64-windows/cryptxml.dll, lib/wine/aarch64-windows/ir50_32.dll, lib/wine/aarch64-windows/libcompiler-rt.a, lib/wine/aarch64-windows/libcoremessaging.a, lib/wine/aarch64-windows/libcryptsp.a, lib/wine/aarch64-windows/libcryptxml.a, lib/wine/aarch64-windows/libd3dcompiler_42.a, lib/wine/aarch64-windows/libd3dx10_33.a, lib/wine/aarch64-windows/libd3dx9_35.a, lib/wine/aarch64-windows/libd3dx9_42.a`
