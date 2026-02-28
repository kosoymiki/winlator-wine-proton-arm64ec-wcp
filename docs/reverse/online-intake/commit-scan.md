# Online Commit Scan

- source: GitHub API (`gh api`) only
- repos scanned: **5**
- errors: **4**

## Errors

- `coffin_wine`: gh api failed: repos/coffincolors/wine/commits/9bdf2d7795baf3a1c0e3c39bf15d509522e2e22a: Get "https://api.github.com/repos/coffincolors/wine/commits/9bdf2d7795baf3a1c0e3c39bf15d509522e2e22a": read tcp 192.168.0.199:34978->134.0.118.88:443: read: connection reset by peer
- `froggingfamily_wine_tkg_git`: gh api failed: repos/Frogging-Family/wine-tkg-git/commits/97f2231bffbfab385046f08897df50663b571a2f: Get "https://api.github.com/repos/Frogging-Family/wine-tkg-git/commits/97f2231bffbfab385046f08897df50663b571a2f": read tcp 192.168.0.199:45750->134.0.118.88:443: read: connection reset by peer
- `termux_x11`: gh api failed: repos/termux/termux-x11/commits/6d627520b4717cdea1ed1530e6d063be7537cc8b: Get "https://api.github.com/repos/termux/termux-x11/commits/6d627520b4717cdea1ed1530e6d063be7537cc8b": read tcp 192.168.0.199:55266->89.108.98.20:443: read: connection reset by peer
- `utkarsh_gamenative`: gh api failed: repos/utkarshdalal/GameNative/commits/f3051a300984b4d31c16cf17eda7ebdee6b774cf: Get "https://api.github.com/repos/utkarshdalal/GameNative/commits/f3051a300984b4d31c16cf17eda7ebdee6b774cf": read tcp 192.168.0.199:54322->89.108.98.20:443: read: connection reset by peer

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

