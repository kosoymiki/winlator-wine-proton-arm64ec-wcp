# Ae.solator - Reflective Implementation Log

## Baseline (Stage 0)

### Before

- Goal: lock a reliable baseline before changing Turnip, nightly contents, logging, branding, and README.
- Risks:
  - `work/winlator-ludashi/src` is a nested git repo on branch `wcp/0001-rebase` with untracked `.rej` files from previous patch attempts.
  - Root repo is dirty (`ci/winlator/apply-repo-patches.sh` modified, `AGENTS.md` untracked, `work/` untracked in root).
  - CI patch stack currently stops at `0004`; new changes should avoid rewriting large existing patches if possible.
- Success criteria:
  - Baseline facts are documented (package/app ID, current logging model, Turnip/nightly patch entry points).
  - Execution can proceed in isolated steps with explicit verification points.

### During

- Confirmed current Winlator source is available under `work/winlator-ludashi/src` and is suitable as the working tree for generating a follow-up patch.
- Confirmed current branding values in source:
  - `namespace = com.winlator.cmod`
  - `applicationId = com.winlator.cmod` in upstream source, branding adjustments currently come from patches (not source HEAD)
- Confirmed root patch stack:
  - `0001-winlator-arm64ec-runtime-and-fex.patch`
  - `0002-debug-no-embedded-runtime.patch`
  - `0003-wcphub-beta-turnip.patch`
  - `0004-theme-darkgreen-daynight.patch`
- Confirmed current log path behavior:
  - `DebugDialog` writes through `LogView.getLogFile(context)`
  - file target is `Winlator/logs` under configured Winlator path
- Confirmed `Box64` logging toggle exists and only affects env vars (`BOX64_LOG`, `BOX64_DYNAREC_MISSING`) in `GuestProgramLauncherComponent`.
- Confirmed `enable_vulkan_api_dump` string exists but no active code path was found enabling Vulkan api dump.
- Confirmed current branding patch intent (`0002`) already uses `by.aero.so.benchmark` naming in patch content.

### After

- Baseline is stable enough to implement changes in the nested Winlator source and export them as a new follow-up patch (`0005-*`) instead of manually rewriting `0002/0003/0004`.
- Working assumptions for next stage:
  - Fix Turnip installation by removing fragile `Uri.fromFile(...)` -> `ContentResolver` path for downloaded files.
  - Stabilize nightly content filtering and UI reload path in `ContentsFragment`/`ContentsManager`.

## Stage 1 - Turnip latest download/install flow

### Before

- Goal: fix the broken Turnip "latest" path (download -> installer handoff -> install -> UI refresh).
- Risks:
  - `file://` handoff to `ContentResolver` may be the real break, but install failures could also come from zip structure assumptions.
  - Manual zip extraction changes can introduce path traversal or temp-dir cleanup bugs.
- Success criteria:
  - Latest Turnip can be downloaded from GitHub Releases and installed without file picker.
  - Installed driver appears in Adrenotools list without duplicates.

### During

- Confirmed the fragile point: downloaded files were going through `Uri.fromFile(...)` and `installDriver(Uri)` (`ContentResolver` path).
- Implemented a direct install path (`installDriver(File)` -> shared stream extraction).
- Hardened extraction logic:
  - zip-slip guard
  - nested directories creation
  - `meta.json` validation
  - recursive temp cleanup via `FileUtils.delete(...)`
- Added UI button to fetch latest Turnip release assets and select zip directly.

### After

- Canonical path for downloaded Turnip installs is now `File`/stream-based, not `ContentResolver`-based.
- UI now supports `Download latest Turnip driver` and avoids duplicate entries in the list.
- Remaining runtime validation depends on device-side manual test (not completed in CLI-only flow).

## Stage 2 - WCPHub beta/nightly contents filtering and refresh

### Before

- Goal: restore predictable beta/nightly visibility and live reload in `Contents`.
- Risks:
  - Spinner mapping could desync if visible types are filtered but code still indexes `ContentType.values()`.
  - Beta toggle could reload remote profiles but leave stale local UI state.
- Success criteria:
  - Toggle changes list content immediately.
  - Filtering is deterministic for beta/nightly signals (`beta` field, version name, URL).

### During

- Confirmed prior code path reloaded remote contents only on resume and used a single `setRemoteProfiles(json)` path.
- Added `showBeta` preference/toggle and a dedicated `reloadRemoteContents()` path.
- Reworked spinner handling to map against an explicit `allowedTypes` list (avoids raw enum-index coupling).
- Added overloaded `ContentsManager.setRemoteProfiles(json, includeBeta, ignoreWine)` and beta/nightly detection rules.

### After

- Nightly visibility is now a user-controlled setting and reloads without fragment restart.
- Filtering logic is explicit and centralized in `ContentsManager`.
- ARM64EC-focused contents view remains intentional (`WINE`, `BOX64`, `WOWBOX64` hidden in remote list path).

## Stage 3 - Runtime logging expansion (FEX / Vulkan / Turnip)

### Before

- Goal: extend the existing Box64 logging model so users can enable FEX/Vulkan/Turnip logs from settings and collect files under `Winlator/logs`.
- Risks:
  - Runtime env vars differ across versions (especially FEX logging support).
  - Adding callbacks may duplicate output or degrade `DebugDialog` behavior.
- Success criteria:
  - New settings persist.
  - Runtime log files are created in the same log directory policy as `LogView`.

### During

- Added shared log-path helper (`WinlatorLogUtils`) and file-backed debug callback (`FileDebugLogger`).
- Added callback cleanup in `ProcessHelper.removeAllDebugCallbacks()` for `Closeable` debug sinks to avoid leaking file descriptors between sessions.
- Reused the existing `enable_vulkan_api_dump` preference key and added:
  - `enable_fex_logs`
  - `enable_turnip_logs`
- Extended `SettingsFragment`, `settings_fragment.xml`, `XServerDisplayActivity`, and `GuestProgramLauncherComponent`.
- Implemented env-var wiring:
  - FEX: `FEX_LOG_LEVEL`, `FEX_LOG_FILE` (runtime support depends on bundled FEX version)
  - Vulkan: `VK_LAYER_LUNARG_api_dump` + file path vars
  - Turnip/Mesa: `MESA_LOG_FILE`, `MESA_DEBUG`

### After

- New log toggles are wired to preferences and runtime setup.
- `main_menu_logs` visibility now reflects all log toggles, not only Wine/Box64.
- `LogView` and runtime log files share the same `Winlator/logs` path policy.
- Device-side validation is still required to confirm exact FEX env-var support on the shipped runtime build.

## Stage 4 - Branding and package identity (`Ae.solator`)

### Before

- Goal: finish the package/app identity move to `by.aero.so.benchmark` and remove fragile hardcoded provider authorities.
- Risks:
  - Provider authority mismatch can break file sharing and DocumentsProvider integration.
  - Package rebrand changes can be confused with Java package/namespace refactor (which is not required here).
- Success criteria:
  - APK identity uses `by.aero.so.benchmark`.
  - Manifest providers derive authorities from `${applicationId}`.

### During

- Updated `applicationId` to `by.aero.so.benchmark` and version name suffix for Ae.solator benchmark build identity.
- Switched app label to `@string/app_name` and set resource value to `Ae.solator`.
- Replaced hardcoded provider authorities with `${applicationId}` placeholders.
- Removed an extra stray `>` in `AndroidManifest.xml` while touching the file.

### After

- Branding is now consistent at the manifest/Gradle/resource level without refactoring Java package names.
- Provider authorities track the package ID automatically.
- Legacy broadcast action string was intentionally left unchanged in this step to avoid changing shortcut behavior without a dedicated regression pass.

## Stage 5 - Emerald accent refresh

### Before

- Goal: move the primary accent away from blue toward a clearer emerald tone in both light/dark usage.
- Risks:
  - Theme accents are referenced through multiple aliases (`colorAccent`, material teal aliases, fallback accent).
  - A color-only change can miss dark-mode buttons and preference accents.
- Success criteria:
  - Core accent tokens and their aliases are updated consistently.

### During

- Updated `colorAccent`, `colorAccentDark`, `button_positive_dark`, material teal aliases, and `preference_fallback_accent_color`.
- Kept the change scoped to shared tokens already referenced by styles to avoid broad UI regressions.

### After

- Accent palette is visibly more emerald while preserving existing theme wiring.
- Further per-screen polish can be done later if any component still pulls hardcoded blue tones.

## Stage 6-7 - Repository cleanup and README redesign

### Before

- Goal: clean repo noise and reposition project branding to `Ae.solator`, while keeping Ludashi as upstream thanks.
- Risks:
  - Over-cleaning may hide files developers actually want tracked locally.
  - README rewrite can drift from real script names / artifact naming.
- Success criteria:
  - Root README reflects Ae.solator branding and benchmark rationale.
  - Local noise (`work/`, `out/`, `*.rej`) is suppressed from root status.

### During

- Added root `.gitignore` for generated folders and patch rejection artifacts.
- Copied upstream-style logo graphic into `docs/assets/` for README hero image.
- Rewrote root `README.md` in a Ludashi-inspired structure (hero image, install/build notes, components, credits), but with Ae.solator branding and explicit `.benchmark` explanation.
- Updated `docs/winlator-fork-integration.md` and `AGENTS.md` wording to reference Ae.solator build identity while preserving upstream Ludashi context.

### After

- Repo top-level presentation now reflects `Ae.solator` as the primary fork identity.
- Ludashi remains credited as upstream base/inspiration rather than the main brand.
- Cleanup stayed non-destructive: no user local work trees or `.rej` files were deleted.

## Stage 8 - Patch export and validation

### Before

- Goal: export a clean follow-up patch (`0005`) for CI application and verify patch integrity.
- Risks:
  - New helper Java files (`FileDebugLogger`, `WinlatorLogUtils`) would be missed by plain `git diff` because they are untracked.
  - Patch hunk corruption risk (previous CI failure pattern) must be explicitly checked.
- Success criteria:
  - `0005` includes all intended source changes, including new files.
  - `git apply --check` passes on a clean archive of the nested source repo `HEAD`.

### During

- Used `git add -N` for new Java helper files so they appear in the generated diff without committing/staging content.
- Exported `ci/winlator/patches/0005-aeroso-turnip-nightly-logs-branding-cleanup.patch`.
- Ran `git diff --check` on the nested source diff and `git apply --check --reverse` against the live working tree.
- Created a temporary archive from nested repo `HEAD` and validated `git apply --check` on that clean snapshot.

### After

- Patch `0005` is syntactically valid and applies to a clean archive snapshot of the nested source repo `HEAD`.
- CLI validation is complete at patch/integrity level; full Android build validation is blocked in this environment because Gradle wrapper download is denied (no network access in sandbox).

## Execution Validation Follow-up (after `0005`)

### Before

- Goal: run the next practical validations after patch export: patch-stack application on the current `winlator_bionic`, local Gradle compile, and CI script dry run in isolated temp directories.
- Risks:
  - Existing legacy patches (`0001`-`0004`) may no longer match current upstream `winlator_bionic`.
  - Local machine may not have Android SDK configured, making Gradle compile results inconclusive.
- Success criteria:
  - Produce concrete pass/fail evidence for the current patch stack and local build prerequisites.

### During

- Ran a custom patch-stack apply check (`0001` -> `0005`) against a clean worktree of local `winlator_bionic` using the same `git apply --index --3way --recount` behavior as the patch script.
- Result: failure at `0001-winlator-arm64ec-runtime-and-fex.patch` (large upstream drift, multiple hunks no longer match current `winlator_bionic` source layout).
- Ran `./gradlew --no-daemon :app:compileDebugJavaWithJavac` with network enabled (wrapper download succeeded).
- Result: build configuration fails locally because Android SDK is not configured (`ANDROID_HOME`/`sdk.dir` missing).
- Ran `ci/winlator/ci-build-winlator-ludashi.sh` in isolated temp `WORK_DIR`/`OUT_DIR` with `WINLATOR_GRADLE_TASK=help` and local repo path as clone source (to avoid touching real `work/`).
- Result: script reproduces the same blocker: `0001` patch conflicts on current `winlator_bionic`. Submodule clone also warns/fails in this local test environment due proxy/network settings, but the script already tolerates submodule failure (`|| true`) and continues until patch failure.

### After

- The new `0005` patch is valid, but the **overall CI patch stack is still blocked by pre-existing drift in `0001`** against current upstream `winlator_bionic`.
- Local source compile validation is additionally blocked by missing Android SDK configuration on this machine.
- Next real unblock is not in `0005`; it is a rebase/refresh of legacy patch `0001` (and likely follow-up checks for `0002`-`0004`) or pinning CI to a known-compatible upstream commit.

## Patch Stack Rebase / CI Unblock (follow-up)

### Before

- Goal: remove the actual CI blocker so `0001`-`0005` apply again in sequence on current `winlator_bionic`.
- Risks:
  - The failure could be patch drift, patch corruption, or patch-script behavior (different root causes require different fixes).
  - Reworking `0001` and `0005` together could accidentally duplicate/erase changes already covered by `0002`-`0004`.
- Success criteria:
  - `apply-repo-patches.sh` applies `0001`..`0005` cleanly on a fresh upstream checkout.
  - Isolated `ci-build-winlator-ludashi.sh` reaches the next external build prerequisite blocker.

### During

- Reconstructed and regenerated `0001-winlator-arm64ec-runtime-and-fex.patch` against current `winlator_bionic` by applying the intended logic to a clean temporary worktree (9 files).
- Found the deeper CI failure root cause: `ci/winlator/apply-repo-patches.sh` was unconditionally normalizing patch files with `sed 's/\\r$//'`, which breaks valid patches targeting CRLF-formatted upstream files.
  - Evidence: `git apply --check` succeeds with the original patch file, but fails on the normalized copy.
- Fixed `apply-repo-patches.sh` to apply original patch files directly (no destructive CRLF normalization).
- Rebased `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch` to be **incremental on top of `0001`-`0004`** instead of diffing directly from plain upstream.
  - Used a temporary patched tree (`0001`-`0004` applied), resolved the overlapping conflicts, and regenerated `0005`.
- Validated patch-stack application in an isolated local clone:
  - `0001` ✅
  - `0002` ✅
  - `0003` ✅
  - `0004` ✅
  - `0005` ✅

### After

- CI patch phase is now unblocked: `apply-repo-patches.sh` successfully applies `0001`..`0005` on current `winlator_bionic`.
- Isolated `ci-build-winlator-ludashi.sh` dry-run now proceeds past clone/submodules/patches/assets-fix and stops at the expected local environment blocker:
  - Android SDK not configured (`ANDROID_HOME` / `sdk.dir` missing).
- The remaining blocker for a full local APK build is environment setup, not patch logic.

## Final Local Build Validation (SDK + patch-stack + assembleDebug)

### Before

- Goal: finish the local end-to-end validation and confirm the current patch stack produces a real APK.
- Risks:
  - Android SDK/tooling setup could still be incomplete.
  - A late-stage AAPT or Gradle error could expose regressions not visible in patch-only checks.
  - Regenerating `0005` to fix late errors could accidentally regress `0001` behavior (embedded runtime skip path).
- Success criteria:
  - `ci-build-winlator-ludashi.sh` completes `assembleDebug`.
  - Built APK path is produced.
  - Patch-stack still preserves `prepareEmbeddedWineAssets`/`WINEDLLPATH` changes from `0001`.

### During

- Installed local Android SDK components and accepted licenses (`platform-tools`, `platforms;android-34`, `build-tools;35.0.0`, `ndk;29.0.14206865`, `cmake;3.22.1`) under `/home/mikhail/.local/android-sdk`.
- First full isolated `assembleDebug` run failed in `:app:processDebugResources`:
  - `AAPT: error: resource style/SwitchCompat not found` (from `contents_fragment.xml`).
- Fixed the resource issue by adding a compatibility alias style:
  - `app/src/main/res/values/styles.xml`: `SwitchCompat -> Widget.AppCompat.CompoundButton.Switch`.
- While regenerating `0005`, caught a logic regression in a bad intermediate export:
  - `0005` started reverting `0001` (`prepareEmbeddedWineAssets` -> `downloadProton`, and `WINEDLLPATH` removal).
- Rebuilt `0005` correctly via 3-way rebase workflow against base `0001`-`0004` and manually resolved overlap conflicts (keeping `0001` runtime changes + `0005` branding/UI/logging changes).
- Revalidated stack on a fresh clone:
  - `prepareEmbeddedWineAssets` preserved ✅
  - `WINEDLLPATH` preserved ✅
  - `SwitchCompat` style alias present ✅
- Reran isolated `ci-build-winlator-ludashi.sh` with SDK configured and proxies unset.

### After

- Full local CI-style build completed successfully:
  - `:app:assembleDebug` ✅
  - `BUILD SUCCESSFUL` ✅
- Produced APK:
  - `out/winlator/by.aero.so.benchmark-debug-7a315de.apk`
- Remaining issues observed are warnings only (duplicate `POST_NOTIFICATIONS` declaration, C/C++ warnings from upstream/native code), not build blockers.

## Forensic Book Integration (WP0–WP7, Phase 1/2)

### Before

- Goal: implement the forensic plan on top of the current Ae.solator fork without breaking the working patch stack, and make the changes reusable across all WCP packages (`wine-11`, `GE`, `GameNative`).
- Risks:
  - The repo is intentionally dirty (including `.rej` files), so validation steps can fail for reasons unrelated to new logic.
  - Parser hardening, runtime normalization, and launch tracing touch critical startup paths (`ContainerManager`, `XServerDisplayActivity`, `GuestProgramLauncherComponent`).
  - CI forensic manifests must remain packaging-only metadata and not change runtime payload semantics.
- Success criteria:
  - Parser no longer crashes on invalid `xuser-*` names.
  - Forensic JSONL logs are emitted to `Winlator/logs/forensics`.
  - Direct diagnostics UI and ADB forensic launch path are available.
  - All WCP builders emit `share/wcp-forensics/*`.

### During

- Implemented parser hardening in `ContainerManager` with canonical naming policy (`xuser-<positive-int-without-leading-zero>`), per-directory exception isolation, duplicate-ID handling, and summary/warning reporting.
- Added forensic logging core (`ForensicLogger`) with:
  - Logcat structured events
  - persistent JSONL sink in `Winlator/logs/forensics/*.jsonl`
  - hash helpers (env/config)
- Added runtime forensic helpers:
  - `ContainerDiscovery`
  - `ContainerNormalizer` (silent **in-memory** normalization, no `.container` auto-write)
  - `ContainerForensicSnapshot`
- Integrated launch trace and route tracing:
  - `XServerDisplayActivity` forensic intent extras (`forensic_mode`, `forensic_trace_id`, `forensic_route_source`, `forensic_skip_playtime`)
  - route/container resolution events
  - runtime drift detection + normalization events
  - launch env snapshot and launcher submit/exit events
- Added `DiagnosticsFragment` + new drawer menu item for:
  - direct forensic XServer launch
  - parser validation summary
  - latest forensic trace summary
- Implemented WCP forensic manifests (always-on) in `ci/lib/wcp_common.sh`:
  - `manifest.json`, `critical-sha256.tsv`, `file-index.txt`, `build-env.txt`, `source-refs.json`
  - validation + smoke checks now require these artifacts
- Wired manifest generation into:
  - `ci/ci-build.sh`
  - `ci/proton-ge10/ci-build-proton-ge10-wcp.sh`
  - `ci/protonwine10/ci-build-protonwine10-wcp.sh`
- Added regression helper scripts:
  - `ci/winlator/forensic-regression-local.sh`
  - `ci/winlator/forensic-adb-matrix.sh`
- Caught and fixed one integration mistake while patching:
  - `wcp_write_forensic_manifest()` was initially inserted inside `compose_wcp_tree_from_stage()` heredoc (function unavailable after `source`); moved it outside and revalidated.

### After

- Shell validation passed:
  - `bash -n` for modified CI scripts ✅
  - `ci/winlator/forensic-regression-local.sh` ✅
  - `wcp_write_forensic_manifest` + `wcp_validate_forensic_manifest` smoke-tested on a synthetic WCP tree ✅
- XML parsing passed for new/changed Android resources (`diagnostics_fragment.xml`, `main_menu.xml`, `strings.xml`) ✅
- Full Gradle Java/resource validation is currently blocked by a pre-existing dirty-tree issue:
  - `app/src/main/res/values/arrays.xml.rej` is picked up by Gradle resource merge and fails the build (`filename must end with .xml`)
  - this is not introduced by the forensic changes
- Additional Java-only compile attempt (skipping resource merge) cannot validate app code because `R` generation is absent, so it fails with expected `cannot find symbol: class R`.
- Attempted to export a new incremental Winlator patch (`0006`) by recreating a temporary patched base (`0001`-`0005`) and diffing forensic files; this is currently blocked because `0005` does not apply cleanly to a fresh local clone of the nested Winlator repo in this environment (`app/build.gradle` hunk drift).
- Next step: revalidate/regenerate `0005` against the current nested Winlator base first, then export the forensic changes as `0006+`.

## 0.2b Release Line Hardening (Contents / Turnip / Release Hygiene)

### Before

- Goal: finish the `0.2b` release line work so the app and WCP packages are coherent end-to-end:
  - `Contents` points to our repo releases,
  - stable vs nightly is explicit,
  - Turnip UX supports version selection/history,
  - workflow/release hygiene is scriptable.
- Risks:
  - `ContentsFragment` was mid-refactor and could regress UI binding or install flow.
  - Remote `ContentInfoDialog` could crash on `null` file lists.
  - Workflow metadata drift (`versionCode/channel/releaseTag`) could make installed WCP metadata inconsistent with `contents.json`.
  - Existing dirty nested tree (`*.rej`) still blocks direct Gradle validation unless isolated.
- Success criteria:
  - App UI correctly presents `Wine/Proton` remote packages from this repo.
  - `contents/contents.json` is validated and channel-aware.
  - Turnip picker/downloader compiles and works in code path.
  - Release/cleanup scripts are present and syntax-checked.

### During

- Completed `Contents` migration to repo-backed source and UI honesty changes:
  - `ContentsManager.REMOTE_PROFILES` now uses this repo `contents/contents.json`.
  - Added metadata parsing (`channel`, `delivery`, `displayCategory`, `sourceRepo`, `releaseTag`) with legacy fallback heuristics.
  - `ContentsFragment` now displays `Wine/Proton`, shows channel/delivery/source lines, and keeps beta/nightly filtering tied to explicit channels.
- Fixed a practical crash risk while reviewing remote package info flow:
  - `ContentInfoDialog` now handles `null` file lists for remote-only entries safely (`Collections.emptyList()`).
- Implemented Turnip version picker UX in `AdrenotoolsFragment`:
  - upstream GitHub releases list, cache (TTL), chooser dialog (latest + recent/history), refresh action, progress download, safe install path reuse.
- Introduced repo-level content index and validation tooling:
  - `contents/contents.json` with stable (`wcp-v0.2b`) and nightly (`wcp-latest`) entries.
  - `ci/contents/validate-contents-json.py` validator.
- Wired WCP metadata parity into CI/build scripts and workflows:
  - `channel/delivery/displayCategory/sourceRepo/releaseTag` injection into `profile.json`.
  - nightly workflows now export `WCP_VERSION_CODE=1`, `WCP_CHANNEL=nightly`, `WCP_RELEASE_TAG=wcp-latest` consistently.
- Added release hygiene/tooling for `0.2b`:
  - cleanup scripts for failed/cancelled workflow runs and legacy releases (dry-run by default).
  - RU/EN release note templates and prepare/publish helper scripts.
  - removed legacy workflow YAMLs (`ci-wine-11.1-wcp`, `ci-proton10-wcp`, `release-proton10-wcp`).
- Bumped Winlator app version line to `0.2b` (`versionCode 21`, `versionName 0.2b`) in the nested source.

### After

- Validation completed for the new `0.2b` contents/release work:
  - `ci/contents/validate-contents-json.py contents/contents.json` ✅
  - `bash -n` for new/changed CI and release scripts ✅
  - XML parse for updated layouts/resources ✅
  - targeted `git diff --check` for modified files ✅
  - clean isolated Gradle compile (`:app:compileDebugJavaWithJavac`) after removing `*.rej` in temp copy ✅
- Residual blockers remain operational, not code-level:
  - GitHub CLI auth is still invalid in current environment (cannot yet delete runs/releases, push, or publish `v0.2b` / `wcp-v0.2b`).
  - Winlator patch export (`0006+`) still depends on first regenerating a cleanly re-applicable `0005` against the current nested base.

## Harvard Continuation (2026-02-28) - Consolidated mainline + active slices (`0001..0010`)

### Before

- Историческая запись выше отражала эпоху pre-consolidation (`0001..0048`) и не покрывала текущий live-стек `0001..0010`.
- Требовалось выровнять:
  - X11-first графический контур,
  - Adrenotools global control plane (Turnip + Upscaler + DX policy),
  - intake/harvest/commit-scan операционный контур,
  - URC/reflective контракты под режим `0001 + 0002..0010`.

### During

- Собран и закреплен текущий slice-стек:
  - `0002` Turnip + глобальная перестройка Adrenotools,
  - `0003` strict `aeturnip` runtime bind + source/install forensic markers,
  - `0004..0010` X11/DXVK/upscaler matrix (DX requested/effective map, Proton FSR DXVK gate, NVAPI/ARM64EC capability envelope, launch packet).
- Добавлен runtime distribution marker:
  - `AERO_RUNTIME_DISTRIBUTION=ae.solator`,
  - проброс в launch graphics packet и launcher forensic submit path.
- Усилен online intake:
  - commit-scan (GH API, no-clone),
  - backlog merge (`focus + commit_scan`),
  - harvest resilience (`repo_errors` model + optional fail gate),
  - branch-pin sync + snapshot audit orchestration.
- Нормализованы policy/gate инструменты:
  - contiguous patch-sequence contract для slice-режима,
  - reflective audit strictness как opt-in (`WLT_REFLECTIVE_AUDIT_STRICT`),
  - final-stage/release-prep/snapshot исключают скрытое дублирование commit-scan/harvest.

### After

- Репозиторий перешел в фактический Harvard-режим:
  - `0001` остается каноническим mainline,
  - `0002..0010` используются как активные review/integration slices без потери контракта.
- Для текущего состояния подтверждены gate-проходы:
  - `validate-patch-sequence`,
  - `check-patch-stack (0001..0010)`,
  - `run-reflective-audits`,
  - `check-urc-mainline-policy`,
  - `run-final-stage-gates` (strict/no-fetch).
- Эта запись фиксирует переход от исторического 0.2b-лога к актуальной operational модели Ae.solator (`X11-first + aeturnip + dxvk/upscaler matrix`).
