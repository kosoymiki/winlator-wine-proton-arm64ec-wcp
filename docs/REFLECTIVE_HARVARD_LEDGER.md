# Reflective Harvard Ledger

This ledger is mandatory for the Magnum Opus integration track.  
Every logical stage must include explicit hypothesis, evidence, and validation.

## How to use

For each stage/patch set, add one row with concrete links to commits, logs, and files.
Do not leave placeholder text in completed rows.

## Record Template

| Stage | Scope | Hypothesis | Evidence | Counter-evidence | Decision | Impact | Verification | Owner | Date (UTC) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `A1` | `runtime-contract` | Runtime plan unification lowers launch variance | `logcat bundle`, `forensics manifest` | One container still hangs on first launch | `rework` | Keep preflight hard gate, postpone profile auto-switch | `forensic-adb-complete-matrix.sh` + cold start x10 | `Ae.solator` | `2026-02-25` |
| `B3` | `translator-profile-migration` | Runtime profile-driven fallback from legacy presets reduces drift between requested and effective launch env | `ci/winlator/patches/0001-mainline-full-stack-consolidated.patch`, `docs/UNIFIED_RUNTIME_CONTRACT.md` | Risk of overriding intentionally old presets if migration is too aggressive | `accept` | Legacy defaults are mapped only for explicit non-`AUTO` runtime profiles; forensic now records requested/effective presets | `ci/winlator/check-patch-stack.sh` (43 patches) | `Ae.solator` | `2026-02-25` |
| `C1` | `gamenative-apk-runtime-matrix` | Correct focus prefixes for GN 0.7.2 expose actionable launch/graphics/runtime transfer signals for `pre-0044` | `/home/mikhail/gamenative-v0.7.2_reverse_20260225_143304/focus/focus_summary.txt`, `docs/GAMENATIVE_072_RUNTIME_TRANSFER_MATRIX.md`, `ci/research/extract-apk-runtime-focus.py`, `ci/research/build-gamenative-runtime-transfer-report.py` | Initial extraction with legacy-only prefixes (`Lcom/winemu/`, `Lcom/xj/winemu/`) produced zero focus classes/methods and invalid matrix | `accept` | Focus capture now includes `Lcom/winlator/` + `Lapp/gamenative/`; matrix quantifies launch (`630`), graphics (`366`), registry (`37`) and translator (`213`) method surfaces for targeted 0044 queue work | `ci/research/extract-apk-runtime-focus.py --apk /home/mikhail/gamenative-v0.7.2.apk`, `ci/research/build-gamenative-runtime-transfer-report.py` | `Ae.solator` | `2026-02-25` |
| `C2` | `gn-gh-patch-crosswalk` | Function-level crosswalk can identify safe patch merges between GameNative and GameHub without violating external-only policy | `docs/GAMENATIVE_072_RUNTIME_TRANSFER_MATRIX.md`, `docs/GAMEHUB_RUNTIME_TRANSFER_MATRIX.md`, `docs/GN_GH_PATCH_CROSSWALK.md`, `ci/research/build-gn-gh-patch-crosswalk.py` | Raw module overlap is noisy if token filters are too broad (false positives from generic UI/content names) | `accept` | Defined merge queue by shared behavior (`0044` launch, `0045` graphics, `0046` registry) and kept content/UI layers as research-only | `ci/research/build-gamehub-runtime-transfer-report.py`, `ci/research/build-gn-gh-patch-crosswalk.py` | `Ae.solator` | `2026-02-25` |
| `C3` | `launch-runtime-contract-bridge-0044` | A strict launch precheck bridge between activity and launcher can reduce route/shortcut drift crashes while preserving external-only runtime policy | `ci/winlator/patches/0001-mainline-full-stack-consolidated.patch`, `docs/GN_GH_PATCH_CROSSWALK.md` | Full Gradle compile in sandbox was blocked by environment limits (`SDK location` then Gradle daemon socket restrictions/download task), so runtime compile proof remains CI-only | `accept` | Added reason-coded launch precheck (`route/kind/target/reason/shell_fallback`) in `XServerDisplayActivity` + `GuestProgramLauncherComponent`, deterministic `wfm.exe` fallback for missing shortcut/empty command, and `WINLATOR_RUNTIME_PRESET_GUARD_REASON` forensic/env contract | `ci/winlator/check-patch-stack.sh` (44 patches, apply-pass), next verification in GitHub CI + adb forensic runs | `Ae.solator` | `2026-02-25` |
| `D2` | `runtime-forensic-mismatch-matrix` | Enforcing branch/time-bounded CI failure parsing plus scenario-level runtime mismatch matrix will reduce false triage and speed startup-hang root cause detection | `ci/validation/gh-latest-failures.sh`, `ci/winlator/forensic-adb-runtime-contract.sh`, `ci/winlator/forensic-runtime-mismatch-matrix.py`, `docs/CI_FAILURE_PLAYBOOK.md`, `README.md` | Runtime class / signal markers may still be absent in some device logs, so mismatch rows can contain `-` placeholders and require manual confirmation | `accept` | Added fresh-failure filtering (`branch + since_hours`) and a deterministic adb forensic pipeline that emits baseline-compared mismatch TSV/MD for `wine11/protonwine10/steven104` scenarios | `bash ci/validation/gh-latest-failures.sh 20 main 24`, `python3 ci/winlator/forensic-runtime-mismatch-matrix.py --help`, `bash -n ci/winlator/forensic-adb-runtime-contract.sh` | `Ae.solator` | `2026-02-26` |
| `D37` | `x11-turnip-dxvk-upscaler-runtime-matrix-0004-0010` | X11-first graphics launch should use deterministic DX route + upscaler matrix + capability envelope (including ARM64EC NVAPI gating) across Wine/Proton lanes | `ci/winlator/patches/0004-upscaler-adrenotools-control-plane-x11-bind.patch`, `ci/winlator/patches/0005-upscaler-dxvk-proton-fsr-x11-turnip-runtime-matrix.patch`, `ci/winlator/patches/0006-upscaler-x11-turnip-dx-all-directs-memory-policy.patch`, `ci/winlator/patches/0007-upscaler-module-forensics-dx8assist-contract.patch`, `ci/winlator/patches/0008-upscaler-dx-policy-order-and-artifact-sources.patch`, `ci/winlator/patches/0009-launch-graphics-packet-dx-upscaler-x11-turnip-bundle.patch`, `ci/winlator/patches/0010-dxvk-capability-envelope-proton-fsr-gate-upscaler-matrix.patch`, `docs/UNIFIED_RUNTIME_CONTRACT.md` | Aggressive matrix expansion can create contradictory env/forensic states if order is not fixed across runtime and launcher paths | `accept` | Added DX requested/effective map, policy-order marker, Proton FSR DXVK-stack gate, NVAPI requested/effective+arch markers, and unified launch packet forwarding | `WINLATOR_PATCH_FROM=0001 WINLATOR_PATCH_TO=0010 bash ci/winlator/check-patch-stack.sh <src>`, `bash ci/winlator/run-reflective-audits.sh`, `bash ci/validation/run-final-stage-gates.sh` | `Ae.solator` | `2026-02-28` |

## Decision Codes

- `accept` - implementation validated and promoted to mainline.
- `rework` - concept is kept, implementation changes required.
- `reject` - not compatible with external-only mainline policy.

## Required Artifacts Per Row

- commit SHA(s)
- affected patch IDs
- forensic evidence path(s)
- explicit regression result (pass/fail)
