# Online Intake Combined Matrix

This report is produced via GitHub API only (no source clone).

## coffin_winlator: `coffincolors/winlator`

- branch: `cmod_bionic`
- commits scanned: **25**
- category mix: misc=198, container_flow=60, input_stack=33, graphics_xserver=19, launcher_runtime=14, build_ci=10

## coffin_wine: `coffincolors/wine`

- branch: `arm64ec`
- commits scanned: **25**
- category mix: misc=314, arm64ec_core=29, build_ci=14

## gamenative_protonwine: `GameNative/proton-wine`

- branch: `proton_10.0`
- commits scanned: **25**
- category mix: misc=57, arm64ec_core=31, build_ci=12, graphics_xserver=8, input_stack=4, audio_stack=2

## Cross-source focus

- Runtime stability first: prioritize `arm64ec_core`, `launcher_runtime`, `container_flow`.
- Defer risky `HACK`/revert clusters behind gated lanes before promoting to mainline.

