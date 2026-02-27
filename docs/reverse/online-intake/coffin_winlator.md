# Online Intake: `coffincolors/winlator`

- Branch analyzed: `cmod_bionic`
- Default branch: `cmod_bionic`
- Updated at: `2026-02-27T01:42:17Z`
- Commits scanned: `25`

## Top categories

- `misc`: **198**
- `container_flow`: **60**
- `input_stack`: **33**
- `graphics_xserver`: **19**
- `launcher_runtime`: **14**
- `build_ci`: **10**
- `audio_stack`: **6**
- `arm64ec_core`: **1**

## Top touched files

- `app/src/main/res/values/strings.xml`: **13**
- `app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java`: **13**
- `app/build.gradle`: **10**
- `app/src/main/java/com/winlator/cmod/xenvironment/ImageFsInstaller.java`: **9**
- `app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java`: **7**
- `app/src/main/java/com/winlator/cmod/ShortcutsFragment.java`: **7**
- `app/src/main/java/com/winlator/cmod/contentdialog/ShortcutSettingsDialog.java`: **7**
- `app/src/main/java/com/winlator/cmod/winhandler/WinHandler.java`: **6**
- `app/src/main/res/values/arrays.xml`: **6**
- `app/src/main/java/com/winlator/cmod/MainActivity.java`: **6**
- `app/src/main/res/layout/container_detail_fragment.xml`: **5**
- `app/src/main/res/layout/shortcut_settings_dialog.xml`: **5**
- `app/src/main/java/com/winlator/cmod/container/Shortcut.java`: **4**
- `app/src/main/java/com/winlator/cmod/xenvironment/components/BionicProgramLauncherComponent.java`: **4**
- `app/src/main/java/com/winlator/cmod/ContainersFragment.java`: **4**
- `app/src/main/java/com/winlator/cmod/container/Container.java`: **4**
- `app/src/main/java/com/winlator/cmod/SettingsFragment.java`: **4**
- `app/src/main/res/layout/settings_fragment.xml`: **4**
- `app/src/main/res/menu/xserver_menu.xml`: **4**
- `app/src/main/assets/box86_64/box64-0.3.7.tzst`: **3**
- `app/src/main/java/com/winlator/cmod/widget/EnvVarsView.java`: **3**
- `app/src/main/java/com/winlator/cmod/contentdialog/ControllerAssignmentDialog.java`: **3**
- `app/src/main/cpp/jniLibs/arm64-v8a/libevshim.so`: **2**
- `app/src/main/cpp/winlator/evshim.c`: **2**
- `app/src/main/java/com/winlator/cmod/BigPictureActivity.java`: **2**

## Recent commit subjects

- `49bfb90f` fixed custom icons, default renderer, and warning prompt handling on new installs
- `11ec0ee4` uncomment installfromassets, yikes, sorry.
- `d5313d65` added renderer selection to registry keys in container detail fragment to fix black screen ddraw games per @Pippeto-Crypto
- `4ef54484` Added safety check to prevent parsing corrupted shortcuts and clean-up, fixed behavior of warning text in big picture activity, updated evshim.c with the final version, updated warning text for new update
- `0165e8ea` Fix range buttons, fix toggle function for input controls buttons
- `ef12a1c6` improve alsa client safety fixes reduce overhead, update arrays with box 3.2, update BionicProgramLauncherComponent with new evshim lib location, replace box64 with unpatched version, fix PEB log in WineRequestHandler, add screenSize to PEB log, add testing comment for apply evshim winebus.so to user-installed wine, add override for TarCompressorUtils, fix frontend support in XServerDisplayActivity and container_id handling in ShortcutsFragment and update instructions and overwrite previous instructions and fixes xractivity launch with intent (needs Ivonasek imrovements controller fixes still), improve gyro zeroing, replace proton packs with updated winebus, evshim full rewrite remove mmap (native class in project can be removed...)
- `d58a184c` performance insanity, fix gstreamer workaround overrides, change controller assignment dialog to a non-blocking simple initial check, add condition for Wrapper selection and extraction,
- `f1ea28a6` update version name to beta3, update containerdetailfragment gstreamer workaround values, add proton to contents manager, add auto install contents to make shipping new wcp easier
- `8f30d192` update version name to beta2, fixed layout issue in shortcut settings dialog, fixed checkbox persistance in shortcutSettingsDialog for gStreamerWorkaround as well as settingsfragment for peb,
- `b4367b71` set build name to Cmod-v13.1-hotfix-beta, adjusted update warning language for clarity in imageFsInstaller
- `1ebc1411` added extractx86_64InputDlls and new tzst to assets just in case, left unused for now.
- `05a4ce29` merge final changes from last dev apk, update arrays, update EnvVars with print, update FEXCoreManager with changes from apk, update ImageFSInstaller version, add Wine PEB logging from apk, make GStreamerWorkaround a toggle, update WineRequestHandler to create container/shortcut settings logs, disable generateWinePrefix, implement extractInputDlls to support the new controller implementation, update strings with new GStreamer Workaround details, remove dxvk 2.4.1-arm64ec, update all assets, update ImageFSInstaller version code to 23 and add warning for system files updates, add defaults for new graphicsDriverConfigDialog params to prevent null pointer exceptions, added arm64ec_input_dlls.tzst with v13 arm64ec dlls to prevent crashes with 3+ players and avoid extra shim dlls (xinput1_3 main.c from x86_64 proton build), changed extractInputDlls to extractArm64ecInputDlls
- `cb0ce9ca` merge final changes from dev branch, add vkbasalt, remove clipboard/browser code to BionicProgramLauncherComponent, add Simulate Touch Screen to shortcut settings, updated strings, arrays, layouts, update graphics driver components launcher, remove MEDIACONV env vars from BionicProgramLauncherComponent, update AdrenotoolsManager, update asset, re-add assets to commit
- `64c6ffee` final final touches, credits, logo update, link fix, strings fix
- `db7e3d58` final touches for cmod v13, cleaned up and refined some strings, fixed tint on favorite icon, fixed default background speed in Big Picture Activity (you're next buddy), hid relative mouse mode from shortcut settings (better behavior when handled via toggle)
- `838fa42c` feat(audio,core): Implement ALSA-Reflector and integrate guest libs
- `85677f29` added libevshim_guest.so in assets to this commit (was unversioned previously), replace copyDevLibs with new favorite icon launcher and update related shortcut and containerfragment classes/layouts
- `d68fa055` Virtual gamepad gyro, left‑stick option, new turbo/macros + UI and dialog polish; make P1 virtual‑exclusive, updated XServerDisplayActivity to pass winhandler to ControllerAssignmentDialog,update controller assignment name to controller manager in ui, added final proton-9.0-arm64ec to assets with native input bug fixes (recompile with opengl enabled)
- `393d7dfd` Add reactive visual feedback for virtual controls. Elements now render a translucent fill while actively pressed (or toggled), using low‑alpha overlays across BUTTON, D‑Pad, Range, Stick, and Trackpad types. Invalidate on touch transitions to ensure immediate redraw.
- `e59f4e22` Replace Wine’s xinput1_3 on arm64ec with the stable main.c from the Proton 9.0 x86_64 build, fixing the ARM64 crash in wine_xinput_hid_update, and refresh proton-9.0-arm64ec.txz accordingly. Fix MainActivity permission flow by requesting permissions sequentially and set dark mode default to false. Add a “Disable touchscreen mouse” toggle: the dialog persists the setting and TouchpadView now ignores finger‑driven mouse events while keeping stylus/external mouse and virtual gamepad behavior intact. Restored accidentally removed env setup calls in BionicProgramLauncherComponent. Updated build version name, removed unpatched box64 selection from arrays.xml (no controller support yet), bumped ImageFSInstaller version up to 22. Disabled touchscreen timeout logging.
