# Contents QA Checklist (0.2b)

## Contents source and schema
- [ ] `ContentsManager.REMOTE_PROFILES` points to this repo `contents/contents.json`
- [ ] `ci/contents/validate-contents-json.py contents/contents.json` passes
- [ ] Each `Wine/Proton` stable entry points to `wcp-v0.2b`
- [ ] Each `Wine/Proton` entry points to its per-package rolling tag (`*-latest`)
- [ ] `channel`, `delivery`, `displayCategory`, `sourceRepo`, `releaseTag` are present

## Winlator UI behavior
- [ ] Spinner/category shows `Wine/Proton` (not just `Wine`) for package entries
- [ ] Stable packages are visible with beta toggle OFF
- [ ] Nightly/beta packages are hidden with beta toggle OFF
- [ ] Nightly/beta packages appear with beta toggle ON
- [ ] Rows show source/provenance line for remote packages (repo + release tag)
- [ ] UI does not imply packages are embedded in APK

## Install/update paths
- [ ] Downloading a remote WCP from `Contents` installs successfully
- [ ] Installed package moves from download action to local menu action
- [ ] Duplicate install is rejected cleanly (`content already exist`)
- [ ] Removing an installed `Wine/Proton` package fails safely if a container uses it

## Turnip / Adrenotools UX
- [ ] Version picker opens (latest + recent/history entries)
- [ ] Refresh reloads release list
- [ ] Selected Turnip ZIP downloads with progress and installs
- [ ] Installed driver list refreshes without duplicates
- [ ] Network/API failures show user-readable error messages

## CI/WCP metadata parity
- [ ] `wine-11` nightly build emits `channel=nightly`, `releaseTag=wine-11-arm64ec-latest`, `versionCode=1`
- [ ] `proton-ge10` nightly build emits same metadata policy
- [ ] `protonwine10` nightly build emits same metadata policy
- [ ] Stable release builds emit `channel=stable` and `releaseTag=wcp-v0.2b`
