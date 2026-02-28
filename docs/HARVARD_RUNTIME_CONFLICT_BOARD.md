# Harvard Runtime Conflict Board (Trello Style)

## Scope

This board is the operational source-of-truth for runtime conflict work across:

- `wine`
- `proton`
- `ae.solator` distribution markers
- `turnip` bind path
- `adrenotools` policy/control-plane
- `vkd3d`
- `dxvk`
- loader/wrapper/layout path (`WINEDLLOVERRIDES`, DX wrappers)

Use this board for handoff between agents and for continuous backlog intake.

## Board Rules (Required)

1. Every new runtime conflict task starts in `Inbox`.
2. When started, move task to `Doing` and add owner/date.
3. On validation pass, move to `Done` with evidence commands.
4. Keep `Ready` as prioritized next queue (max 7 cards).
5. Do not delete historical done cards; append newer cards.
6. Card flow is strict: Inbox -> Ready -> Doing -> Done.

## Execution Report Snapshot (as of 2026-02-28)

### What Was Implemented

- Runtime conflict contour added to launch path in `patch 0010`:
  - `AERO_LIBRARY_CONFLICTS`
  - `AERO_LIBRARY_CONFLICT_COUNT`
  - `AERO_LIBRARY_CONFLICT_SHA256`
  - `AERO_LIBRARY_REPRO_ID`
- Forensic events added:
  - `RUNTIME_LIBRARY_CONFLICT_SNAPSHOT`
  - `RUNTIME_LIBRARY_CONFLICT_DETECTED`
- Launch packet + runtime matrix enriched with conflict fingerprint (`count + sha`).
- URC contract checks updated for new markers/events:
  - `ci/validation/check-urc-mainline-policy.sh`
  - `docs/UNIFIED_RUNTIME_CONTRACT.md`
- ADB forensic orchestration now runs strict conflict contour analysis:
  - `ci/winlator/forensic-runtime-conflict-contour.py`
  - `ci/winlator/forensic-adb-runtime-contract.sh`
  - `ci/winlator/forensic-adb-harvard-suite.sh`
- Multi-agent handoff wiring added:
  - `README.md` diagnostics section
  - `docs/README.md` active ops index
  - `AGENTS.md` runtime board protocol

### Validation Evidence (latest run)

- `bash ci/winlator/validate-patch-sequence.sh ci/winlator/patches`
- `WINLATOR_PATCH_FROM=0001 WINLATOR_PATCH_TO=0010 bash ci/winlator/check-patch-stack.sh <winlator-src>`
- `bash ci/winlator/run-reflective-audits.sh`
- `bash ci/validation/check-urc-mainline-policy.sh`

---

## Done

- [x] `RC-001` X11-first DX/upscaler matrix across `0004..0010`.
  - Result: deterministic DX requested/effective map and launch packet.
  - Evidence: `check-patch-stack 0001..0010`, `run-reflective-audits`, `check-urc-mainline-policy`.

- [x] `RC-002` DXVK capability envelope + Proton FSR gate + ARM64EC NVAPI gate.
  - Result: `AERO_DXVK_CAPS`, `AERO_DXVK_NVAPI_*`, `AERO_UPSCALE_PROTON_FSR_REASON`.
  - Evidence: patch `0010`, URC contract checks.

- [x] `RC-003` Runtime flavor/distribution markers.
  - Result: `AERO_RUNTIME_FLAVOR`, `AERO_RUNTIME_DISTRIBUTION=ae.solator`, `AERO_WINE_ARCH`.
  - Evidence: launch packet + launcher forensic payload.

- [x] `RC-004` Runtime library conflict snapshot contour (reproducible).
  - Result: `AERO_LIBRARY_CONFLICTS/COUNT/SHA256/REPRO_ID` + events:
    `RUNTIME_LIBRARY_CONFLICT_SNAPSHOT`, `RUNTIME_LIBRARY_CONFLICT_DETECTED`.
  - Evidence: patch `0010`, URC check pass.

- [x] `RC-013` Multi-agent board wiring into required docs/policy checks.
  - Result: board linked from `README.md` + `docs/README.md`, and enforced by `check-urc-mainline-policy.sh`; agent protocol pinned in `AGENTS.md`.
  - Evidence: `bash ci/validation/check-urc-mainline-policy.sh`.

- [x] `RC-014` Reproducible per-library self-log channel for loader conflicts.
  - Result: strict subsystem envelope + component stream markers (`AERO_RUNTIME_SUBSYSTEMS*`, `AERO_LIBRARY_COMPONENT_STREAM*`, `AERO_RUNTIME_LOGGING_*`) with conflict-grade events and launcher propagation.
  - Evidence: `WINLATOR_PATCH_FROM=0001 WINLATOR_PATCH_TO=0010 bash ci/winlator/check-patch-stack.sh <winlator-src>`, `bash ci/validation/check-urc-mainline-policy.sh`.

- [x] `RC-015` Cross-base subsystem logging parity audit.
  - Result: strict logging markers/events enforced across patch-base window `0001..0010`, with URC + final-stage strict gates passing.
  - Evidence: `WINLATOR_PATCH_FROM=0001 WINLATOR_PATCH_TO=0010 bash ci/winlator/check-patch-stack.sh <winlator-src>`, `bash ci/validation/check-urc-mainline-policy.sh`, `WLT_FINAL_STAGE_FETCH=0 WLT_FINAL_STAGE_SCOPE=focused WLT_FINAL_STAGE_FAIL_MODE=strict WLT_FINAL_STAGE_RUN_RELEASE_PREP=0 WLT_FINAL_STAGE_RUN_SNAPSHOT=0 WLT_FINAL_STAGE_RUN_COMMIT_SCAN=0 bash ci/validation/run-final-stage-gates.sh`.

- [x] `RC-016` ADB conflict-contour hard bind to runtime logging contract.
  - Result: adb matrix now emits `logcat-runtime-conflict-contour.txt` + `runtime-conflict-contour.summary.txt` per scenario, and suite-level `runtime-conflict-contour.{tsv,md,json,summary.txt}` with severity gate (`WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE`).
  - Evidence: `python3 -m py_compile ci/winlator/forensic-runtime-conflict-contour.py`, `bash -n ci/winlator/forensic-adb-complete-matrix.sh ci/winlator/forensic-adb-runtime-contract.sh ci/winlator/forensic-adb-harvard-suite.sh`, `bash ci/validation/check-urc-mainline-policy.sh`.

- [x] `RC-006` Add conflict severity level (`info|low|medium|high`) and gate option.
  - Result: conflict contour classifier emits severity + rank and supports threshold gate (`--fail-on-severity-at-or-above`), wired into runtime contract and Harvard suite via `WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE`.
  - Evidence: `python3 -m py_compile ci/winlator/forensic-runtime-conflict-contour.py`, `bash -n ci/winlator/forensic-adb-runtime-contract.sh ci/winlator/forensic-adb-harvard-suite.sh`, `bash ci/validation/check-urc-mainline-policy.sh`.

- [x] `RC-007` Add explicit conflict classes for missing wrapper artifacts (dxvk/vkd3d/ddraw payload mismatch).
  - Result: conflict contour now emits explicit statuses `wrapper_dxvk_missing`, `wrapper_vkd3d_missing`, `wrapper_ddraw_missing`, `wrapper_multi_missing` instead of generic coverage gap for wrapper payload classes.
  - Evidence: `python3 -m py_compile ci/winlator/forensic-runtime-conflict-contour.py`, `bash ci/winlator/selftest-runtime-conflict-contour.sh`.

- [x] `RC-008` Add conflict reconciliation hints (`patch_hint`) for top recurring conflict signatures.
  - Result: contour now parses `AERO_LIBRARY_CONFLICTS` signatures and maps recurring signatures to targeted statuses/focus/hints (for example `component_conflict_dxvk_artifact_source_unset` -> `dxvk-artifact-source` patch hint path).
  - Evidence: `python3 -m py_compile ci/winlator/forensic-runtime-conflict-contour.py`, `bash ci/winlator/selftest-runtime-conflict-contour.sh`.

- [x] `RC-009` Extend intake marker coverage for conflict telemetry markers (`AERO_LIBRARY_CONFLICT_*`).
  - Result: online intake marker extraction now includes `AERO_LIBRARY_CONFLICTS/COUNT/SHA256/REPRO_ID`, runtime conflict events, and runtime logging coverage markers.
  - Evidence: `python3 -m py_compile ci/reverse/online_intake.py`, ad-hoc extraction check for required markers (`markers-ok`).

- [x] `RC-010` Add compact conflict summary into final-stage gate output metadata.
  - Result: `ci/validation/run-final-stage-gates.sh` now writes `conflict_marker_repo_total`, `conflict_marker_repos`, `conflict_marker_total_hits`, and `conflict_marker_hits` into `summary.meta` from `docs/reverse/online-intake/combined-matrix.json`.
  - Evidence: `bash -n ci/validation/run-final-stage-gates.sh`, ad-hoc summary extraction run from `combined-matrix.json`.

- [x] `RC-011` NVAPI layout shim compatibility audit for arm64ec lanes.
  - Result: added strict audit `ci/validation/audit-nvapi-layout-shim.py` for override order, arm64ec artifact gate, `DXVK_ENABLE_NVAPI` toggle semantics, and builtin fallback paths; policy check now enforces this audit.
  - Evidence: `python3 ci/validation/audit-nvapi-layout-shim.py --strict --output -`, `bash ci/validation/check-urc-mainline-policy.sh`.

- [x] `RC-012` Turnip strict-bind conflict fallback audit.
  - Result: added strict audit `ci/validation/audit-turnip-strict-bind-fallback.py` for strict/relaxed bind semantics, mirror fallback reason propagation, and `turnip_bind_not_strict` conflict mapping; policy check now enforces this audit.
  - Evidence: `python3 ci/validation/audit-turnip-strict-bind-fallback.py --strict --output -`, `bash ci/validation/check-urc-mainline-policy.sh`.

---

## Doing

- [ ] `RC-005` Device-side forensic validation of conflict contour on real scenarios.
  - Owner: `Ae.solator`
  - Target matrix:
    - `wine11`, `protonwine10`, `protonge10`, `gamenative104`
    - VPN on/off
    - NVAPI requested on/off
    - Proton FSR modes (`quality/balanced/performance/ultra`)
  - Done when:
    - per-scenario bundle contains conflict markers and stable repro SHA.

---

## Ready (Prioritized Next)

---

## Inbox (New Tasks Intake)

Append new cards here in this format:

`RC-XXX | title | source(user/agent/ci) | risk(low/med/high) | note`

Current inbox:

## Intake Log (Append-only)

Use this table to append incoming tasks without editing prior rows.

| Date | Card | Source | Note |
| --- | --- | --- | --- |
| 2026-02-28 | RC-011 | user | Added NVAPI layout shim compatibility audit for arm64ec lanes |
| 2026-02-28 | RC-012 | user | Added Turnip strict-bind conflict fallback audit |
| 2026-02-28 | RC-013 | user/agent | Wired runtime conflict board into AGENTS/docs index/URC policy checks |
| 2026-02-28 | RC-014 | user | Added request for per-library reproducible conflict self-log channel |
| 2026-02-28 | RC-015 | user | Added request to hard-bind logging across all patch bases/elements |
| 2026-02-28 | RC-016 | user/agent | Bound strict runtime logging envelope into adb matrix/hardvard suite contour artifacts + threshold gate |
| 2026-02-28 | RC-006 | user/agent | Closed severity classification + gate wiring for runtime conflict contour and validated URC policy checks |
| 2026-02-28 | RC-007 | user/agent | Added explicit wrapper payload conflict classes (dxvk/vkd3d/ddraw/multi) with selftest coverage |
| 2026-02-28 | RC-008 | user/agent | Added reconciliation hint mapping from `AERO_LIBRARY_CONFLICTS` signatures to targeted patch hints |
| 2026-02-28 | RC-009 | user/agent | Extended online intake marker coverage for runtime conflict telemetry markers |
| 2026-02-28 | RC-010 | user/agent | Added compact conflict marker summary fields into final-stage `summary.meta` output |
| 2026-02-28 | RC-011 | user/agent | Closed NVAPI layout shim audit with strict policy hook in URC check |
| 2026-02-28 | RC-012 | user/agent | Closed Turnip strict-bind fallback audit with strict policy hook in URC check |

---

## Checklist (Global Remaining)

- [ ] Close `CONTENTS_QA_CHECKLIST.md` end-to-end.
- [ ] Complete Harvard ADB matrix with conflict contour enabled.
- [x] Confirm no regression in `run-final-stage-gates.sh` strict mode with updated markers.
- [ ] Keep `0001..0010` apply-check clean after each conflict-contour change.
- [ ] Fold slices back into consolidated mainline only after matrix + QA completion.

---

## Handoff For Next Agent

1. Read:
   - `docs/HARVARD_RUNTIME_CONFLICT_BOARD.md`
   - `docs/UNIFIED_RUNTIME_CONTRACT.md`
   - `ci/winlator/patches/README.md`
2. Run baseline checks:
   - `bash ci/winlator/validate-patch-sequence.sh ci/winlator/patches`
   - `WINLATOR_PATCH_FROM=0001 WINLATOR_PATCH_TO=0010 bash ci/winlator/check-patch-stack.sh <winlator-src>`
   - `bash ci/winlator/run-reflective-audits.sh`
   - `bash ci/validation/check-urc-mainline-policy.sh`
3. Move exactly one card from `Ready` to `Doing`, execute, validate, and update this board.
