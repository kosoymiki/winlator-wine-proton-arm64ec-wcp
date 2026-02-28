# Online Commit Scan

- source: GitHub API (`gh api`) only
- repos scanned: **9**
- errors: **0**

## Repo Summaries

### ahmad1abbadi_darkos

- repo: `ahmad1abbadi/darkos`
- branch: `main`
- marker totals: none

| SHA | Date | Files | Paths | Markers | Message |
| --- | --- | ---: | ---: | --- | --- |
| `ee48c639429e` | `2024-10-02T14:01:17Z` | 1 | 1 |  | Update README.md |
| `564f50c29fe2` | `2024-08-20T23:22:11Z` | 1 | 1 |  | fix installation some packages |
| `0171c69abdfb` | `2024-07-16T21:52:00Z` | 1 | 1 |  | fixed a mistake run-darkos.py |
| `ad4bb23432a7` | `2024-07-16T21:39:09Z` | 1 | 1 |  | Update run-darkos.py |
| `e864c7f1d9ab` | `2024-07-15T20:31:30Z` | 1 | 1 |  | Update currently version.txt |
| `f5eaf90d8683` | `2024-07-15T20:29:14Z` | 1 | 1 |  | Update installglibc.py |
| `560a5f70f182` | `2024-07-15T20:13:30Z` | 1 | 1 |  | Update run-darkos.py |
| `a8ce86996662` | `2024-07-15T18:32:06Z` | 1 | 1 |  | Update new-update.py |
| `9c7f152658a4` | `2024-07-15T18:20:26Z` | 1 | 1 |  | Update currently version.txt |
| `7cdda6f14554` | `2024-07-15T18:13:47Z` | 1 | 1 |  | Update currently version.txt |
| `6b2aa898be61` | `2024-07-15T18:13:23Z` | 1 | 1 |  | Update update-darkos.py |
| `bc04fcf2f96c` | `2024-07-15T18:12:51Z` | 1 | 1 |  | Update darkos.py |

### coffin_wine

- repo: `coffincolors/wine`
- branch: `arm64ec`
- marker totals: none

| SHA | Date | Files | Paths | Markers | Message |
| --- | --- | ---: | ---: | --- | --- |
| `51c64ec8733d` | `2024-12-08T14:33:15Z` | 2 | 2 |  | Revert "configure: Properly test clang for dwarf support." |
| `343daae0d64a` | `2024-11-24T18:35:40Z` | 1 | 1 |  | Partially revert f1d4dd7cc83d971c6e69c3f2bdffe85dbcd81c0a |
| `9bdf2d7795ba` | `2024-10-22T09:27:06Z` | 3 | 3 |  | Revert "winecrt0: Use version 2 of CHPE metadata." |
| `26abd3e04f23` | `2024-10-20T13:11:14Z` | 1 | 1 |  | ntdll: Default to libarm64ecfex for amd64 emulation |
| `caac07018711` | `2024-10-20T11:24:39Z` | 1 | 1 |  | HACK: Link box64cpu differently |
| `7e490e5002af` | `2024-10-19T17:03:48Z` | 2 | 2 |  | HACK: Don't build box64 library for ARM64EC |
| `8bc3a81619c9` | `2024-04-12T20:04:31Z` | 1 | 1 |  | HACK: ntdll: Rudimentary ARM64EC suspend support. |
| `ca5cafeef84b` | `2024-09-27T11:29:21Z` | 2 | 2 |  | HACK: define some extra arm64ec symbols to workaround llvm bugs |
| `bfd241c687b9` | `2024-10-13T09:57:12Z` | 1 | 1 |  | ntdll: Refuse to run on page sizes other than 4k |
| `1fa51459dc26` | `2024-03-24T13:28:19Z` | 1 | 1 |  | Revert "wow64: Use setjmp/longjmp from ntdll." |
| `6d374c30766b` | `2024-03-01T19:53:21Z` | 1 | 1 |  | ntdll: Enable the Hack for some internal applications |
| `5994cb936241` | `2023-09-04T17:53:14Z` | 1 | 1 |  | ntdll: Improve the locale hack by applying a hack |

### coffin_winlator

- repo: `coffincolors/winlator`
- branch: `cmod_bionic`
- marker totals: `ContentProfile`=8, `DXVK`=3, `VKD3D`=2

| SHA | Date | Files | Paths | Markers | Message |
| --- | --- | ---: | ---: | --- | --- |
| `49bfb90fce93` | `2025-08-10T06:35:24Z` | 4 | 4 |  | fixed custom icons, default renderer, and warning prompt handling on new installs |
| `11ec0ee4fe07` | `2025-08-07T08:05:22Z` | 1 | 1 |  | uncomment installfromassets, yikes, sorry. |
| `d5313d6588ea` | `2025-08-07T07:04:41Z` | 3 | 3 |  | added renderer selection to registry keys in container detail fragment to fix black screen ddraw games per @Pippeto-Crypto |
| `4ef5448483d7` | `2025-08-07T05:04:24Z` | 8 | 8 |  | Added safety check to prevent parsing corrupted shortcuts and clean-up, fixed behavior of warning text in big picture activity, updated evshim.c with the final version, updated warning text for new update |
| `0165e8ea6a64` | `2025-08-07T02:30:41Z` | 2 | 2 |  | Fix range buttons, fix toggle function for input controls buttons |
| `ef12a1c61bf9` | `2025-08-06T08:50:42Z` | 16 | 16 | ContentProfile | improve alsa client safety fixes reduce overhead, update arrays with box 3.2, update BionicProgramLauncherComponent with new evshim lib location, replace box64 with unpatched version, fix PEB log in WineRequestHandler, a |
| `d58a184cb2d4` | `2025-08-05T15:16:25Z` | 10 | 10 |  | performance insanity, fix gstreamer workaround overrides, change controller assignment dialog to a non-blocking simple initial check, add condition for Wrapper selection and extraction, |
| `f1ea28a66303` | `2025-08-04T08:47:31Z` | 11 | 11 | ContentProfile, DXVK, VKD3D | update version name to beta3, update containerdetailfragment gstreamer workaround values, add proton to contents manager, add auto install contents to make shipping new wcp easier |
| `8f30d192355e` | `2025-08-03T23:14:30Z` | 4 | 4 |  | update version name to beta2, fixed layout issue in shortcut settings dialog, fixed checkbox persistance in shortcutSettingsDialog for gStreamerWorkaround as well as settingsfragment for peb, |
| `b4367b71cc54` | `2025-08-03T22:23:41Z` | 2 | 2 |  | set build name to Cmod-v13.1-hotfix-beta, adjusted update warning language for clarity in imageFsInstaller |
| `1ebc14117dd6` | `2025-08-03T21:53:47Z` | 3 | 3 |  | added extractx86_64InputDlls and new tzst to assets just in case, left unused for now. |
| `05a4ce2911cd` | `2025-08-03T21:32:15Z` | 16 | 16 | DXVK | merge final changes from last dev apk, update arrays, update EnvVars with print, update FEXCoreManager with changes from apk, update ImageFSInstaller version, add Wine PEB logging from apk, make GStreamerWorkaround a tog |

### froggingfamily_wine_tkg_git

- repo: `Frogging-Family/wine-tkg-git`
- branch: `master`
- marker totals: none

| SHA | Date | Files | Paths | Markers | Message |
| --- | --- | ---: | ---: | --- | --- |
| `97f2231bffbf` | `2026-02-25T06:38:13Z` | 1 | 1 |  | proton: container: Bring our usual userpatches support to proton container builds |
| `2d624ba32f04` | `2026-02-04T21:50:37Z` | 1 | 1 |  | CI: fixup for unescaped chars on proton-arch-ntsync-nopackage |
| `ec2fe1375e4c` | `2026-01-31T13:35:39Z` | 2 | 2 |  | Hotfixes: Valve: Update de-steamify-10.0-be patchset for current Bleeding Edge |
| `0160d96ad5ed` | `2026-01-31T13:26:40Z` | 1 | 1 |  | container fixes: Pass the correct flag to configure.sh if SELinux is enabled (#1686) |
| `4ea7a331a4c6` | `2026-01-31T13:24:10Z` | 1 | 1 |  | readme fixups |
| `a1352a3b0840` | `2026-01-31T13:18:52Z` | 7 | 7 |  | proton: Time to break everyone's setup |
| `65ea535d2bcd` | `2026-01-28T23:54:53Z` | 1 | 1 |  | makepkg: Get rid of outdated package replace |
| `36ffb9fc77a5` | `2026-01-27T18:00:23Z` | 7 | 7 |  | Update proton-tkg patchsets for 19294e0a and move previous versions to legacy |
| `64ca71f0704e` | `2026-01-20T15:25:10Z` | 2 | 2 |  | Valve: Hotfixes: Add a secondary atiadlxx-ADL2 revert patch, and enable for BE |
| `2dd6c9363f46` | `2026-01-20T15:24:09Z` | 1 | 1 |  | Valve: Update de-steamify-10.0-be patch for current BE |
| `e291444b5f46` | `2026-01-09T19:11:51Z` | 1 | 1 |  | fix: pin Fedora CI to version 42 to prevent breakage due to fedora image changes (#1685) |
| `8c54250246d1` | `2026-01-03T14:42:32Z` | 1 | 1 |  | prepare: Don't choke one multiple cached vk.xml and video.xml files, and use the latest one available for each instead |

### gamenative_protonwine

- repo: `GameNative/proton-wine`
- branch: `proton_10.0`
- marker totals: `x11drv_xinput2_enable`=2

| SHA | Date | Files | Paths | Markers | Message |
| --- | --- | ---: | ---: | --- | --- |
| `6ccff11d0e7d` | `2026-02-23T16:39:05Z` | 5 | 5 |  | Activates `test-bylaws` patches for ARM64EC builds |
| `120d9174d70f` | `2026-02-23T21:36:43Z` | 3 | 3 |  | Reverts and patches winemenubuilder for Winlator |
| `2d7b60b63d0f` | `2026-02-01T04:24:43Z` | 69 | 69 | x11drv_xinput2_enable | feature: add android support |
| `b8fdff8e1f85` | `2026-01-17T00:53:35Z` | 2 | 2 |  | atiadlxx: Add stub for ADL_Display_ODClockInfo_Get(). |
| `6d0ed7cb2257` | `2026-01-16T22:43:49Z` | 2 | 2 |  | atiadlxx: Add ADL_Display_MVPUStatus_Get(). |
| `895fae95a6da` | `2023-02-13T14:05:53Z` | 1 | 1 |  | windows.media.speech: Add Vosk checks to autoconf. |
| `b3724d19b2dc` | `2026-01-05T21:23:45Z` | 1 | 1 |  | Revert "win32u: Initialize surface with white colour on creation." |
| `c373d92d1038` | `2025-12-23T20:42:20Z` | 3 | 3 |  | mscoree: Update Wine Mono to 10.4.1. |
| `74f92cc44dda` | `2025-11-19T03:33:41Z` | 1 | 1 |  | gdi32: HACK: Force using Microsoft Sans Serif for Thai. |
| `cfd8b1a2cef8` | `2025-12-09T18:57:03Z` | 1 | 1 |  | mf: Prevent the session from starting invalid topologies. |
| `a51874ceab12` | `2024-12-13T22:31:44Z` | 5 | 5 |  | gameinput: Introduce new DLL. |
| `c22deaae02f0` | `2025-06-18T08:23:54Z` | 1 | 1 |  | include: Add APP_LOCAL_DEVICE_ID definition. |

### ilya114_box64droid

- repo: `Ilya114/Box64Droid`
- branch: `main`
- marker totals: `D8VK`=2, `DXVK`=2

| SHA | Date | Files | Paths | Markers | Message |
| --- | --- | ---: | ---: | --- | --- |
| `e3cfa57650cd` | `2025-10-08T20:29:44Z` | 1 | 1 | DXVK, D8VK | EOL |
| `389a940de5a5` | `2025-05-22T14:23:39Z` | 1 | 1 | DXVK, D8VK | Update README.md |
| `72d0d37d4e48` | `2025-01-31T13:53:33Z` | 1 | 1 |  | Merge pull request #138 from someoneplanet/main |
| `d5ae79047168` | `2025-01-16T22:13:19Z` | 1 | 1 |  | Update install.sh |
| `36e5b3249296` | `2025-01-16T11:14:20Z` | 1 | 1 |  | Merge pull request #135 from windows11cmyk/main |
| `479096dbd21f` | `2025-01-16T10:59:31Z` | 1 | 1 |  | Update box64droid.py |
| `53a25e950ff2` | `2025-01-06T16:36:12Z` | 1 | 1 |  | Create generator-generic-ossf-slsa3-publish.yml |
| `58af92eaaea9` | `2024-12-31T19:40:29Z` | 1 | 1 |  | Update native.py |
| `e66bc9c1d03b` | `2024-12-31T16:37:00Z` | 1 | 1 |  | Update native.py |
| `e8d0c5724d15` | `2024-12-31T16:35:01Z` | 1 | 1 |  | Update box64droid.py |
| `3f213df85006` | `2024-12-31T16:22:22Z` | 1 | 1 |  | Update box64droid.py |
| `36f0ae9a015c` | `2024-12-31T12:53:02Z` | 1 | 1 |  | Update native.py |

### olegos2_mobox

- repo: `olegos2/mobox`
- branch: `main`
- marker totals: `D8VK`=6, `DXVK`=6, `TU_DEBUG`=6, `VKD3D`=6

| SHA | Date | Files | Paths | Markers | Message |
| --- | --- | ---: | ---: | --- | --- |
| `24e5611620ef` | `2024-11-23T06:35:32Z` | 1 | 1 |  | No more tokens |
| `b1032bc5426b` | `2024-06-19T12:25:25Z` | 1 | 1 |  | Merge pull request #445 from NathanKanaeru/patch-3 |
| `edf0d177c651` | `2024-06-19T12:25:13Z` | 1 | 1 | TU_DEBUG, DXVK, VKD3D, D8VK | Merge pull request #444 from NathanKanaeru/patch-2 |
| `0596541abcc5` | `2024-06-18T07:13:34Z` | 1 | 1 |  | Update README.md |
| `8284d49b4bf1` | `2024-06-18T06:38:11Z` | 1 | 1 | TU_DEBUG, DXVK, VKD3D, D8VK | Create README-id.md |
| `6eaf2288d9a7` | `2024-04-06T08:17:56Z` | 7 | 7 | TU_DEBUG, DXVK, VKD3D, D8VK | Merge pull request #341 from Webpage-gh/main |
| `8209b8e1c254` | `2024-04-06T07:26:10Z` | 7 | 7 | TU_DEBUG, DXVK, VKD3D, D8VK | Add Simplified Chinese translation |
| `d5c3b75066c1` | `2024-03-31T14:14:33Z` | 6 | 6 | TU_DEBUG, DXVK, VKD3D, D8VK | Merge pull request #329 from eltociear/add_ja-readme |
| `24b7576b9ace` | `2024-03-31T06:23:08Z` | 6 | 6 | TU_DEBUG, DXVK, VKD3D, D8VK | Add Japanese README |
| `cbca83402da9` | `2024-03-03T18:12:37Z` | 1 | 1 |  | change default wine for wow64 to 9.3 |
| `77a1d3dc51ae` | `2024-02-26T06:18:51Z` | 1 | 1 |  | revert, xz was fixed |
| `1a0cdb5ed18a` | `2024-02-25T20:21:39Z` | 1 | 1 |  | xz workaround try 2 |

### termux_x11

- repo: `termux/termux-x11`
- branch: `master`
- marker totals: none

| SHA | Date | Files | Paths | Markers | Message |
| --- | --- | ---: | ---: | --- | --- |
| `3376f0ed5f5c` | `2026-02-18T21:09:24Z` | 2 | 2 |  | fix(shell-loader): keep Loader in debug build |
| `451ebe5de412` | `2026-02-18T20:31:46Z` | 1 | 1 |  | Fix shell-loader binary size regression after Gradle upgrade |
| `658adf0c44cb` | `2026-02-18T20:11:39Z` | 6 | 6 |  | Fix resource shrinker removing runtime-resolved strings |
| `61f4fb541504` | `2026-02-18T19:33:21Z` | 2 | 2 |  | Fix R8 shrink breakage (JNI + reflection) |
| `702f2a1b64e6` | `2026-02-18T11:29:30Z` | 1 | 1 |  | Remove `android.enableJetifier=true` due to gradle warning. |
| `72f0fa95d3c8` | `2026-02-18T11:27:50Z` | 3 | 3 |  | Fix build after Gradle 9 upgrade |
| `f7e9ae7e5360` | `2026-02-16T00:53:11Z` | 1 | 1 |  | build(deps): bump com.android.tools.build:gradle from 8.13.1 to 9.0.1 |
| `5c21322de87b` | `2026-02-06T00:54:43Z` | 1 | 1 |  | build(deps): bump org.jetbrains.kotlin:kotlin-stdlib-jdk8 |
| `8725cd1abfae` | `2026-02-18T10:44:47Z` | 2 | 2 |  | build(deps): bump gradle-wrapper from 9.2.1 to 9.3.1 (#966) |
| `33f486970622` | `2026-02-18T10:43:35Z` | 1 | 1 |  | build(deps): bump actions/upload-artifact from 5 to 6 (#956) |
| `bbde9f3d0802` | `2026-02-18T10:43:26Z` | 1 | 1 |  | build(deps): bump actions/cache from 4 to 5 (#952) |
| `6d627520b471` | `2025-11-30T18:39:22Z` | 1 | 1 |  | Update Gradle Wrapper from 9.2.0 to 9.2.1 (#945) |

### utkarsh_gamenative

- repo: `utkarshdalal/GameNative`
- branch: `master`
- marker totals: none

| SHA | Date | Files | Paths | Markers | Message |
| --- | --- | ---: | ---: | --- | --- |
| `fa629bb70ed7` | `2026-02-28T05:44:33Z` | 1 | 1 |  | Revert "fix: remain connected to SteamService and solve for login page game s…" (#678) |
| `1bbebf6cfe25` | `2026-02-28T05:38:44Z` | 1 | 1 |  | fix: remain connected to SteamService and solve for login page game smother (#677) |
| `959b5cbe6c45` | `2026-02-28T04:24:59Z` | 4 | 4 |  | Adds Wine request component for external interactions (#676) |
| `48d10aafbaa5` | `2026-02-28T04:24:50Z` | 31 | 31 |  | Control editor improvements, touchpad gestures, and new default presets (#599) |
| `ba06986bccd0` | `2026-02-27T23:05:29Z` | 68 | 68 |  | Feat/UI ux overhaul final (#667) |
| `761d93b86cbf` | `2026-02-25T07:45:39Z` | 1 | 1 |  | fix: serve cached images when device has no internet (#635) |
| `08cc7a5c8feb` | `2026-02-25T07:41:57Z` | 7 | 7 |  | Use container language for GOG downloads (#627) |
| `b75b002530d9` | `2026-02-25T07:19:32Z` | 1 | 1 |  | fix: capture external mouse pointer on first event (#626) |
| `e27bff9f65ac` | `2026-02-25T05:01:32Z` | 1 | 1 |  | Fix L2/R2 being triggered as buttons instead of axis (#646) |
| `f3051a300984` | `2026-02-25T02:34:22Z` | 22 | 22 |  | Added steam offline mode for games like N++ (#645) |
| `cb3ee6efbe87` | `2026-02-25T00:00:05Z` | 1 | 1 |  | fix: retry cloud sync on AsyncJobFailedException (#643) |
| `af92a5e0dd05` | `2026-02-24T23:38:21Z` | 2 | 2 |  | sqlite queries can't use true and false as identifiers (either 1 and 0 or the strings 'True' and 'False' [since 3.23.0]) (#629) |

