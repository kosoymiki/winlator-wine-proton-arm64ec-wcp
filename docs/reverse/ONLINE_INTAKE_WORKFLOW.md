# Online Intake Workflow

This workflow performs upstream reverse intake in two transport modes:
- `gh` (default): GitHub API mode (no clone, weak-network friendly).
- `git`: targeted shallow clone (`--filter=blob:none`) + selected
  commit/file extraction for deep cycles.

It uses two passes:
- commit-centric (recent commits + touched files),
- tree-wide with raw marker parsing for priority runtime files.

Intake scope modes:
- `focused` (default): only `focus_paths[]` per repo, with tree scan fallback.
- `tree`: full repository tree scan (slower, heavier traffic).

## Scope

- All repos from `ci/reverse/online_intake_repos.json` with
  `enabled_default=true` (mainline deterministic set).
- Current deterministic set includes:
  - Winlator/Wine/Proton lines (`coffin*`, `GameNative`, `GameHub*`),
  - Termux/FEX/Box lanes (`termux-*`, `DesMS`, `cheadrian`, `olegos2`, `Ilya114`, `ahmad1abbadi`),
  - Turnip/Mesa lanes (`StevenMXZ`, `whitebelyash`, `MrPurple666`),
  - MiceWine/Horizon lanes (`KreitinnSoftware/*`, `HorizonEmuTeam`).

## Run

```bash
ci/reverse/online-intake.sh
```

Strict high-priority gate (intake + backlog strict + optional Runtime Contract):

```bash
ci/reverse/run-high-priority-cycle.sh
WLT_HIGH_CYCLE_FETCH=0 ci/reverse/run-high-priority-cycle.sh
WLT_HIGH_CYCLE_PROFILE=core ci/reverse/run-high-priority-cycle.sh
WLT_HIGH_CYCLE_PROFILE=all ci/reverse/run-high-priority-cycle.sh
WLT_HIGH_CYCLE_TRANSPORT=git WLT_HIGH_CYCLE_MODE=full ci/reverse/run-high-priority-cycle.sh
WLT_HIGH_CYCLE_BACKLOG_STRICT=1 ci/reverse/run-high-priority-cycle.sh
WLT_HIGH_CYCLE_ALL_REPOS=1 ci/reverse/run-high-priority-cycle.sh
WLT_HIGH_CYCLE_ALIASES=coffin_wine,gamenative_protonwine ci/reverse/run-high-priority-cycle.sh
WLT_HIGH_CYCLE_REQUIRED_MEDIUM_MARKERS=ContentProfile,REMOTE_PROFILES ci/reverse/run-high-priority-cycle.sh
WLT_HIGH_CYCLE_RUN_COMMIT_SCAN=1 WLT_HIGH_CYCLE_COMMIT_SCAN_PROFILE=core ci/reverse/run-high-priority-cycle.sh
WLT_HIGH_CYCLE_RUN_HARVEST=1 WLT_HIGH_CYCLE_HARVEST_PROFILE=core ci/reverse/run-high-priority-cycle.sh
```

Online commit scan only (GitHub API, no clone):

```bash
ci/reverse/online-commit-scan.sh
ONLINE_COMMIT_SCAN_PROFILE=all ci/reverse/online-commit-scan.sh
ONLINE_COMMIT_SCAN_PROFILE=custom ONLINE_COMMIT_SCAN_ALIASES=coffin_wine,gamenative_protonwine ci/reverse/online-commit-scan.sh
ONLINE_COMMIT_SCAN_COMMITS_PER_REPO=20 ci/reverse/online-commit-scan.sh
```

Targeted sparse-harvest + local transfer (map-driven):

```bash
ci/reverse/harvest-transfer.sh
HARVEST_TRANSFER_PROFILE=core HARVEST_TRANSFER_APPLY=1 ci/reverse/harvest-transfer.sh
HARVEST_TRANSFER_PROFILE=custom HARVEST_TRANSFER_ALIASES=gamenative_protonwine HARVEST_TRANSFER_APPLY=1 ci/reverse/harvest-transfer.sh
HARVEST_TRANSFER_APPLY=0 HARVEST_TRANSFER_MAX_COMMITS_PER_REPO=40 ci/reverse/harvest-transfer.sh
```

Optional flags:

```bash
OUT_DIR=docs/reverse/online-intake LIMIT=40 ci/reverse/online-intake.sh
REPO_FILE=ci/reverse/online_intake_repos.json INCLUDE_ALL_REPOS=1 LIMIT=8 ci/reverse/online-intake.sh
LIMIT=8 MAX_FOCUS_FILES=6 ci/reverse/online-intake.sh
LIMIT=8 MAX_FOCUS_FILES=6 GH_RETRIES=6 GH_RETRY_DELAY_SEC=2.0 ci/reverse/online-intake.sh
ONLINE_INTAKE_MODE=full LIMIT=12 MAX_FOCUS_FILES=8 ci/reverse/online-intake.sh
ONLINE_INTAKE_ALIASES=coffin_wine,gamenative_protonwine ci/reverse/online-intake.sh
ONLINE_INTAKE_TRANSPORT=gh ONLINE_INTAKE_MODE=code-only ci/reverse/online-intake.sh
ONLINE_INTAKE_SCOPE=focused ONLINE_INTAKE_TRANSPORT=gh ONLINE_INTAKE_MODE=code-only ci/reverse/online-intake.sh
ONLINE_INTAKE_TRANSPORT=git ONLINE_INTAKE_MODE=full ONLINE_INTAKE_GIT_DEPTH=120 ci/reverse/online-intake.sh
ONLINE_INTAKE_TRANSPORT=git ONLINE_INTAKE_MODE=full ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC=600 ci/reverse/online-intake.sh
ONLINE_INTAKE_FETCH=0 ci/reverse/online-intake.sh
ONLINE_BACKLOG_STRICT=1 ONLINE_REQUIRED_HIGH_MARKERS=x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION ci/reverse/online-intake.sh
ONLINE_BACKLOG_STRICT=1 ONLINE_REQUIRED_MEDIUM_MARKERS=ContentProfile,REMOTE_PROFILES ci/reverse/online-intake.sh
ONLINE_BACKLOG_STRICT=1 ONLINE_REQUIRED_LOW_MARKERS=DXVK,D8VK,VKD3D,PROOT_TMP_DIR,BOX64_LOG,WINEDEBUG,MESA_VK_WSI_PRESENT_MODE,TU_DEBUG,WINE_OPEN_WITH_ANDROID_BROWSER ci/reverse/online-intake.sh
ONLINE_BACKLOG_STRICT=1 ONLINE_REQUIRE_LOW_READY_VALIDATED=1 ONLINE_REQUIRED_LOW_MARKERS=DXVK,D8VK,VKD3D,PROOT_TMP_DIR,BOX64_LOG,WINEDEBUG,MESA_VK_WSI_PRESENT_MODE,TU_DEBUG,WINE_OPEN_WITH_ANDROID_BROWSER ci/reverse/online-intake.sh
ONLINE_INCLUDE_COMMIT_SCAN=1 ONLINE_COMMIT_SCAN_JSON=docs/reverse/online-intake/commit-scan.json ci/reverse/online-intake.sh
ONLINE_INCLUDE_COMMIT_SCAN=1 ONLINE_COMMIT_SCAN_AUTO=1 ONLINE_COMMIT_SCAN_PROFILE=all ci/reverse/online-intake.sh
ONLINE_RUN_HARVEST=1 ONLINE_HARVEST_PROFILE=core ci/reverse/online-intake.sh
ONLINE_RUN_HARVEST=1 ONLINE_SYNC_BRANCH_PINS=1 ONLINE_RUN_SNAPSHOT_AUDIT=1 ci/reverse/online-intake.sh
```

Default network-thrifty settings:
- `LIMIT=8`
- `MAX_FOCUS_FILES=6`
- `GH_RETRIES=4`
- `GH_RETRY_DELAY_SEC=1.5`
- `ONLINE_INTAKE_MODE=code-only` (`full` includes commit-diff scan)
- `ONLINE_INTAKE_SCOPE=focused` (`tree` scans the whole repo tree)
- `ONLINE_INTAKE_TRANSPORT=gh` (`git` available for deep fetch fallback)
- `ONLINE_INTAKE_GIT_WORKDIR=docs/reverse/online-intake/_git-cache`
- `ONLINE_INTAKE_GIT_DEPTH=80`
- `ONLINE_INTAKE_CMD_TIMEOUT_SEC=120`
- `ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC=420`
- `ONLINE_INTAKE_FETCH=1` (`0` = skip network fetch, rebuild backlog from existing combined matrix only)
- `ONLINE_BACKLOG_STRICT=0` (`1` = fail when high-priority backlog rows remain `needs_review`)
- `ONLINE_REQUIRED_HIGH_MARKERS` = required high-priority marker list for strict gate
  (default: `x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION`)
- `ONLINE_REQUIRED_MEDIUM_MARKERS` = required medium-priority marker list for strict gate
  (default: `ContentProfile,REMOTE_PROFILES`)
- `ONLINE_REQUIRED_LOW_MARKERS` = low-priority marker list for strict gate
  (default: `DXVK,D8VK,VKD3D,PROOT_TMP_DIR,BOX64_LOG,WINEDEBUG,MESA_VK_WSI_PRESENT_MODE,TU_DEBUG,WINE_OPEN_WITH_ANDROID_BROWSER`)
- `ONLINE_REQUIRE_LOW_READY_VALIDATED` = `0|1` (default `1`) to enforce ready-validated status for low-priority markers in strict mode
- `ONLINE_INCLUDE_COMMIT_SCAN` = `0|1` (default `1`) to merge commit-level marker hits into backlog rows.
- `ONLINE_COMMIT_SCAN_AUTO` = `0|1` (default `1`) to refresh commit-scan before backlog build
  when intake fetch is enabled or commit-scan file is missing.
- `ONLINE_COMMIT_SCAN_PROFILE` = `core|all|custom`; defaults to `all` when
  `INCLUDE_ALL_REPOS=1`, to `custom` when aliases are set, otherwise `core`.
- `ONLINE_COMMIT_SCAN_COMMITS_PER_REPO` = number of recent commits fetched per repo (default `12`).
- `ONLINE_COMMIT_SCAN_JSON` = commit-scan source file (default `${OUT_DIR}/commit-scan.json`).
- `ONLINE_RUN_HARVEST` = `0|1` (default `0`) enables sparse harvest+transfer after backlog gate.
- `ONLINE_HARVEST_PROFILE` = `core|all|custom`; defaults follow the same
  rule as commit-scan profile (`all` for all repos, `custom` for aliases, else `core`).
- `ONLINE_HARVEST_MAX_COMMITS_PER_REPO` = commit depth for harvest correlation (default `24`).
- `ONLINE_HARVEST_APPLY` = `0|1` (default `1`) controls whether transfer map sync writes to tree.
- `ONLINE_HARVEST_SKIP_NO_SYNC` = `0|1` (default `1`) skips repos with no sync rules in apply mode.
- `ONLINE_HARVEST_AUTO_FOCUS_SYNC` = `0|1` (default `1`) auto-creates snapshot sync rules from `focus_paths[]`.
- `ONLINE_HARVEST_INCLUDE_UNMAPPED` = `0|1` (default `1`) includes enabled repos absent in transfer map.
- `ONLINE_HARVEST_FAIL_ON_REPO_ERRORS` = `0|1` (default `0`) controls per-repo failure handling.
- `ONLINE_HARVEST_OUT_DIR` = output directory for harvest artifacts (default `${OUT_DIR}/harvest`).
- `ONLINE_SYNC_BRANCH_PINS` = `0|1` (default `1`) refreshes `online_intake_repos.json` branches from harvest.
- `ONLINE_RUN_SNAPSHOT_AUDIT` = `0|1` (default `1`) runs snapshot contract audit when harvest is enabled.
- `ONLINE_SNAPSHOT_AUDIT_STRICT` = `0|1` (default `1`) strict mode for snapshot audit gate.

## Outputs

- `docs/reverse/online-intake/combined-matrix.md`
- `docs/reverse/online-intake/combined-matrix.json`
- `docs/reverse/online-intake/PATCH_TRANSFER_BACKLOG.md`
- `docs/reverse/online-intake/PATCH_TRANSFER_BACKLOG.json`
- per-repo reports (`*.md`, `*.json`)
- tree-wide category distribution and focus-marker extraction in per-repo `*.md`
- combined matrix includes per-repo snapshot bullets (branch, commit window, category mix)
  and cross-source marker heat (runtime marker overlap)
- branch resolution is resilient: if configured branch is stale, intake falls back
  to upstream default/main/master and records requested vs effective branch.
- per-repo reports include marker code snippets (line + code) for direct code-level review.
- backlog file is generated from marker overlap and maps high-signal markers to
  patch targets in the current tree.
- backlog rows include a `status` field (`ready`, `ready_validated`, `needs_review`, `missing_target`)
  based on local tree state to avoid conflict-prone transfers.
- backlog rows include `Focus/Commits` hit split so marker pressure from file parse vs commit deltas stays explicit.
- backlog rows also include evidence pointers (`repo:path:line` + snippet) so
  patch decisions can be reviewed directly against parsed code lines.
- evidence rows are tagged by source (`focus` or `commit_scan`).
- `ci/reverse/check-online-backlog.py` validates high-priority backlog rows and
  fails when a mapped target is missing.
- with `ONLINE_BACKLOG_STRICT=1`, backlog check also fails on any intake error
  count in `PATCH_TRANSFER_BACKLOG.json`.
- with `ONLINE_BACKLOG_STRICT=1`, all high-priority rows must be `ready_validated`
  (not only `ready`).
- with `ONLINE_BACKLOG_STRICT=1`, all medium-priority rows must also be
  `ready_validated`.
- with `ONLINE_BACKLOG_STRICT=1` and `ONLINE_INCLUDE_COMMIT_SCAN=1`, backlog
  check fails when `commit_scan_errors > 0`.
- with `ONLINE_BACKLOG_STRICT=1`, all markers from
  `ONLINE_REQUIRED_HIGH_MARKERS` must exist as high-priority rows.
- with `ONLINE_BACKLOG_STRICT=1`, all markers from
  `ONLINE_REQUIRED_MEDIUM_MARKERS` must exist as medium-priority rows.
- with `ONLINE_BACKLOG_STRICT=1` and `ONLINE_REQUIRE_LOW_READY_VALIDATED=1`,
  all low-priority rows must be `ready_validated`.
- with `ONLINE_BACKLOG_STRICT=1`, all markers from
  `ONLINE_REQUIRED_LOW_MARKERS` must exist as low-priority rows.
- `run-high-priority-cycle.sh` supports profiles:
  - `all` (default): all enabled repos.
  - `core`: targeted aliases for high-signal runtime markers (Winlator/Wine/Proton + wine-tkg + Box/FEX/Termux bridge lanes).
  - `custom`: use explicit `WLT_HIGH_CYCLE_ALIASES`.
  - In `all` profile, alias filters are intentionally ignored to keep intake deterministic.
  - In `custom` profile, `WLT_HIGH_CYCLE_ALIASES` is required.
  - Optional commit-level scan can be enabled with `WLT_HIGH_CYCLE_RUN_COMMIT_SCAN=1`.
  - Optional sparse harvest+transfer can be enabled with `WLT_HIGH_CYCLE_RUN_HARVEST=1`.
  - Optional snapshot contract audit can be enabled with
    `WLT_HIGH_CYCLE_RUN_SNAPSHOT_AUDIT=1` (strict mode by default).
- `online-commit-scan.sh` supports profiles:
  - `core` (default): high-signal repos for runtime and wrapper deltas.
    Includes `froggingfamily_wine_tkg_git` for DXVK/VKD3D/Proton-FSR policy deltas.
  - `all`: all enabled repos from `online_intake_repos.json`.
  - `custom`: explicit alias list via `ONLINE_COMMIT_SCAN_ALIASES`.
- `harvest-transfer.sh` supports profiles:
  - `core` (default): transfer-focused aliases (`gamenative_protonwine`, `coffin_wine`, `coffin_winlator`).
  - `all`: all enabled aliases from `transfer_map.json`.
  - `custom`: explicit aliases via `HARVEST_TRANSFER_ALIASES`.
  - transfer behavior is controlled by `HARVEST_TRANSFER_APPLY=0|1`.
  - path mapping and sync policy live in `ci/reverse/transfer_map.json`.
  - `HARVEST_TRANSFER_AUTO_FOCUS_SYNC=1` auto-creates snapshot sync rules from
    repo `focus_paths[]` when explicit `sync_rules` are absent.
  - `HARVEST_TRANSFER_INCLUDE_UNMAPPED=1` includes enabled repos from
    `online_intake_repos.json` that are not listed in `transfer_map.json`.
  - `HARVEST_TRANSFER_FAIL_ON_REPO_ERRORS=0|1` controls whether harvest exits
    non-zero on per-repo failures (default `0` for long resilient cycles).
  - auto-synced focus snapshots are written under `ci/reverse/upstream_snapshots/`.
  - branch pins can be refreshed from harvest output via
    `ci/reverse/sync-repo-branches-from-harvest.py`.

Repo scope is configured by `ci/reverse/online_intake_repos.json`:
- `enabled_default=true` entries are scanned by default.
- current mainline contract requires every configured repo to keep
  `enabled_default=true` (single deterministic intake surface).
- `INCLUDE_ALL_REPOS=1` remains supported for compatibility.
- `combined-matrix.json` stores both `reports` and `errors` so one failing
  upstream does not break the full intake cycle.
- if a repo fetch fails but previous `*.json` exists, intake keeps a stale-cache
  report for that alias and marks it in markdown/json output.
- `MAX_FOCUS_FILES` limits per-repo raw file-marker fetches to reduce network load.
- `commit-scan.md` / `commit-scan.json` capture recent commit-level marker touches
  (`files + first-line message + marker list`) without cloning upstream sources.
  Default marker set now includes DX/upscaler contract keys:
  `DXVK`, `VKD3D`, `D8VK`, `DXVK_NVAPI`, `WINE_FULLSCREEN_FSR*`, `VKBASALT_CONFIG`.
- with `ONLINE_COMMIT_SCAN_AUTO=1`, commit-scan is auto-regenerated before backlog
  generation when intake fetch is enabled (or commit-scan is missing).
- `PATCH_TRANSFER_BACKLOG.json` includes `commit_scan_used` and `commit_scan_errors`
  metadata for strict gating/reporting.
- with `ONLINE_INTAKE_FETCH=0`, if `${OUT_DIR}/combined-matrix.json` is absent,
  the script seeds it from `docs/reverse/online-intake/combined-matrix.json`.
- `focus_paths[]` and `pinned_commits[]` can be added per repo in
  `ci/reverse/online_intake_repos.json` for deterministic targeted intake.
- with `ONLINE_RUN_HARVEST=1`, intake also runs map-driven transfer, optional
  branch pin sync (`sync-repo-branches-from-harvest.py`), and optional snapshot audit.

## Intended use

- identify high-churn hotspots before patch transfer
- prioritize runtime-critical deltas (`arm64ec_core`, launcher, container flow)
- keep risky `HACK`/revert paths gated before mainline promotion
