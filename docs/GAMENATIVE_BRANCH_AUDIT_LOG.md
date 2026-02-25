# GameNative Branch Audit Log

- Generated (UTC): `2026-02-25 13:06:31`
- Source repo: `utkarshdalal/GameNative`
- Default branch: `master`
- Branches audited: `102`
- PR sample size: `120`

## Branch risk distribution

| Risk | Count |
| --- | ---: |
| `high` | 54 |
| `medium` | 34 |
| `low` | 14 |
| `unknown` | 0 |

## Branch topics

| Topic | Count |
| --- | ---: |
| `misc` | 56 |
| `bugfix` | 20 |
| `runtime` | 8 |
| `io` | 7 |
| `content-delivery` | 6 |
| `ui` | 3 |
| `graphics` | 1 |
| `release` | 1 |

## Candidate branches for selective backport

| Branch | Topic | Ahead | Behind | Files | Portability |
| --- | --- | ---: | ---: | ---: | --- |
| `steam-offline-mode` | `misc` | 1 | 7 | 22 | `good-cherry-pick-candidate` |
| `gog-other-language-support-utkarsh` | `misc` | 2 | 8 | 7 | `good-cherry-pick-candidate` |
| `portrait-orientation` | `misc` | 1 | 42 | 1 | `good-cherry-pick-candidate` |

## High-risk branches (manual study first)

| Branch | Status | Ahead | Behind | Files | Topic |
| --- | --- | ---: | ---: | ---: | --- |
| `add-glibc-change-targetsdk` | `diverged` | 378 | 1130 | 300 | `runtime` |
| `glibc-attempt-4` | `diverged` | 379 | 1130 | 300 | `runtime` |
| `glibc-attempt-5` | `diverged` | 379 | 1130 | 300 | `runtime` |
| `add-drm-flag` | `diverged` | 1 | 772 | 10 | `misc` |
| `drm-checks` | `diverged` | 5 | 772 | 6 | `misc` |
| `fix-drm-protected-games` | `behind` | 0 | 770 | 0 | `bugfix` |
| `update-winlator-add-libraries` | `behind` | 0 | 765 | 0 | `misc` |
| `winlator-cmod` | `diverged` | 1 | 764 | 189 | `misc` |
| `winlator-cmod-2` | `diverged` | 2 | 764 | 31 | `misc` |
| `glibc-attempt-3` | `diverged` | 386 | 760 | 130 | `runtime` |
| `add-controller-and-keyboard` | `behind` | 0 | 739 | 0 | `io` |
| `new-wine` | `behind` | 0 | 736 | 0 | `misc` |
| `rename-app` | `diverged` | 1 | 727 | 19 | `misc` |
| `usability-fixes` | `behind` | 0 | 727 | 0 | `bugfix` |
| `enable-logging` | `behind` | 0 | 715 | 0 | `misc` |
| `fix-dinput` | `diverged` | 1 | 673 | 1 | `io` |
| `fix-dinput-again` | `diverged` | 1 | 672 | 7 | `io` |
| `pull-in-pluvia-changes` | `diverged` | 1 | 662 | 5 | `misc` |
| `ui-fixes` | `behind` | 0 | 657 | 0 | `ui` |
| `more-warmup-fixes` | `behind` | 0 | 652 | 0 | `bugfix` |
| `update-vortek-fix-audio` | `diverged` | 1 | 648 | 9 | `io` |
| `revert-64-fix-sign-in` | `diverged` | 1 | 639 | 3 | `bugfix` |
| `fix-sign-in` | `behind` | 0 | 639 | 0 | `bugfix` |
| `fix-downloads-2` | `diverged` | 4 | 630 | 11 | `content-delivery` |
| `new_vortek_winlator` | `diverged` | 4 | 626 | 98 | `misc` |
| `allow-choosing-sd-card` | `diverged` | 1 | 623 | 3 | `misc` |
| `new_vortek` | `diverged` | 10 | 616 | 19 | `misc` |
| `attempt-real-steam` | `diverged` | 3 | 616 | 12 | `misc` |
| `game-debugging` | `behind` | 0 | 613 | 0 | `bugfix` |
| `99` | `diverged` | 17 | 604 | 7 | `misc` |

## Recent PR snapshot

| PR | State | Updated | Branch | Title |
| ---: | --- | --- | --- | --- |
| 648 | `open` | `2026-02-25` | `jb/dedup-network-check` | refactor: deduplicate network connectivity checks |
| 649 | `open` | `2026-02-25` | `config-export-for-all-platforms` | Added container config export for all platforms |
| 591 | `open` | `2026-02-25` | `feat/ui-ux-overhaul` | feat: ui/ux overhaul from ObfuscatedVoid & Phobos + remaining merge conflict resolutions |
| 638 | `open` | `2026-02-25` | `moonlighter-dep-fix` | Gamefix: Added correct redist launch dep for Moonlighter |
| 637 | `open` | `2026-02-25` | `remove-unused-bitness-depot-filter` | Remove unnecessary bitness depot filter |
| 624 | `open` | `2026-02-25` | `gog-partial-downloads-support` | Added fix for not showing partial downloads for GOG |
| 569 | `open` | `2026-02-25` | `streamlined-launch-dependencies-flow` | Streamlined launch dependencies retrieval flow |
| 639 | `open` | `2026-02-25` | `vredist-launch-dependency` | Added vredist launch dependency (need help getting this to auto-install) |
| 627 | `closed` | `2026-02-25` | `gog-other-language-support` | Use container language for GOG downloads |
| 635 | `closed` | `2026-02-25` | `jb/offline-image-cache` | fix: serve cached images when device has no internet |
| 626 | `closed` | `2026-02-25` | `jb/pointer-capture` | fix: capture external mouse pointer on first event |
| 599 | `open` | `2026-02-25` | `feature/control-editor-improvements` | Control editor improvements, touchpad gestures, and new default presets |
| 646 | `closed` | `2026-02-25` | `fix-l2-r2-axis` | Fix L2/R2 being triggered as buttons instead of axis |
| 645 | `closed` | `2026-02-25` | `steam-offline-mode` | Added steam offline mode for games like N++ |
| 643 | `closed` | `2026-02-25` | `jb/async-job-retry` | fix: retry cloud sync on AsyncJobFailedException |
| 623 | `open` | `2026-02-24` | `jb/navbar-insets` | fix: library content hidden behind soft navigation bar |
| 629 | `closed` | `2026-02-24` | `jb/query_bool` | fix: replace boolean literals with 0/1 in Room queries |
| 557 | `closed` | `2026-02-24` | `feat/amazon-games-support` | Feat/amazon games support |
| 338 | `open` | `2026-02-24` | `d7vk-support` | D7vk support |
| 581 | `closed` | `2026-02-24` | `jb/guard-missing-wine-image` | fix: auto-download missing wine/proton on first launch |
| 604 | `open` | `2026-02-24` | `fix/resume-state` | fix: allow state and page to resume on app refocus instead of rerouting to login and library |
| 612 | `closed` | `2026-02-24` | `fix/kb-wake-bug` | fix: prevent IME keyboard from invoke on thor 2nd screen when waking from sleep |
| 614 | `closed` | `2026-02-24` | `script-interpreter` | Added GOG Script interpreter and run it when the manifest says so |
| 608 | `closed` | `2026-02-24` | `additional-game-fixes` | Additional game registry fixes |

## Notes

- This report is generated via GitHub API and should be treated as triage, not as an auto-merge list.
- Branches with large behind/ahead deltas require manual semantic review before porting.
- For Winlator CMOD, prioritize runtime/content-delivery branches with low drift first.
