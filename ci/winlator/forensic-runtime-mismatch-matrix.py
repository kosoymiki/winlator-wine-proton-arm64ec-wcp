#!/usr/bin/env python3
"""
Build a runtime mismatch matrix from forensic-adb-complete-matrix output.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path


KEY_FIELDS = (
    "saw_submit",
    "saw_terminal",
    "launch_submit",
    "launch_exit",
    "runtime_class",
    "signal_policy",
    "signal_inputs",
)

SEVERITY_RANK = {
    "info": 0,
    "low": 1,
    "medium": 2,
    "high": 3,
}


def classify_row(row: dict[str, str], baseline: dict[str, str]) -> tuple[str, str, str, str]:
    if row["label"] == baseline["label"]:
        return ("baseline", "info", "reference-row", "-")

    mismatch_reason = row.get("runtime_mismatch_reason", "-").strip().lower()
    if mismatch_reason not in {"", "-", "none", "null"}:
        return (
            "runtime_guard_blocked",
            "high",
            "runtime-mismatch-guard",
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java + app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java",
        )

    if row.get("launch_submit") == "0" and row.get("saw_submit") == "0":
        return (
            "no_submit",
            "high",
            "launch-route-or-precheck",
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java + app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java",
        )

    if row.get("launch_submit") == "1" and row.get("launch_exit") == "0" and row.get("saw_terminal") == "0":
        return (
            "hang_after_submit",
            "high",
            "runtime-exec-path",
            "app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java",
        )

    baseline_runtime = baseline.get("runtime_class", "-")
    runtime_class = row.get("runtime_class", "-")
    if baseline_runtime != "-" and runtime_class != "-" and runtime_class != baseline_runtime:
        return (
            "runtime_class_mismatch",
            "high",
            "bionic-runtime-contract",
            "ci/lib/wcp_common.sh + ci/lib/winlator-runtime.sh",
        )

    if row.get("mismatch_count", "0") != "0":
        return (
            "contract_drift",
            "medium",
            "signal-envelope-and-policy",
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java + app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java",
        )

    return ("ok", "low", "none", "-")


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


def marker(text: str, *needles: str) -> bool:
    lowered = text.lower()
    return all(needle.lower() in lowered for needle in needles)


def bool01(value: bool) -> str:
    return "1" if value else "0"


def parse_scenario(scenario_dir: Path) -> dict[str, str]:
    meta = read_keyvals(scenario_dir / "scenario_meta.txt")
    wait = read_keyvals(scenario_dir / "wait-status.txt")
    filtered = read_text(scenario_dir / "logcat-filtered.txt")
    full = read_text(scenario_dir / "logcat-full.txt")
    forensic_tail = read_text(scenario_dir / "forensics-jsonl-tail.txt")
    merged = "\n".join((filtered, full, forensic_tail))

    runtime_class = find_first(
        [
            re.compile(r'"runtimeClass"\s*:\s*"([^"]+)"'),
            re.compile(r"runtimeClass[=:\"]+\s*([A-Za-z0-9._-]+)"),
            re.compile(r"WINLATOR_RUNTIME_CLASS[=:\"]+\s*([A-Za-z0-9._-]+)"),
        ],
        merged,
    )
    signal_policy = find_first(
        [
            re.compile(r'"signalPolicy"\s*:\s*"([^"]+)"'),
            re.compile(r"WINLATOR_SIGNAL_POLICY[=:\"]+\s*([A-Za-z0-9._-]+)"),
        ],
        merged,
    )
    runtime_mismatch_reason = find_first(
        [
            re.compile(r'"runtimeMismatchReason"\s*:\s*"([^"]+)"'),
            re.compile(r"runtimeMismatchReason[=:\"]+\s*([^\n\" ,]+)"),
        ],
        merged,
    )

    signal_inputs = marker(
        merged,
        "WINLATOR_SIGNAL_INPUT_ROUTE",
        "WINLATOR_SIGNAL_INPUT_LAUNCH_KIND",
    )
    launch_submit = "LAUNCH_EXEC_SUBMIT" in merged
    launch_exit = "LAUNCH_EXEC_EXIT" in merged or "SESSION_EXIT_COMPLETED" in merged
    fex_markers = marker(merged, "fex")
    vulkan_markers = marker(merged, "vulkan")
    turnip_markers = marker(merged, "turnip")
    external_runtime = marker(merged, "external")

    return {
        "label": meta.get("label", scenario_dir.name),
        "container_id": meta.get("container_id", ""),
        "trace_id": read_text(scenario_dir / "trace_id.txt").strip(),
        "elapsed_sec": wait.get("elapsed_sec", ""),
        "saw_intent": wait.get("saw_intent", "0"),
        "saw_submit": wait.get("saw_submit", "0"),
        "saw_terminal": wait.get("saw_terminal", "0"),
        "launch_submit": bool01(launch_submit),
        "launch_exit": bool01(launch_exit),
        "runtime_class": runtime_class or "-",
        "signal_policy": signal_policy or "-",
        "signal_inputs": bool01(signal_inputs),
        "runtime_mismatch_reason": runtime_mismatch_reason or "-",
        "fex_markers": bool01(fex_markers),
        "vulkan_markers": bool01(vulkan_markers),
        "turnip_markers": bool01(turnip_markers),
        "external_runtime": bool01(external_runtime),
    }


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
    if baseline_label:
        for row in rows:
            if row["label"] == baseline_label:
                return row
    return rows[0]


def append_mismatch_fields(rows: list[dict[str, str]], baseline: dict[str, str]) -> None:
    for row in rows:
        mismatch_keys = []
        for key in KEY_FIELDS:
            if row.get(key, "") != baseline.get(key, ""):
                mismatch_keys.append(key)
        row["mismatch_count"] = str(len(mismatch_keys))
        row["mismatch_keys"] = ",".join(mismatch_keys) if mismatch_keys else "-"
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
    lines.append("# Runtime Mismatch Matrix")
    lines.append("")
    lines.append(f"- Baseline label: `{baseline['label']}`")
    lines.append(f"- Baseline container: `{baseline.get('container_id', '-')}`")
    lines.append("")
    lines.append("| Label | Container | Submit | Terminal | Launch Submit | Launch Exit | Runtime Class | Signal Policy | Mismatch Count | Status | Severity | Rank | Focus | Patch Hint | Mismatch Keys |")
    lines.append("| --- | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | --- |")
    for row in rows:
        lines.append(
            "| {label} | {container_id} | {saw_submit} | {saw_terminal} | {launch_submit} | {launch_exit} | {runtime_class} | {signal_policy} | {mismatch_count} | {status} | {severity} | {severity_rank} | {recommended_focus} | {patch_hint} | {mismatch_keys} |".format(
                **row
            )
        )
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- `saw_submit/saw_terminal` are extracted from `wait-status.txt`.")
    lines.append("- `runtime_class/signal_policy` are parsed from logcat/forensics tails when present.")
    lines.append("- `mismatch_count` is calculated against the baseline row.")
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
    lines.append("runtime_mismatch_summary")
    lines.append(f"baseline_label={baseline.get('label', '')}")
    lines.append(f"baseline_container_id={baseline.get('container_id', '')}")
    lines.append(f"scenario_count={len(rows)}")
    lines.append("status_counts=" + ",".join(f"{k}:{counts_by_status[k]}" for k in sorted(counts_by_status)))
    lines.append("severity_counts=" + ",".join(f"{k}:{counts_by_severity[k]}" for k in sorted(counts_by_severity)))
    lines.append("rows_with_mismatch=" + str(sum(1 for r in rows if r.get("mismatch_count") not in {"", "0"})))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build runtime mismatch matrix from forensic output.")
    parser.add_argument("--input", required=True, help="Directory produced by forensic-adb-complete-matrix.sh")
    parser.add_argument(
        "--baseline-label",
        default="steven104",
        help="Scenario label used as baseline. Falls back to the first scenario if missing.",
    )
    parser.add_argument(
        "--output-prefix",
        default="",
        help="Output prefix path (without extension). Defaults to <input>/runtime-mismatch-matrix",
    )
    parser.add_argument(
        "--fail-on-mismatch",
        action="store_true",
        help="Return exit code 2 if any non-baseline row has mismatch_count > 0",
    )
    parser.add_argument(
        "--fail-on-severity-at-or-above",
        choices=("off", "info", "low", "medium", "high"),
        default="off",
        help="Return exit code 3 if a non-baseline drift row has severity at/above this level.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.input).resolve()
    if not root.is_dir():
        raise SystemExit(f"input directory not found: {root}")

    scenarios = discover_scenarios(root)
    if not scenarios:
        raise SystemExit(f"no scenario directories with scenario_meta.txt under: {root}")

    rows = [parse_scenario(path) for path in scenarios]
    baseline = choose_baseline(rows, args.baseline_label)
    append_mismatch_fields(rows, baseline)

    if args.output_prefix:
        prefix = Path(args.output_prefix)
    else:
        prefix = root / "runtime-mismatch-matrix"
    prefix.parent.mkdir(parents=True, exist_ok=True)

    tsv_path = prefix.with_suffix(".tsv")
    md_path = prefix.with_suffix(".md")
    json_path = prefix.with_suffix(".json")
    summary_path = prefix.with_suffix(".summary.txt")
    write_tsv(tsv_path, rows)
    write_markdown(md_path, rows, baseline)
    write_json(json_path, rows, baseline)
    write_summary(summary_path, rows, baseline)

    print(f"[runtime-mismatch] wrote {tsv_path}")
    print(f"[runtime-mismatch] wrote {md_path}")
    print(f"[runtime-mismatch] wrote {json_path}")
    print(f"[runtime-mismatch] wrote {summary_path}")
    if args.fail_on_mismatch:
        if any(row["label"] != baseline["label"] and row.get("mismatch_count") != "0" for row in rows):
            print("[runtime-mismatch] mismatch detected against baseline")
            return 2
    if args.fail_on_severity_at_or_above != "off":
        threshold = SEVERITY_RANK[args.fail_on_severity_at_or_above]
        for row in rows:
            if row["label"] == baseline["label"]:
                continue
            if row.get("status") in {"ok", "baseline"}:
                continue
            sev_rank = int(row.get("severity_rank", "9"))
            if sev_rank >= threshold:
                print(
                    "[runtime-mismatch] severity threshold reached: "
                    f"label={row.get('label')} severity={row.get('severity')} "
                    f"threshold={args.fail_on_severity_at_or_above}"
                )
                return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
