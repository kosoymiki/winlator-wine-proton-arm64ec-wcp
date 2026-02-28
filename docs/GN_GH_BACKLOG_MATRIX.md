# GN + GH Unified Backlog Matrix

- Generated (UTC): `2026-02-25 13:36:50`
- Purpose: anti-conflict migration matrix for GameNative + GameHub signals into Ae.solator mainline
- Mainline policy: `bionic-native` + `external-only runtime`

## GameNative branch coverage

- Audited branches: `102`
- Bucket policy:
  - `priority-port`: low-drift branches suitable for direct behavior transfer
  - `selective-review`: moderate-drift branches for scoped transfer
  - `deep-review`: high-impact runtime/graphics/content branches requiring design review
  - `research-only`: high-risk branches kept as evidence, not direct port
  - `already-covered`: branch behavior already represented in default line

| Bucket | Count |
| --- | ---: |
| `priority-port` | 3 |
| `selective-review` | 40 |
| `deep-review` | 14 |
| `research-only` | 45 |
| `already-covered` | 0 |

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

| Risk | Count |
| --- | ---: |
| `low` | 14 |
| `medium` | 34 |
| `high` | 54 |
| `unknown` | 0 |

## Priority migration queue (behavior-level)

| Branch | Topic | Bucket | Ahead | Behind | Files | Portability |
| --- | --- | --- | ---: | ---: | ---: | --- |
| `steam-offline-mode` | `misc` | `priority-port` | 1 | 7 | 22 | `good-cherry-pick-candidate` |
| `gog-other-language-support-utkarsh` | `misc` | `priority-port` | 2 | 8 | 7 | `good-cherry-pick-candidate` |
| `portrait-orientation` | `misc` | `priority-port` | 1 | 42 | 1 | `good-cherry-pick-candidate` |
| `fix/cloud-save-gameinstall-utkarsh` | `content-delivery` | `selective-review` | 5 | 75 | 3 | `selective-cherry-pick` |
| `feat/amazon-games-support-utkarsh` | `misc` | `selective-review` | 112 | 8 | 59 | `selective-cherry-pick` |
| `revert-506-unpack-files` | `misc` | `selective-review` | 1 | 61 | 14 | `selective-cherry-pick` |
| `apply-known-config-on-boot` | `misc` | `selective-review` | 2 | 68 | 2 | `selective-cherry-pick` |
| `feat/steam-achievement` | `misc` | `selective-review` | 4 | 70 | 5 | `selective-cherry-pick` |
| `relative-mouse` | `misc` | `selective-review` | 1 | 72 | 1 | `selective-cherry-pick` |
| `small-fixes-0.7.1` | `bugfix` | `selective-review` | 3 | 75 | 1 | `selective-cherry-pick` |
| `add-deck-emu-to-tu-debug` | `bugfix` | `selective-review` | 1 | 100 | 1 | `selective-cherry-pick` |
| `close-session-after-exit` | `misc` | `selective-review` | 1 | 106 | 1 | `selective-cherry-pick` |
| `Dual-Screen-Support` | `misc` | `selective-review` | 12 | 110 | 20 | `selective-cherry-pick` |
| `dual-screen-support-utkarsh` | `misc` | `selective-review` | 11 | 110 | 20 | `selective-cherry-pick` |
| `test-coldclient` | `misc` | `selective-review` | 2 | 116 | 6 | `selective-cherry-pick` |
| `posthog-remove-duplicate2` | `misc` | `selective-review` | 1 | 120 | 1 | `selective-cherry-pick` |
| `feat/steam-autologin` | `misc` | `selective-review` | 6 | 120 | 11 | `selective-cherry-pick` |
| `posthog-remove-duplicate` | `misc` | `selective-review` | 7 | 120 | 11 | `selective-cherry-pick` |
| `install-mono-wine-version-change` | `release` | `selective-review` | 1 | 122 | 1 | `selective-cherry-pick` |
| `feat/game-manager-utkarsh2` | `misc` | `selective-review` | 7 | 136 | 22 | `selective-cherry-pick` |
| `revert-js` | `misc` | `selective-review` | 1 | 139 | 1 | `selective-cherry-pick` |
| `repair-containers` | `misc` | `selective-review` | 4 | 147 | 12 | `selective-cherry-pick` |
| `feat/game-manager` | `misc` | `selective-review` | 21 | 154 | 15 | `selective-cherry-pick` |
| `feat/game-manager-utkarsh` | `misc` | `selective-review` | 21 | 154 | 15 | `selective-cherry-pick` |
| `revert-368-master` | `misc` | `selective-review` | 1 | 159 | 1 | `selective-cherry-pick` |
| `gog-integration` | `misc` | `selective-review` | 97 | 159 | 69 | `selective-cherry-pick` |
| `steamagent` | `misc` | `selective-review` | 2 | 160 | 7 | `selective-cherry-pick` |
| `check-ufs` | `misc` | `selective-review` | 2 | 178 | 4 | `selective-cherry-pick` |
| `enumerate-extensions-crash` | `bugfix` | `selective-review` | 1 | 179 | 2 | `selective-cherry-pick` |
| `control-editing-minimal` | `misc` | `selective-review` | 5 | 184 | 18 | `selective-cherry-pick` |
| `coderabbitai/docstrings/37c6634` | `misc` | `selective-review` | 1 | 198 | 4 | `selective-cherry-pick` |
| `fix-max-recursion-steam-dlls` | `bugfix` | `selective-review` | 4 | 207 | 3 | `selective-cherry-pick` |
| `coderabbitai/utg/6e57714` | `misc` | `selective-review` | 1 | 222 | 6 | `selective-cherry-pick` |
| `new-wrapper` | `misc` | `selective-review` | 2 | 225 | 10 | `selective-cherry-pick` |
| `wine-import-dropdown` | `misc` | `selective-review` | 27 | 225 | 14 | `selective-cherry-pick` |
| `wine-import-dropdown2` | `misc` | `selective-review` | 43 | 225 | 16 | `selective-cherry-pick` |
| `custom-controller` | `io` | `selective-review` | 7 | 241 | 40 | `selective-cherry-pick` |
| `gbe-experimental-steamclient` | `misc` | `selective-review` | 1 | 294 | 3 | `rebase-first` |
| `update-javasteam-fix-heating` | `bugfix` | `selective-review` | 0 | 333 | 0 | `rebase-first` |
| `jb/fix_depot_arch` | `bugfix` | `selective-review` | 0 | 339 | 0 | `rebase-first` |

## GameHub provenance constraints

| Repo | Classification | Confidence | Rationale |
| --- | --- | --- | --- |
| `gamehublite/gamehub-oss` | `apk-patchset-overlay` | `high` | Repository appears to distribute patch layers over upstream APKs rather than full source ownership. |
| `Producdevity/gamehub-lite` | `apk-patchset-overlay` | `high` | Repository appears to distribute patch layers over upstream APKs rather than full source ownership. |
| `tkashkin/GameHub` | `hybrid-source-and-patch` | `medium` | Repository combines source files with patch/decompile artifacts; selective reuse is required. |

## Conflict arbitration defaults (GN vs GH)

1. Runtime stability and launch determinism > everything else.
2. Mainline external-only policy is non-negotiable.
3. If GN/GH disagree, prefer the path with lower regression risk and explicit forensic observability.
4. Asset-first ideas from external repos stay out of mainline; only behavior contracts are portable.

## Required reflective checkpoints

- Every merged migration item must have a record in `docs/REFLECTIVE_HARVARD_LEDGER.md`.
- Each record must include: hypothesis, evidence, counter-evidence, decision, impact, verification.

