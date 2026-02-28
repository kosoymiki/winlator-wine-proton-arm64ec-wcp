# Content Packages Architecture (Ae.solator)

## Goal
`Contents` in Ae.solator must clearly separate:
- local installed packages,
- downloadable packages,
- stable vs beta/nightly channels,
without implying that our Wine/Proton packages are embedded inside the APK.

## Source of truth
- Repository file: `contents/contents.json`
- Runtime URL in app: `raw.githubusercontent.com/<repo>/main/contents/contents.json`
- Package assets: GitHub Releases of this repository (`wcp-stable` + per-package rolling `*-latest` tags)

## Entry model (extended, backward-compatible)
Required legacy fields still supported:
- `type`, `verName`, `verCode`, `remoteUrl`

New/extended fields used by this fork:
- `channel`: `stable | beta | nightly` (primary visibility filter)
- `delivery`: `remote | embedded` (UI honesty; current WCP entries use `remote`)
- `internalType`: Wine-family subtype (`wine | proton | protonge | protonwine`) while keeping `type=Wine` for compatibility
- `displayCategory`: UI label override (we use `Wine/Proton`)
- `sourceRepo`: provenance (`owner/repo`)
- `releaseTag`: release source (`wcp-stable` or per-package rolling tag like `wine-11-arm64ec-latest`)

## Filtering policy
1. Stable entries are always visible.
2. `Show beta / nightly` toggle controls `beta` and `nightly` entries.
3. Legacy entries without `channel` use fallback heuristics (`beta/nightly` in metadata/URL).

## Type and display mapping
- Internal content type remains `Wine` for compatibility with Winlator internals.
- Wine-family subtypes are carried by `internalType` for deterministic package identity (`wine/protonge/protonwine`) without fragmenting the main UI group.
- UI display label maps `Wine` entries to `Wine/Proton`.
- This avoids breaking existing parsing while keeping the UI accurate.

## Turnip vs Contents
- Turnip driver downloads remain upstream-sourced and are handled by `Adrenotools`.
- Wine/Proton content packages are distributed from this repo releases and surfaced through `Contents`.

## Graphics translation payload families

Contents metadata and release notes should keep naming consistent for these
external payload families:

- `DXVK`
- `VKD3D`
- `D8VK`

## Packaging metadata propagation
WCP build scripts inject the same metadata into `profile.json` (`channel`, `delivery`, `displayCategory`, `sourceRepo`, `releaseTag`) so installed packages retain provenance and channel info.
