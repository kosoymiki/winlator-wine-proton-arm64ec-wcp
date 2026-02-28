# GameHub 5.3.5 Process Launch Timeline

Date anchor: February 27, 2026
Primary package: `com.miHoYo.GenshinImpact`

## Scenario A: Proton container path (observed)

### 1) Before launch (container/content preparation)

Source: `util_2026_02_27_com.miHoYo.GenshinImpact.txt`, `log_2026_02_27_0.txt`

- `12:28:22` - `EmuFileDownload {name=proton10.0-arm64x-2, version=1.0.3}`.
- `12:28:50` - Proton archive MD5 validation passes (`6dcb...`).
- `PcEmuSetup` reports container install complete:
  - `winePath=/data/user/0/com.miHoYo.GenshinImpact/files/usr/opt/wine_proton10.0-arm64x-2`.

### 2) During launch (runtime boot)

Source: `/tmp/gamehub_live_20260227_124752/logcat.txt`, `/tmp/gamehub_live_20260227_124752/ps.txt`

- `12:47:52` - `WineActivity` becomes focused in task transition.
- Process tree confirms running runtime chain:
  - `com.miHoYo.GenshinImpact:wine`
  - `wineserver`
  - multiple `wine C:\windows\system32\*.exe`
  - `jwm`
- This proves user-space bootstrap completed and the container runtime was active.

### 3) After launch (teardown/failure signature)

Source: `/tmp/gamehub_live_20260227_124752/logcat.txt`

- `12:47:53` - visibility transition starts away from `WineActivity`.
- `X11Controller: Windows Changed: 0 x 0 0 x 0`.
- Surface pipeline errors follow:
  - `BufferQueue has been abandoned` (query/dequeue).
- `WineActivity` window is destroyed and removed from task history.

## Scenario B: Wine path (observed from app external wine logs)

Source: `util_2026_02_27_com.miHoYo.GenshinImpact_wine.txt`

- Multiple launches observed (`12:34`, `12:36`, `12:39`) with repeated sequence:
  - `WinEmuServiceImpl initByWineProcess`
  - `WineInGameSettings ...`
  - `WineActivity updateNativeRenderingMode = Never`
  - `WindowRealizedCallback`
  - `stopWineLoading`
- Workload examples:
  - desktop launch (`exePath=explorer.exe`)
  - local game launch (`war3.exe` with app id `999999995`)
- Repeated heartbeat telemetry errors exist (`Invalid parameters`) but they are telemetry-plane, not direct evidence of runtime bootstrap failure.

## Cross-Scenario Causal Notes

1. Runtime user-space startup reaches a healthy process set before failure.
2. Dominant failure marker is activity/surface lifecycle collapse, not missing binaries.
3. Launch diagnostics need stronger coupling: activity state + X11 window state + surface queue status + process survival.

## What This Timeline Changes in Implementation Priority

- P0 priority goes to launch lifecycle hardening (avoid premature surface/activity teardown).
- P1 priority goes to X11/surface diagnostics and recovery path.
- Payload checks (download/hash/install) remain necessary but are not the primary fix path for this failure class.

