#!/usr/bin/env python3
"""
Build a runtime conflict contour matrix from forensic-adb-complete-matrix output.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path


SEVERITY_RANK = {
    "info": 0,
    "low": 1,
    "medium": 2,
    "high": 3,
}

EVENT_TOKENS = {
    "event_runtime_subsystem_snapshot": "RUNTIME_SUBSYSTEM_SNAPSHOT",
    "event_runtime_logging_contract_snapshot": "RUNTIME_LOGGING_CONTRACT_SNAPSHOT",
    "event_runtime_library_component_signal": "RUNTIME_LIBRARY_COMPONENT_SIGNAL",
    "event_runtime_library_component_conflict": "RUNTIME_LIBRARY_COMPONENT_CONFLICT",
    "event_runtime_library_conflict_snapshot": "RUNTIME_LIBRARY_CONFLICT_SNAPSHOT",
    "event_runtime_library_conflict_detected": "RUNTIME_LIBRARY_CONFLICT_DETECTED",
}

WRAPPER_COMPONENT_CLASS = {
    "dxvk": (
        "wrapper_dxvk_missing",
        "high",
        "wrapper-artifact-integrity",
        "ci/lib/wcp_common.sh + ci/ci-build.sh (DXVK payload path)",
    ),
    "vkd3d": (
        "wrapper_vkd3d_missing",
        "high",
        "wrapper-artifact-integrity",
        "ci/lib/wcp_common.sh + ci/ci-build.sh (VKD3D payload path)",
    ),
    "ddraw": (
        "wrapper_ddraw_missing",
        "high",
        "wrapper-artifact-integrity",
        "ci/lib/wcp_common.sh + winlator runtime wrapper payload layout",
    ),
}

CONFLICT_SIGNATURE_HINTS = {
    "dxvk_artifact_source_unset": (
        "high",
        "dxvk-artifact-source",
        "ci/lib/wcp_common.sh + ci/ci-build.sh (DXVK source selection and payload staging)",
    ),
    "vkd3d_artifact_source_unset": (
        "high",
        "vkd3d-artifact-source",
        "ci/lib/wcp_common.sh + ci/ci-build.sh (VKD3D source selection and payload staging)",
    ),
    "ddraw_artifact_source_unset": (
        "high",
        "ddraw-artifact-source",
        "ci/lib/wcp_common.sh + runtime wrapper payload source selection",
    ),
    "layout_libs_missing_for_dxvk": (
        "high",
        "layout-wrapper-bindings",
        "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java (layout libs for DXVK stack)",
    ),
    "runtime_logging_mode_not_strict": (
        "high",
        "runtime-logging-contract",
        "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java (strict logging mode contract)",
    ),
    "runtime_logging_coverage_missing": (
        "high",
        "runtime-logging-contract",
        "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java (logging coverage publication)",
    ),
    "turnip_bind_not_strict": (
        "medium",
        "turnip-bind-policy",
        "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java (turnip strict bind path)",
    ),
    "runtime_distribution_mismatch": (
        "medium",
        "runtime-distribution-contract",
        "docs/UNIFIED_RUNTIME_CONTRACT.md + XServerDisplayActivity distribution marker",
    ),
}


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except FileNotFoundError:
        return ""


def read_keyvals(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    for raw in read_text(path).splitlines():
        if "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        data[key.strip()] = value.strip()
    return data


def find_first(patterns: list[re.Pattern[str]], text: str) -> str:
    for pat in patterns:
        match = pat.search(text)
        if match:
            return match.group(1).strip()
    return ""


def parse_component_map(payload: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for token in payload.split(";"):
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        key = key.strip().lower()
        value = value.strip()
        if not key:
            continue
        out[key] = value
    return out


def parse_csv_tokens(payload: str) -> list[str]:
    return [item.strip().lower() for item in payload.split(",") if item.strip()]


def parse_pipe_tokens(payload: str) -> list[str]:
    return [
        item.strip().lower()
        for item in payload.split("|")
        if item.strip() and item.strip().lower() != "none"
    ]


def classify_wrapper_missing(missing_components: list[str]) -> tuple[str, str, str, str] | None:
    wrappers = [key for key in ("dxvk", "vkd3d", "ddraw") if key in missing_components]
    if not wrappers:
        return None
    if len(wrappers) == 1:
        status, severity, focus, patch_hint = WRAPPER_COMPONENT_CLASS[wrappers[0]]
        return (status, severity, focus, patch_hint)
    return (
        "wrapper_multi_missing",
        "high",
        "wrapper-artifact-integrity",
        "ci/lib/wcp_common.sh + ci/ci-build.sh + winlator runtime wrapper payload layout",
    )


def classify_conflict_signature(conflict_signatures: list[str]) -> tuple[str, str, str, str] | None:
    for signature in conflict_signatures:
        hint = CONFLICT_SIGNATURE_HINTS.get(signature)
        if hint is None:
            continue
        severity, focus, patch_hint = hint
        return (f"component_conflict_{signature}", severity, focus, patch_hint)
    return None


def discover_scenarios(root: Path) -> list[Path]:
    scenarios = []
    for child in sorted(root.iterdir()):
        if not child.is_dir():
            continue
        if child.name == "ui-baseline":
            continue
        if (child / "scenario_meta.txt").exists():
            scenarios.append(child)
    return scenarios


def choose_baseline(rows: list[dict[str, str]], baseline_label: str) -> dict[str, str]:
    alias_map = {
        "steven104": "gamenative104",
        "gamenative104": "steven104",
    }
    if baseline_label:
        for row in rows:
            if row["label"] == baseline_label:
                return row
        alias = alias_map.get(baseline_label)
        if alias:
            for row in rows:
                if row["label"] == alias:
                    return row
    return rows[0]


def parse_scenario(scenario_dir: Path) -> dict[str, str]:
    meta = read_keyvals(scenario_dir / "scenario_meta.txt")
    wait = read_keyvals(scenario_dir / "wait-status.txt")
    filtered = read_text(scenario_dir / "logcat-filtered.txt")
    full = read_text(scenario_dir / "logcat-full.txt")
    forensic_tail = read_text(scenario_dir / "forensics-jsonl-tail.txt")
    contour = read_text(scenario_dir / "logcat-runtime-conflict-contour.txt")
    merged = "\n".join((filtered, full, forensic_tail, contour))

    runtime_subsystems_sha = find_first(
        [
            re.compile(r'"runtime_subsystems_sha256"\s*:\s*"([^"]+)"'),
            re.compile(r"AERO_RUNTIME_SUBSYSTEMS_SHA256[=:\"]+\s*([A-Fa-f0-9]{16,64})"),
            re.compile(r"snapshot_sha256[=:\"]+\s*([A-Fa-f0-9]{16,64})"),
        ],
        merged,
    )
    component_stream_sha = find_first(
        [
            re.compile(r'"component_stream_sha256"\s*:\s*"([^"]+)"'),
            re.compile(r'"library_component_stream_sha256"\s*:\s*"([^"]+)"'),
            re.compile(r"AERO_LIBRARY_COMPONENT_STREAM_SHA256[=:\"]+\s*([A-Fa-f0-9]{16,64})"),
        ],
        merged,
    )
    logging_mode = find_first(
        [
            re.compile(r'"logging_mode"\s*:\s*"([^"]+)"'),
            re.compile(r'"runtime_logging_mode"\s*:\s*"([^"]+)"'),
            re.compile(r"AERO_RUNTIME_LOGGING_MODE[=:\"]+\s*([A-Za-z0-9._-]+)"),
        ],
        merged,
    )
    logging_required = find_first(
        [
            re.compile(r'"logging_required"\s*:\s*"([^"]+)"'),
            re.compile(r'"runtime_logging_required"\s*:\s*"([^"]+)"'),
            re.compile(r"AERO_RUNTIME_LOGGING_REQUIRED[=:\"]+\s*([A-Za-z0-9,._-]+)"),
        ],
        merged,
    )
    logging_coverage = find_first(
        [
            re.compile(r'"logging_coverage"\s*:\s*"([^"]+)"'),
            re.compile(r'"runtime_logging_coverage"\s*:\s*"([^"]+)"'),
            re.compile(r"AERO_RUNTIME_LOGGING_COVERAGE[=:\"]+\s*([A-Za-z0-9=;._,-]+)"),
        ],
        merged,
    )
    logging_coverage_sha = find_first(
        [
            re.compile(r'"logging_coverage_sha256"\s*:\s*"([^"]+)"'),
            re.compile(r'"runtime_logging_coverage_sha256"\s*:\s*"([^"]+)"'),
            re.compile(r"AERO_RUNTIME_LOGGING_COVERAGE_SHA256[=:\"]+\s*([A-Fa-f0-9]{16,64})"),
        ],
        merged,
    )
    runtime_distribution = find_first(
        [
            re.compile(r'"runtime_distribution"\s*:\s*"([^"]+)"'),
            re.compile(r"AERO_RUNTIME_DISTRIBUTION[=:\"]+\s*([A-Za-z0-9._-]+)"),
        ],
        merged,
    )
    runtime_flavor = find_first(
        [
            re.compile(r'"runtime_flavor"\s*:\s*"([^"]+)"'),
            re.compile(r"AERO_RUNTIME_FLAVOR[=:\"]+\s*([A-Za-z0-9._-]+)"),
        ],
        merged,
    )
    runtime_emulator = find_first(
        [
            re.compile(r'"runtime_emulator"\s*:\s*"([^"]+)"'),
            re.compile(r"AERO_RUNTIME_EMULATOR[=:\"]+\s*([A-Za-z0-9._-]+)"),
        ],
        merged,
    )
    translator_chain = find_first(
        [
            re.compile(r'"translator_chain"\s*:\s*"([^"]+)"'),
            re.compile(r'"runtime_translator_chain"\s*:\s*"([^"]+)"'),
            re.compile(r"AERO_RUNTIME_TRANSLATOR_CHAIN[=:\"]+\s*([A-Za-z0-9._-]+)"),
        ],
        merged,
    )
    runtime_hodll = find_first(
        [
            re.compile(r'"runtime_hodll"\s*:\s*"([^"]+)"'),
            re.compile(r"AERO_RUNTIME_HODLL[=:\"]+\s*([A-Za-z0-9._,;=-]+)"),
        ],
        merged,
    )
    library_conflicts = find_first(
        [
            re.compile(r'"library_conflicts"\s*:\s*"([^"]+)"'),
            re.compile(r"AERO_LIBRARY_CONFLICTS[=:\"]+\s*([A-Za-z0-9._|:-]+)"),
        ],
        merged,
    )

    coverage_map = parse_component_map(logging_coverage)
    required_components = parse_csv_tokens(logging_required)
    conflict_signatures = parse_pipe_tokens(library_conflicts)
    missing_components = [
        key for key in required_components if coverage_map.get(key, "0").strip() != "1"
    ]

    row: dict[str, str] = {
        "label": meta.get("label", scenario_dir.name),
        "container_id": meta.get("container_id", ""),
        "trace_id": read_text(scenario_dir / "trace_id.txt").strip(),
        "elapsed_sec": wait.get("elapsed_sec", ""),
        "runtime_distribution": runtime_distribution or "-",
        "runtime_flavor": runtime_flavor or "-",
        "runtime_emulator": runtime_emulator or "-",
        "runtime_translator_chain": translator_chain or "-",
        "runtime_hodll": runtime_hodll or "-",
        "runtime_subsystems_sha256": runtime_subsystems_sha or "-",
        "component_stream_sha256": component_stream_sha or "-",
        "runtime_logging_mode": logging_mode or "-",
        "runtime_logging_required": logging_required or "-",
        "runtime_logging_coverage": logging_coverage or "-",
        "runtime_logging_coverage_sha256": logging_coverage_sha or "-",
        "logging_required_components": ",".join(required_components) if required_components else "-",
        "logging_missing_components": ",".join(missing_components) if missing_components else "-",
        "library_conflicts": library_conflicts or "-",
        "library_conflict_signatures": ",".join(conflict_signatures) if conflict_signatures else "-",
        "library_conflict_signature_count": str(len(conflict_signatures)),
        "logging_has_x11": "1" if coverage_map.get("x11", "0") == "1" else "0",
        "logging_has_turnip": "1" if coverage_map.get("turnip", "0") == "1" else "0",
        "logging_has_dxvk": "1" if coverage_map.get("dxvk", "0") == "1" else "0",
        "logging_has_vkd3d": "1" if coverage_map.get("vkd3d", "0") == "1" else "0",
        "logging_has_ddraw": "1" if coverage_map.get("ddraw", "0") == "1" else "0",
        "logging_has_layout": "1" if coverage_map.get("layout", "0") == "1" else "0",
        "logging_has_translator": "1" if coverage_map.get("translator", "0") == "1" else "0",
        "logging_has_loader": "1" if coverage_map.get("loader", "0") == "1" else "0",
        "logging_has_adrenotools": "1" if coverage_map.get("adrenotools", "0") == "1" else "0",
        "logging_has_fex": "1" if coverage_map.get("fex", "0") == "1" else "0",
        "logging_has_box": "1" if coverage_map.get("box", "0") == "1" else "0",
    }

    for key, token in EVENT_TOKENS.items():
        row[key] = str(merged.count(token))

    conflict_count = int(row["event_runtime_library_component_conflict"]) + int(
        row["event_runtime_library_conflict_detected"]
    )
    row["component_conflict_count"] = str(conflict_count)
    return row


def classify_row(row: dict[str, str], baseline: dict[str, str]) -> tuple[str, str, str, str]:
    if row["label"] == baseline["label"]:
        return ("baseline", "info", "reference-row", "-")

    if row.get("runtime_logging_mode", "-") not in {"strict", "-"}:
        return (
            "logging_mode_drift",
            "high",
            "runtime-logging-contract",
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java",
        )

    if row.get("runtime_subsystems_sha256", "-") == "-" or row.get("component_stream_sha256", "-") == "-":
        return (
            "logging_fingerprint_missing",
            "high",
            "runtime-subsystem-envelope",
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java",
        )

    if row.get("runtime_logging_coverage_sha256", "-") == "-":
        return (
            "logging_coverage_hash_missing",
            "high",
            "runtime-logging-contract",
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java",
        )

    if row.get("event_runtime_subsystem_snapshot", "0") == "0":
        return (
            "subsystem_snapshot_missing",
            "high",
            "forensic-event-routing",
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java",
        )

    if row.get("event_runtime_logging_contract_snapshot", "0") == "0":
        return (
            "logging_contract_snapshot_missing",
            "high",
            "forensic-event-routing",
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java",
        )

    if row.get("event_runtime_library_component_signal", "0") == "0":
        return (
            "component_signal_missing",
            "high",
            "runtime-library-component-signals",
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java",
        )

    missing = row.get("logging_missing_components", "-")
    if missing not in {"", "-"}:
        wrapper_status = classify_wrapper_missing(parse_csv_tokens(missing))
        if wrapper_status is not None:
            return wrapper_status
        severity = "medium"
        if any(
            core in missing.split(",")
            for core in ("x11", "turnip", "dxvk", "vkd3d", "layout", "translator", "loader")
        ):
            severity = "high"
        return (
            "logging_coverage_gap",
            severity,
            "runtime-logging-coverage",
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java",
        )

    if row.get("runtime_distribution", "-") not in {"-", "ae.solator"}:
        return (
            "distribution_mismatch",
            "medium",
            "runtime-distribution-contract",
            "docs/UNIFIED_RUNTIME_CONTRACT.md + XServerDisplayActivity distribution marker",
        )

    if int(row.get("component_conflict_count", "0") or "0") > 0:
        signature_status = classify_conflict_signature(
            parse_pipe_tokens(row.get("library_conflicts", "-"))
        )
        if signature_status is not None:
            return signature_status
        return (
            "component_conflicts_detected",
            "medium",
            "runtime-library-conflicts",
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java + launcher routing",
        )

    return ("ok", "low", "none", "-")


def append_classification(rows: list[dict[str, str]], baseline: dict[str, str]) -> None:
    for row in rows:
        status, severity, focus, patch_hint = classify_row(row, baseline)
        row["status"] = status
        row["severity"] = severity
        row["severity_rank"] = str(SEVERITY_RANK.get(severity, 9))
        row["recommended_focus"] = focus
        row["patch_hint"] = patch_hint


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    if not rows:
        return
    fields = list(rows[0].keys())
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def write_markdown(path: Path, rows: list[dict[str, str]], baseline: dict[str, str]) -> None:
    lines = []
    lines.append("# Runtime Conflict Contour")
    lines.append("")
    lines.append(f"- Baseline label: `{baseline['label']}`")
    lines.append(f"- Baseline container: `{baseline.get('container_id', '-')}`")
    lines.append("")
    lines.append(
        "| Label | Container | Subsystem Snapshot | Logging Snapshot | Component Signals | Component Conflicts | Logging Mode | Missing Components | Status | Severity | Rank | Focus | Patch Hint |"
    )
    lines.append(
        "| --- | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- | ---: | --- | --- |"
    )
    for row in rows:
        lines.append(
            "| {label} | {container_id} | {event_runtime_subsystem_snapshot} | {event_runtime_logging_contract_snapshot} | {event_runtime_library_component_signal} | {component_conflict_count} | {runtime_logging_mode} | {logging_missing_components} | {status} | {severity} | {severity_rank} | {recommended_focus} | {patch_hint} |".format(
                **row
            )
        )
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- `component_conflict_count` = `RUNTIME_LIBRARY_COMPONENT_CONFLICT + RUNTIME_LIBRARY_CONFLICT_DETECTED`.")
    lines.append("- `logging_missing_components` is derived from `runtime_logging_required` vs `runtime_logging_coverage`.")
    lines.append("- Missing wrapper components (`dxvk`, `vkd3d`, `ddraw`) are emitted as explicit `wrapper_*_missing` statuses.")
    lines.append("- Known conflict signatures from `AERO_LIBRARY_CONFLICTS` are mapped to targeted reconciliation `patch_hint` values.")
    lines.append("- This matrix is sourced from scenario logcat + forensics JSONL tails from adb capture.")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_json(path: Path, rows: list[dict[str, str]], baseline: dict[str, str]) -> None:
    payload = {
        "baseline_label": baseline.get("label", ""),
        "baseline_container_id": baseline.get("container_id", ""),
        "rows": rows,
    }
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")


def write_summary(path: Path, rows: list[dict[str, str]], baseline: dict[str, str]) -> None:
    counts_by_status: dict[str, int] = {}
    counts_by_severity: dict[str, int] = {}
    for row in rows:
        status = row.get("status", "unknown")
        severity = row.get("severity", "unknown")
        counts_by_status[status] = counts_by_status.get(status, 0) + 1
        counts_by_severity[severity] = counts_by_severity.get(severity, 0) + 1
    lines = []
    lines.append("runtime_conflict_contour_summary")
    lines.append(f"baseline_label={baseline.get('label', '')}")
    lines.append(f"baseline_container_id={baseline.get('container_id', '')}")
    lines.append(f"scenario_count={len(rows)}")
    lines.append("status_counts=" + ",".join(f"{k}:{counts_by_status[k]}" for k in sorted(counts_by_status)))
    lines.append("severity_counts=" + ",".join(f"{k}:{counts_by_severity[k]}" for k in sorted(counts_by_severity)))
    lines.append(
        "rows_with_component_conflicts="
        + str(sum(1 for row in rows if int(row.get("component_conflict_count", "0") or "0") > 0))
    )
    lines.append(
        "rows_with_logging_coverage_gap="
        + str(sum(1 for row in rows if row.get("logging_missing_components", "-") not in {"", "-"}))
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def severity_threshold_hit(rows: list[dict[str, str]], threshold: str) -> tuple[bool, dict[str, str] | None]:
    if threshold == "off":
        return (False, None)
    threshold_rank = SEVERITY_RANK[threshold]
    for row in rows:
        if row.get("status") in {"baseline", "ok"}:
            continue
        if SEVERITY_RANK.get(row.get("severity", "info"), 0) >= threshold_rank:
            return (True, row)
    return (False, None)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build runtime conflict contour matrix from forensic output.")
    parser.add_argument("--input", required=True, help="Directory produced by forensic-adb-complete-matrix.sh")
    parser.add_argument(
        "--baseline-label",
        default="gamenative104",
        help="Scenario label used as baseline. Falls back to first scenario if missing.",
    )
    parser.add_argument(
        "--output-prefix",
        default="",
        help="Output prefix path (without extension). Defaults to <input>/runtime-conflict-contour",
    )
    parser.add_argument(
        "--fail-on-severity-at-or-above",
        choices=("off", "info", "low", "medium", "high"),
        default="off",
        help="Return exit code 3 if non-baseline row severity is at/above this level.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.input)
    if not root.exists():
        raise SystemExit(f"[runtime-conflict-contour][error] input directory not found: {root}")

    scenarios = discover_scenarios(root)
    if not scenarios:
        raise SystemExit(f"[runtime-conflict-contour][error] no scenario dirs under: {root}")

    rows = [parse_scenario(path) for path in scenarios]
    baseline = choose_baseline(rows, args.baseline_label)
    append_classification(rows, baseline)

    output_prefix = args.output_prefix or str(root / "runtime-conflict-contour")
    prefix_path = Path(output_prefix)
    write_tsv(prefix_path.with_suffix(".tsv"), rows)
    write_markdown(prefix_path.with_suffix(".md"), rows, baseline)
    write_json(prefix_path.with_suffix(".json"), rows, baseline)
    write_summary(prefix_path.with_suffix(".summary.txt"), rows, baseline)

    hit, row = severity_threshold_hit(rows, args.fail_on_severity_at_or_above)
    if hit and row is not None:
        print(
            "[runtime-conflict-contour] severity threshold reached: "
            f"label={row.get('label','-')} status={row.get('status','-')} "
            f"severity={row.get('severity','-')} threshold={args.fail_on_severity_at_or_above}"
        )
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
