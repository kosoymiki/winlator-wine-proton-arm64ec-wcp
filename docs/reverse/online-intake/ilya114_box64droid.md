# Online Intake: `Ilya114/Box64Droid`

- Transport: `gh`
- Scope: `focused`
- Branch analyzed: `main`
- Intake mode: `code-only`
- Default branch: `main`
- Updated at: `2026-02-28T07:40:59Z`
- Commits scanned: `0`

## Top categories

- `cpu_translation`: **2**
- `misc`: **1**

## Tree-wide categories (all files)

- files scanned: **3**
- `cpu_translation`: **2**
- `misc`: **1**

## Top touched files

- commit diff scan disabled in code-only mode

## Recent commit subjects

- commit scan disabled in code-only mode

## Focus file markers

- `scripts/native/box64droid.py` -> BOX64_DYNAREC, BOX64_LOG, WINEDEBUG, DXVK, D8VK
  - `L14` `DXVK`: `dxvk_config = config_folder + "DXVK_D8VK.conf"`
  - `L15` `D8VK`: `dxvk_config_hud =  config_folder + "DXVK_D8VK_HUD.conf"`
  - `L149` `BOX64_DYNAREC`: `os.system("BOX86_LOG=1 BOX86_SHOWSEGV=1 BOX86_DYNAREC_LOG=1 BOX86_DYNAREC_MISSING=1 BOX86_DLSYM_ERROR=1 BOX64_LOG=1 BOX64_SHOWSEGV=1 BOX64_DYNAREC_LOG=1 BOX64_DYNAREC_MISSING=1 BOX64_DLSYM_ERROR=1 WINEDEBUG=+err tasks...`
- `scripts/native/start-box64.py` -> DXVK, D8VK
  - `L3` `DXVK`: `exec(open('/sdcard/Box64Droid (native)/DXVK_D8VK_HUD.conf').read())`
- `README.md` -> DXVK, D8VK
  - `L5` `DXVK`: `Box64Droid is a project with scripts that automate installing preconfigured rootfs with [Box64](https://github.com/ptitSeb/box64), [Box86](https://github.com/ptitSeb/box86), [Wine](https://github.com/Kron4ek/Wine-Buil...`
  - `L33` `D8VK`: `- You can choose to use environment variables; there are three files: `DXVK_D8VK.conf`, `Box64Droid.conf`, and `DXVK_D8VK.conf`. These files are created and found in the /sdcard/Box64Droid/ folder after the first Box6...`
