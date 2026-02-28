# Online Intake: `utkarshdalal/GameNative`

- Transport: `gh`
- Scope: `focused`
- Branch analyzed: `master`
- Intake mode: `code-only`
- Default branch: `master`
- Updated at: `2026-02-28T05:44:37Z`
- Commits scanned: `0`

## Top categories

- `launcher_runtime`: **1**
- `graphics_xserver`: **1**
- `cpu_translation`: **1**

## Tree-wide categories (all files)

- files scanned: **3**
- `launcher_runtime`: **1**
- `graphics_xserver`: **1**
- `cpu_translation`: **1**

## Top touched files

- commit diff scan disabled in code-only mode

## Recent commit subjects

- commit scan disabled in code-only mode

## Focus file markers

- `app/src/main/java/com/winlator/xenvironment/components/GuestProgramLauncherComponent.java` -> BOX64_DYNAREC, BOX64_NOBANNER, BOX64_LOG, PROOT_TMP_DIR
  - `L285` `PROOT_TMP_DIR`: `envVars.put("PROOT_TMP_DIR", tmpDir);`
  - `L358` `BOX64_NOBANNER`: `envVars.put("BOX64_NOBANNER", ProcessHelper.PRINT_DEBUG && enableLogs ? "0" : "1");`
  - `L359` `BOX64_DYNAREC`: `envVars.put("BOX64_DYNAREC", "1");`
  - `L364` `BOX64_LOG`: `envVars.put("BOX64_LOG", "1");`
- `app/src/main/java/app/gamenative/ui/screen/xserver/XServerScreen.kt` -> WRAPPER_VK_VERSION, MESA_VK_WSI_PRESENT_MODE, TU_DEBUG, FEXCore, WINEDEBUG, DXVK, VKD3D, D8VK, cnc-ddraw, ContentProfile
  - `L83` `ContentProfile`: `import com.winlator.contents.ContentProfile`
  - `L87` `DXVK`: `import com.winlator.core.DXVKHelper`
  - `L103` `FEXCore`: `import com.winlator.fexcore.FEXCoreManager`
  - `L1825` `WINEDEBUG`: `"WINEDEBUG",`
- `app/src/main/assets/box64_env_vars.json` -> BOX64_DYNAREC, BOX64_DYNAREC_STRONGMEM
  - `L2` `BOX64_DYNAREC`: `{"name" : "BOX64_DYNAREC_SAFEFLAGS", "values" : ["0", "1", "2"], "defaultValue" : "2"},`
  - `L7` `BOX64_DYNAREC_STRONGMEM`: `{"name" : "BOX64_DYNAREC_STRONGMEM", "values" : ["0", "1", "2", "3"], "defaultValue" : "0"},`
