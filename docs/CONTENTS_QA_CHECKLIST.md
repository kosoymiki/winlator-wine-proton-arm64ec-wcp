# Contents QA Checklist

## Static Contract Gate (No Device Required)
- `python3 ci/validation/check-contents-qa-contract.py --root . --output /tmp/contents-qa-contract.md`
- `WLT_WCP_PARITY_REQUIRE_ANY=1 WLT_WCP_PARITY_FAIL_ON_MISSING=1 bash ci/validation/run-wcp-parity-suite.sh`
- `WLT_RELEASE_PREP_RUN_COMMIT_SCAN=0 WLT_RELEASE_PREP_RUN_HARVEST=0 WLT_RELEASE_PREP_RUN_PATCH_BASE=0 bash ci/validation/prepare-release-patch-base.sh`
- This gate validates repository-side invariants for:
  `contents/contents.json`, `artifact-source-map.json`, patch contract tokens in
  `0001-mainline-full-stack-consolidated.patch`, and WCP workflow metadata
  (`WCP_VERSION_CODE/WCP_CHANNEL/WCP_DELIVERY/WCP_DISPLAY_CATEGORY/WCP_RELEASE_TAG`).
- Parity suite validates binary payload parity for configured source/install pairs in
  `ci/validation/wcp-parity-pairs.tsv` (critical path coverage + missing/extra/drift report).

## Contents source and schema
- [x] `ContentsManager.REMOTE_WINE_PROTON_OVERLAY` points to this repo `contents/contents.json`
- [x] `ContentsManager.REMOTE_PROFILES` remains WCP Hub source (`pack.json`) for non-Wine packages
- [x] `ci/contents/validate-contents-json.py contents/contents.json` passes
- [x] Each `Wine/Proton` entry points to its per-package rolling tag (`*-latest`) in overlay
- [x] Stable bundle release flow keeps `wcp-stable` publish lane in `ci/release/publish-0.9c.sh`
- [x] `channel`, `delivery`, `displayCategory`, `sourceRepo`, `releaseTag` are present
- [x] Wine-family entries carry `internalType` (`wine|proton|protonge|protonwine`) while `type` stays `Wine`

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
- [x] `wine-11` nightly build emits `channel=nightly`, `releaseTag=wine-11-arm64ec-latest`, `versionCode=1`
- [x] `proton-ge10` nightly build emits same metadata policy
- [x] `protonwine10` nightly build emits same metadata policy
- [x] Stable release flow keeps `channel=stable` messaging and `wcp-stable` publish tag
