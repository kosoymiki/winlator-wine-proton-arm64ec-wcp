# GameHub 5.3.5 Reverse Ledger

Date: February 27, 2026
APK: `/home/mikhail/GameHub+5.3.5.Lite_RM.mod_DocProv_mod.apk`
Device baseline: RMX3709 (Android 15, SDK 35)
Installed package baseline: `com.miHoYo.GenshinImpact` (`versionName=5.3.5`, `versionCode=78`, `targetSdk=35`)

## Scope

This ledger records the reflective cycle for:
- static reverse of native libraries shipped in the APK,
- runtime launch forensics from device logs and process snapshots,
- parity comparison against `GameNative/proton-wine` startup/patch model.

The objective is to extract only reproducible, patchable behavior that can be transferred to our Winlator stack.

## Evidence Inputs

- APK metadata and native libs inventory (`arm64-v8a`, 35 shared objects).
- External app logs from device:
  - `/storage/emulated/0/Android/data/com.miHoYo.GenshinImpact/files/log/...`
  - `/storage/emulated/0/Android/data/com.miHoYo.GenshinImpact/files/logs/...`
  - `/storage/emulated/0/Android/data/com.miHoYo.GenshinImpact/files/XiaoKunLogcat/...`
- Live capture bundle:
  - `/tmp/gamehub_live_20260227_124752/logcat.txt`
  - `/tmp/gamehub_live_20260227_124752/ps.txt`
- Upstream comparator:
  - `GameNative/proton-wine` (`proton_10.0` branch), notably `build-step-arm64ec.sh`.

## Reflective Checkpoints

| Phase | Hypothesis | Observation | Decision |
|---|---|---|---|
| Before | Launch instability is mostly container payload mismatch | Device logs show valid container download/checksum for `proton10.0-arm64x-2` and resolved `winePath` | Payload integrity alone is not root cause |
| During | Runtime path may fail before wineserver init | Process snapshot confirms `wineserver`, multiple `wine` workers, `jwm`, and `:wine` process exist | Startup reaches post-bootstrap runtime |
| During | Surface/lifecycle handoff can kill session | Live logcat shows `WineActivity` visibility drop, `X11Controller` window reset, then `BufferQueue has been abandoned` | Primary failure cluster is activity/surface lifecycle, not archive integrity |
| During | Native stack may hide reusable orchestration | `libwinemu.so` and `libvfs.so` expose IPC/gamepad/memfd/SteamStub/vfs hooks; `libgpuinfo.so` exposes Vulkan probe JNI | High-value transfer is launch orchestration and diagnostics, not blind binary substitution |
| After | Upstream GN build assumptions may explain behavior | GN proton-wine build script applies Android patchset and compiles with `--without-xinput2` and related X features | Keep GN parity checks explicit in our patch contracts |
| After | Package identity may influence OEM behavior | Installed mod package id is `com.miHoYo.GenshinImpact`, with gamehub internals | Treat package identity as compatibility variable in tests, not as optimization guarantee |

## Key Findings

1. **Container delivery path is consistent**
   - Logs show download + MD5 verification for `proton10.0-arm64x-2` and warm-up package.
   - Container selection and install phases finish with concrete `winePath`.

2. **Observed launch reaches active Wine services**
   - Live process tree includes `wineserver`, `services.exe`, `winedevice.exe`, `explorer.exe`, `rpcss.exe`, `jwm`.
   - Therefore failures are post-bootstrap.

3. **Failure signature centers on UI/surface teardown**
   - `WineActivity` transitions to non-visible quickly.
   - `X11Controller: Windows Changed: 0 x 0 0 x 0` appears near teardown.
   - Followed by `BufferQueue has been abandoned` and activity destruction path.

4. **Runtime orchestration logic is concentrated in a few libraries**
   - `libwinemu.so`: direct rendering JNI, unix socket + epoll bridge, gamepad/rumble IPC, memfd handling.
   - `libvfs.so`: wine process detection, env hooks (`WINEMU_*`), driver path and SteamStub unpack logic.
   - `libgpuinfo.so`: Vulkan instance/device probing JNI and driver/version query surface.
   - `libxserver.so`: EGL/GLES path with X input/socket internals and event plumbing.

5. **Upstream GN parity signal is practical**
   - GN proton-wine script confirms Android-specific configure profile and patchset application flow.
   - This matches our need to keep patch contracts explicit when porting behavior into our stack.

## Non-Goals for This Cycle

- No binary transplant from mod APK into our runtime.
- No opaque patch carry-over without line-level traceability.
- No assumptions that package spoofing alone fixes runtime stability.

## Exit Criteria for This Ledger

- Full library matrix published (`LIBRARY_MATRIX.tsv`).
- Launch timeline and failure points documented (`PROCESS_LAUNCH_TIMELINE.md`).
- Actionable patch backlog produced with severity and acceptance gates (`PATCH_BACKLOG_FROM_RE.md`).

