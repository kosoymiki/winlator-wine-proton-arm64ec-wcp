# GameHub Provenance Report

- Generated (UTC): `2026-02-25 13:04:53`
- Scope: provenance model for GameHub-related repos referenced during optimization research

## Executive Summary

| Repo | Model | Confidence | Default Branch | Stars | Updated |
| --- | --- | --- | --- | ---: | --- |
| `gamehublite/gamehub-oss` | `apk-patchset-overlay` | `high` | `main` | 1095 | `2026-02-24` |
| `Producdevity/gamehub-lite` | `apk-patchset-overlay` | `high` | `master` | 1156 | `2026-02-25` |
| `tkashkin/GameHub` | `hybrid-source-and-patch` | `medium` | `master` | 2711 | `2026-02-25` |

## Model Distribution

| Model | Count |
| --- | ---: |
| `apk-patchset-overlay` | 2 |
| `hybrid-source-and-patch` | 1 |

## gamehublite/gamehub-oss

- Classification: `apk-patchset-overlay` (high confidence)
- Rationale: Repository appears to distribute patch layers over upstream APKs rather than full source ownership.
- Branch: `main`
- Stars/Forks/Open issues: `1095` / `58` / `51`
- README signals: `patches official app`, `mentions reverse engineering`, `claims source build`
- Patch/decompile signals: `patch-path markers: 198`, `apk-patching/decompile tool markers: 148`

Evidence paths:
- `autopatcher.sh`
- `lite_resources/smali_classes10`
- `lite_resources/smali_classes10/bin`
- `lite_resources/smali_classes10/bin/mt`
- `lite_resources/smali_classes10/bin/mt/file`
- `lite_resources/smali_classes10/bin/mt/file/content`
- `lite_resources/smali_classes10/bin/mt/file/content/MTDataFilesProvider.smali`
- `lite_resources/smali_classes10/bin/mt/file/content/MTDataFilesWakeUpActivity.smali`
- `lite_resources/smali_classes4`
- `lite_resources/smali_classes4/com`

## Producdevity/gamehub-lite

- Classification: `apk-patchset-overlay` (high confidence)
- Rationale: Repository appears to distribute patch layers over upstream APKs rather than full source ownership.
- Branch: `master`
- Stars/Forks/Open issues: `1156` / `26` / `81`
- README signals: `mentions reverse engineering`, `mentions upstream mirroring`
- Patch/decompile signals: `patch-path markers: 3372`, `apk-patching/decompile tool markers: 386`
- Source-structure signals: `kotlin/java file markers: 7`

Evidence paths:
- `patches`
- `patches/.gitkeep`
- `patches/binary_replacements`
- `patches/binary_replacements/original`
- `patches/binary_replacements/original/AndroidManifest.xml`
- `patches/binary_replacements/res`
- `patches/binary_replacements/res/drawable-xxhdpi`
- `patches/binary_replacements/res/drawable-xxhdpi/wine_game_loading.jpg`
- `patches/binary_replacements/res/raw`
- `patches/binary_replacements/res/raw/click.mp3`
- `revanced/patches/build.gradle.kts`
- `revanced/patches/src/main/kotlin/app/revanced/patches/gamehub/misc/GameHubLitePatch.kt`
- `revanced/patches/src/main/kotlin/app/revanced/patches/gamehub/misc/RemoveTrackingResourcesPatch.kt`
- `revanced/patches/src/main/kotlin/app/revanced/patches/gamehub/shared/Fingerprints.kt`
- `revanced/patches/src/main/kotlin/app/revanced/patches/gamehub/telemetry/DisableAllTelemetryPatch.kt`
- `revanced/patches/src/main/kotlin/app/revanced/patches/gamehub/telemetry/DisableTelemetryPatch.kt`

## tkashkin/GameHub

- Classification: `hybrid-source-and-patch` (medium confidence)
- Rationale: Repository combines source files with patch/decompile artifacts; selective reuse is required.
- Branch: `master`
- Stars/Forks/Open issues: `2711` / `193` / `272`
- Patch/decompile signals: `patch-path markers: 1`
- Source-structure signals: `vala source markers: 127`

Evidence paths:
- `flatpak/libs/polkit/polkit-build-Add-option-to-build-without-polkitd.patch`
- `src/app.vala`
- `src/data/CompatTool.vala`
- `src/data/Emulator.vala`
- `src/data/Game.vala`
- `src/data/GameSource.vala`
- `src/data/Runnable.vala`
- `src/data/adapters/GamesAdapter.vala`
- `src/data/compat/CustomEmulator.vala`
- `src/data/compat/CustomScript.vala`
- `src/data/compat/DOSBox.vala`

## Reuse Guidance for Winlator CMOD

- Treat `apk-patchset-overlay` repos as idea references; do not import binaries or smali patch flows into mainline CI.
- Prefer source-first repos for direct code borrowing, then port only minimal, testable deltas.
- Keep provenance tags in commit messages when adopting logic influenced by these upstreams.
