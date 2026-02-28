# External Signal Contract

## Scope

This contract defines how Ae.solator mainline accepts and resolves
runtime signals imported from external lanes (GameNative, GameHub, Termux/FEX,
legacy wrapper ecosystems).

## Invariants

1. Mainline behavior remains `external-only` for runtime payloads (FEX/Box/WoWBox, driver bundles).
2. A signal may change policy defaults, but may not introduce bundled fallback archives.
3. Every accepted signal must be observable via deterministic env markers and forensic events.
4. Policy arbitration must be deterministic for equal inputs.

## Decision Order

Signals are processed in this priority order:

1. Safety contract (launch integrity, runtime class validity, known crash guards)
2. Runtime compatibility contract (bionic/native target, external resolver contract)
3. Performance hints (preset overlays, tuning knobs)
4. UX hints (labels, grouping, defaults)

Higher-priority layers can override lower-priority signals; lower layers cannot weaken safety.

## Required Markers

When a signal changes effective runtime policy, launcher flow must emit:

- `WINLATOR_SIGNAL_POLICY`
- `WINLATOR_SIGNAL_SOURCES`
- `WINLATOR_SIGNAL_DECISION_HASH`
- `WINLATOR_SIGNAL_DECISION_COUNT`

Before launcher submit, precheck input envelope must be exported as:

- `WINLATOR_SIGNAL_INPUT_ROUTE`
- `WINLATOR_SIGNAL_INPUT_LAUNCH_KIND`
- `WINLATOR_SIGNAL_INPUT_TARGET_EXECUTABLE`
- `WINLATOR_SIGNAL_INPUT_PRECHECK_REASON`
- `WINLATOR_SIGNAL_INPUT_PRECHECK_FALLBACK`

When Termux/proot-based external lanes are active, signal evidence should also
capture:

- `PROOT_TMP_DIR`

## Rollback Rule

Any signal causing regressions in launch stability or container creation is
moved to research lane and disabled from mainline until validated by CI and
forensic replay.
