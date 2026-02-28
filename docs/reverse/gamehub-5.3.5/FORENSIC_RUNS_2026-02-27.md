# Forensic Runs - February 27, 2026

## Captures produced

| Scenario label | Archive | Outcome |
|---|---|---|
| `proton_container` | `out/gamehub-forensics/20260227_130436_proton_container.tar.gz` | External logs show Proton container path (`proton10.0-arm64x-2`), but live `ps` did not retain active wine child set during sampling window |
| `wine_container` | `out/gamehub-forensics/20260227_130609_wine_container.tar.gz` | Same: strong external signal, but live sampling window did not include stable child runtime set |
| `smoke_test2` | `out/gamehub-forensics/20260227_130823_smoke_test2.tar.gz` | Script validation run after filter hardening; process sampling correctly captures package processes without grep self-noise |

## Interpretation

- Capture tooling works and archives are valid.
- Current two scenario runs were **passive** relative to container launch interaction, so process evidence is dominated by launcher-level package process state.
- High-confidence runtime evidence still comes from app external logs plus earlier dedicated live run (`/tmp/gamehub_live_20260227_124752`).

## Required next run mode (interactive)

For strict Proton-vs-Wine process parity capture, run script while container launch is actively triggered during sampling window:

```bash
ADB_SERIAL=edb0acd0 GH_PKG=com.miHoYo.GenshinImpact GH_START_APP=0 GH_DURATION=90 \
  ci/forensics/gamehub_capture.sh proton_container_live

ADB_SERIAL=edb0acd0 GH_PKG=com.miHoYo.GenshinImpact GH_START_APP=0 GH_DURATION=90 \
  ci/forensics/gamehub_capture.sh wine_container_live
```

Start each target container manually in the UI immediately after command start.

