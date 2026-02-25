# Winlator External Runtime Components (Mainline Contract)

## Scope

This repository builds `Wine/Proton` WCP packages for Winlator.  
Mainline policy is **bionic-native + external runtime components**.

## Components Winlator pulls externally

Winlator installs and updates these outside Wine/Proton WCP:

- `FEXCore` runtime payload (`libarm64ecfex.dll`, `libwow64fex.dll`, `fexcore/*`)
- `Box64/WoWBox64` runtime payload
- `DXVK` and `VKD3D` payload folders
- Vulkan driver/layer packs handled by Adrenotools (`share/vulkan/*` class payloads)

Wine/Proton WCP must stay focused on:

- `bin/` launchers
- `lib/wine/*` runtime modules
- `prefixPack.txz`
- `profile.json`
- forensic metadata (`share/wcp-forensics/*`)

## Enforcement in CI/builders

Mainline builders now enforce:

- `WCP_MAINLINE_FEX_EXTERNAL_ONLY=1`
- `WCP_PRUNE_EXTERNAL_COMPONENTS=1`
- `WCP_INCLUDE_FEX_DLLS=0`
- `WCP_FEX_EXPECTATION_MODE=external`

And they prune external payload paths from WCP trees before packaging.

## Forensics and validation

Each WCP now includes:

- `share/wcp-forensics/external-runtime-components.tsv`

The file is a path-level audit (`category`, `path`, `present`) used to confirm external component separation and detect regressions quickly.
