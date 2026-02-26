# Repository Guidelines

## 1) Purpose & Scope

This file is an **operational guide** for contributors/agents working in this repository.

- Target: Winlator fork + WCP build pipelines (Wine/Proton/ProtonGE).
- Default branch: `main`.
- Safety goal: minimal, isolated, reproducible changes.

---

## 2) Critical Rules

- Do not commit secrets, tokens, or device addresses.
- Do not run destructive git commands (`reset --hard`, force-cleaning unrelated work) unless explicitly requested.
- Do not revert user-owned unrelated changes.
- Keep edits scoped to the task; avoid opportunistic refactors.
- If docs-only task is requested, change docs-only files.

---

## 3) Repo Navigation

- `ci/ci-build.sh` - Wine 11 ARM64EC WCP pipeline.
- `ci/proton-ge10/ci-build-proton-ge10-wcp.sh` - Proton GE10 ARM64EC WCP pipeline.
- `ci/protonwine10/ci-build-protonwine10-wcp.sh` - ProtonWine10 ARM64EC WCP pipeline.
- `ci/gamenative/` - GameNative patchset orchestration (`apply-android-patchset.sh`, manifest, audit tooling).
- `ci/winlator/` - Winlator build flow and patch stack application.
- `.github/workflows/` - CI entrypoints and release publishing.
- `contents/contents.json` - content catalog surface used by Winlator.

---

## 4) Execution Protocol (Required)

1. Inspect current state (`git status`, target files, workflow paths).
2. Implement the smallest viable change.
3. Validate locally with relevant checks.
4. Commit with focused scope and clear message.
5. Push only when requested or when task explicitly includes delivery.

---

## 5) Validation Matrix

Run the narrowest relevant checks:

- Winlator patch stack / contents contract changes:
  - `bash ci/winlator/validate-patch-sequence.sh`
  - `bash ci/winlator/run-reflective-audits.sh`
  - `bash ci/validation/check-urc-mainline-policy.sh`
  - `bash ci/winlator/selftest-runtime-mismatch-matrix.sh`
- Mainline workflow health (pre-triage):
  - `bash ci/validation/gh-mainline-health.sh main 24`
  - `bash ci/validation/collect-mainline-forensic-snapshot.sh`
- Patch-stack apply safety (when touching `ci/winlator/patches/*.patch`):
  - `bash ci/winlator/check-patch-stack.sh /path/to/winlator-upstream-git`
- Wine pipeline changes:
  - `bash -n ci/ci-build.sh`
- Proton GE pipeline changes:
  - `bash -n ci/proton-ge10/ci-build-proton-ge10-wcp.sh`
- ProtonWine pipeline changes:
  - `bash -n ci/protonwine10/ci-build-protonwine10-wcp.sh`
- GN patchset logic changes:
  - `bash -n ci/gamenative/apply-android-patchset.sh`
  - `python3 -m py_compile ci/gamenative/patchset-conflict-audit.py` (if touched)
- Workflow yaml changes:
  - parse/validate YAML locally before push.

---

## 6) CI / Workflow Safety

- Workflow triggers are path-based; check `.github/workflows/*.yml` before editing broad paths.
- Avoid touching `docs/**` if task explicitly says to avoid extra workflow runs.
- Prefer changing only requested files to prevent unintended CI fan-out.

---

## 7) Commit & PR Convention

- Commit style: `<scope>: <concise action>`
  - Examples:
    - `ci: align protonwine patchset mode handling`
    - `docs: rewrite README bilingual structure`
- One logical change per commit.
- In PR/summary, include:
  - what changed,
  - why,
  - what was validated,
  - known risks (if any).

---

## 8) Default Assumptions

- Mainline runtime policy is external-only unless explicitly changed.
- GN patchset is the single source of truth for manifest-owned file patches.
- Release artifacts must remain reproducible and traceable via logs + SHA256.
