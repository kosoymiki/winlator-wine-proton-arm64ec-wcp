# Online Intake: `coffincolors/winlator`

- Transport: `gh`
- Scope: `focused`
- Branch analyzed: `cmod_bionic`
- Intake mode: `code-only`
- Default branch: `cmod_bionic`
- Updated at: `2026-02-27T21:43:58Z`
- Commits scanned: `0`

## Top categories

- `container_flow`: **2**
- `graphics_xserver`: **1**
- `launcher_runtime`: **1**

## Tree-wide categories (all files)

- files scanned: **4**
- `container_flow`: **2**
- `graphics_xserver`: **1**
- `launcher_runtime`: **1**

## Top touched files

- commit diff scan disabled in code-only mode

## Recent commit subjects

- commit scan disabled in code-only mode

## Focus file markers

- `app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java` -> MESA_VK_WSI_PRESENT_MODE, FEXCore, WINEDEBUG, DXVK, VKD3D, D8VK, cnc-ddraw, ContentProfile
  - `L69` `DXVK`: `import com.winlator.cmod.contentdialog.DXVKConfigDialog;`
  - `L73` `VKD3D`: `import com.winlator.cmod.contentdialog.VKD3DConfigDialog;`
  - `L74` `ContentProfile`: `import com.winlator.cmod.contents.ContentProfile;`
  - `L95` `FEXCore`: `import com.winlator.cmod.fexcore.FEXCoreManager;`
- `app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java` -> BOX64_DYNAREC, BOX64_NOBANNER, BOX64_LOG, PROOT_TMP_DIR
  - `L158` `PROOT_TMP_DIR`: `envVars.put("PROOT_TMP_DIR", tmpDir);`
  - `L213` `BOX64_NOBANNER`: `envVars.put("BOX64_NOBANNER", ProcessHelper.PRINT_DEBUG && enableLogs ? "0" : "1");`
  - `L214` `BOX64_DYNAREC`: `envVars.put("BOX64_DYNAREC", "1");`
  - `L217` `BOX64_LOG`: `envVars.put("BOX64_LOG", "1");`
- `app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java` -> FEXCore, DXVK, VKD3D, ContentProfile
  - `L44` `DXVK`: `import com.winlator.cmod.contentdialog.DXVKConfigDialog;`
  - `L47` `VKD3D`: `import com.winlator.cmod.contentdialog.VKD3DConfigDialog;`
  - `L48` `ContentProfile`: `import com.winlator.cmod.contents.ContentProfile;`
  - `L63` `FEXCore`: `import com.winlator.cmod.fexcore.FEXCoreManager;`
- `app/src/main/java/com/winlator/cmod/contents/ContentsManager.java` -> DXVK, VKD3D, libarm64ecfex.dll, ContentProfile, REMOTE_PROFILES
  - `L28` `REMOTE_PROFILES`: `public static final String REMOTE_PROFILES = "contents.json";`
  - `L29` `DXVK`: `public static final String[] DXVK_TRUST_FILES = {"${system32}/d3d8.dll", "${system32}/d3d9.dll", "${system32}/d3d10.dll", "${system32}/d3d10_1.dll",`
  - `L32` `VKD3D`: `public static final String[] VKD3D_TRUST_FILES = {"${system32}/d3d12core.dll", "${system32}/d3d12.dll",`
  - `L36` `libarm64ecfex.dll`: `public static final String[] FEXCORE_TRUST_FILES = {"${system32}/libwow64fex.dll", "${system32}/libarm64ecfex.dll"};`
