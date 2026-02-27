# Online Intake: `coffincolors/wine`

- Branch analyzed: `arm64ec`
- Default branch: `arm64ec`
- Updated at: `2025-01-22T00:14:14Z`
- Commits scanned: `25`

## Top categories

- `misc`: **314**
- `arm64ec_core`: **29**
- `build_ci`: **14**

## Top touched files

- `configure`: **7**
- `configure.ac`: **6**
- `dlls/ntdll/loader.c`: **6**
- `dlls/wow64/syscall.c`: **4**
- `dlls/ntdll/unix/signal_arm64.c`: **3**
- `dlls/ntdll/ntdll_misc.h`: **2**
- `dlls/ntdll/signal_arm64ec.c`: **2**
- `dlls/box64cpu/Makefile.in`: **2**
- `programs/winemenubuilder/winemenubuilder.c`: **1**
- `dlls/winecrt0/arm64ec.c`: **1**
- `aclocal.m4`: **1**
- `dlls/ntdll/unix/server.c`: **1**
- `dlls/wow64/process.c`: **1**
- `dlls/wow64/wow64.spec`: **1**
- `dlls/ntdll/ntdll.spec`: **1**
- `dlls/ntdll/signal_arm64.c`: **1**
- `dlls/ntdll/signal_x86_64.c`: **1**
- `include/winternl.h`: **1**
- `dlls/box64cpu/box64cpu.spec`: **1**
- `dlls/box64cpu/cpu.c`: **1**
- `dlls/box64cpu/crt.c`: **1**
- `libs/box64/LICENSE`: **1**
- `libs/box64/Makefile.in`: **1**
- `libs/box64/src/custommem.c`: **1**
- `libs/box64/src/dynarec/arm64/arm64_emitter.h`: **1**

## Recent commit subjects

- `51c64ec8` Revert "configure: Properly test clang for dwarf support."
- `343daae0` Partially revert f1d4dd7cc83d971c6e69c3f2bdffe85dbcd81c0a
- `9bdf2d77` Revert "winecrt0: Use version 2 of CHPE metadata."
- `26abd3e0` ntdll: Default to libarm64ecfex for amd64 emulation
- `caac0701` HACK: Link box64cpu differently
- `7e490e50` HACK: Don't build box64 library for ARM64EC
- `8bc3a816` HACK: ntdll: Rudimentary ARM64EC suspend support.
- `ca5cafee` HACK: define some extra arm64ec symbols to workaround llvm bugs
- `bfd241c6` ntdll: Refuse to run on page sizes other than 4k
- `1fa51459` Revert "wow64: Use setjmp/longjmp from ntdll."
- `6d374c30` ntdll: Enable the Hack for some internal applications
- `5994cb93` ntdll: Improve the locale hack by applying a hack
- `b09c2030` ntdll: Perform initial WoW64 initialization after locales are set-up
- `cf5aea65` ntdll: Get the right ImageBase on wow64
- `ba7cbdf4` wow64: Support running a BT module provided suspend routine
- `63d3f585` ntdll: Implement WOW64 thread suspension helpers.
- `0c6ac66f` wow64: Default to box64cpu for i386 emulation, but allow changing it with HODLL
- `fd88d285` box64cpu: Add Box64 based library (v0.3.0)
- `1a622895` ntdll: Only copy LOWORD of x86 segments
- `5c29cb8a` wowarmhw: Add new Qemu based library
