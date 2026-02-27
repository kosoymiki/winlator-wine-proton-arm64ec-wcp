# Online Intake Workflow (No Source Clone)

This workflow performs upstream reverse intake using GitHub API only.
It does not clone source repositories.

## Scope

- `coffincolors/winlator` (`cmod_bionic`)
- `coffincolors/wine` (`arm64ec`)
- `GameNative/proton-wine` (`proton_10.0`)

## Run

```bash
ci/reverse/online-intake.sh
```

Optional flags:

```bash
OUT_DIR=docs/reverse/online-intake LIMIT=40 ci/reverse/online-intake.sh
```

## Outputs

- `docs/reverse/online-intake/combined-matrix.md`
- `docs/reverse/online-intake/combined-matrix.json`
- per-repo reports (`*.md`, `*.json`)

## Intended use

- identify high-churn hotspots before patch transfer
- prioritize runtime-critical deltas (`arm64ec_core`, launcher, container flow)
- keep risky `HACK`/revert paths gated before mainline promotion
