#!/usr/bin/env python3
"""Validate RC-005 device-side matrix artifacts.

Checks:
- scenario coverage for flavor/vpn/nvapi/fsr axes
- per-scenario conflict marker presence
- per-scenario stable AERO_LIBRARY_CONFLICT_SHA256 envelope
"""

from __future__ import annotations

import argparse
import itertools
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple

LABEL_RE = re.compile(
    r"^(?P<flavor>.+?)__vpn-(?P<vpn>[^_]+)__nvapi-(?P<nvapi>[01])__fsr-(?P<fsr>.+)$"
)

SHA_RE = re.compile(
    r"AERO_LIBRARY_CONFLICT_SHA256[^0-9a-fA-F]*([0-9a-fA-F]{64})"
    r'|"library_conflict_sha256"\s*:\s*"([0-9a-fA-F]{64})"',
    re.IGNORECASE,
)

MARKER_RE = re.compile(
    r"AERO_LIBRARY_CONFLICT_(?:S|COUNT|SHA256|REPRO_ID)"
    r"|RUNTIME_LIBRARY_CONFLICT_(?:SNAPSHOT|DETECTED)",
    re.IGNORECASE,
)


@dataclass
class ScenarioResult:
    path: Path
    label: str
    flavor: str
    vpn_state: str
    nvapi_state: str
    fsr_mode: str
    has_conflict_artifacts: bool
    has_conflict_markers: bool
    sha_values: List[str]

    @property
    def stable_sha(self) -> bool:
        uniq = {s.lower() for s in self.sha_values}
        return len(uniq) == 1 and len(self.sha_values) > 0


@dataclass
class AuditResult:
    scenarios: List[ScenarioResult]
    malformed_labels: List[Tuple[Path, str]]
    missing_combinations: List[Tuple[str, str, str, str]]
    missing_flavors: List[str]
    missing_vpn_states: List[str]
    missing_nvapi_states: List[str]
    missing_fsr_modes: List[str]
    failures: List[str]


def parse_csv_list(raw: str) -> List[str]:
    return [item.strip() for item in raw.split(",") if item.strip()]


def parse_meta(path: Path) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        out[key.strip()] = value.strip()
    return out


def read_optional(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="ignore")


def extract_sha_values(text: str) -> List[str]:
    values: List[str] = []
    for match in SHA_RE.finditer(text):
        first, second = match.groups()
        token = first or second
        if token:
            values.append(token.lower())
    return values


def load_scenario(path: Path) -> Tuple[ScenarioResult | None, Tuple[Path, str] | None]:
    meta_path = path / "scenario_meta.txt"
    meta = parse_meta(meta_path)
    label = meta.get("label", path.name)

    m = LABEL_RE.match(label)
    if not m:
        return None, (path, label)

    contour_log = path / "logcat-runtime-conflict-contour.txt"
    contour_summary = path / "runtime-conflict-contour.summary.txt"

    has_conflict_artifacts = contour_log.exists() and contour_summary.exists()

    corpus_parts = [
        read_optional(contour_log),
        read_optional(contour_summary),
        read_optional(path / "logcat-filtered.txt"),
        read_optional(path / "forensics-jsonl-tail.txt"),
    ]

    runtime_logs_dir = path / "runtime-logs"
    if runtime_logs_dir.is_dir():
        for log_file in sorted(runtime_logs_dir.glob("*")):
            if log_file.is_file():
                corpus_parts.append(read_optional(log_file))

    corpus = "\n".join(corpus_parts)

    has_conflict_markers = bool(MARKER_RE.search(corpus))
    sha_values = extract_sha_values(corpus)

    res = ScenarioResult(
        path=path,
        label=label,
        flavor=m.group("flavor"),
        vpn_state=m.group("vpn"),
        nvapi_state=m.group("nvapi"),
        fsr_mode=m.group("fsr"),
        has_conflict_artifacts=has_conflict_artifacts,
        has_conflict_markers=has_conflict_markers,
        sha_values=sha_values,
    )
    return res, None


def run_audit(
    input_dir: Path,
    expected_flavors: Sequence[str],
    expected_vpn_states: Sequence[str],
    expected_nvapi_states: Sequence[str],
    expected_fsr_modes: Sequence[str],
) -> AuditResult:
    scenarios: List[ScenarioResult] = []
    malformed_labels: List[Tuple[Path, str]] = []
    failures: List[str] = []

    for meta_file in sorted(input_dir.glob("*/scenario_meta.txt")):
        scenario_dir = meta_file.parent
        scenario, malformed = load_scenario(scenario_dir)
        if malformed:
            malformed_labels.append(malformed)
            continue
        assert scenario is not None
        scenarios.append(scenario)

        if not scenario.has_conflict_artifacts:
            failures.append(
                f"{scenario.label}: missing conflict artifacts "
                f"(expected logcat-runtime-conflict-contour.txt and runtime-conflict-contour.summary.txt)"
            )
        if not scenario.has_conflict_markers:
            failures.append(f"{scenario.label}: conflict markers not found in scenario artifacts")
        if not scenario.stable_sha:
            uniq = sorted(set(scenario.sha_values))
            uniq_str = ",".join(uniq) if uniq else "none"
            failures.append(
                f"{scenario.label}: unstable or missing AERO_LIBRARY_CONFLICT_SHA256 (unique={uniq_str})"
            )

    observed_flavors = {s.flavor for s in scenarios}
    observed_vpn_states = {s.vpn_state for s in scenarios}
    observed_nvapi_states = {s.nvapi_state for s in scenarios}
    observed_fsr_modes = {s.fsr_mode for s in scenarios}

    missing_flavors = [x for x in expected_flavors if x not in observed_flavors]
    missing_vpn_states = [x for x in expected_vpn_states if x not in observed_vpn_states]
    missing_nvapi_states = [x for x in expected_nvapi_states if x not in observed_nvapi_states]
    missing_fsr_modes = [x for x in expected_fsr_modes if x not in observed_fsr_modes]

    expected_combinations = set(
        itertools.product(
            expected_flavors,
            expected_vpn_states,
            expected_nvapi_states,
            expected_fsr_modes,
        )
    )
    observed_combinations = {
        (s.flavor, s.vpn_state, s.nvapi_state, s.fsr_mode) for s in scenarios
    }
    missing_combinations = sorted(expected_combinations - observed_combinations)

    if malformed_labels:
        failures.append(f"malformed scenario labels: {len(malformed_labels)}")
    if missing_flavors:
        failures.append(f"missing flavor coverage: {','.join(missing_flavors)}")
    if missing_vpn_states:
        failures.append(f"missing vpn coverage: {','.join(missing_vpn_states)}")
    if missing_nvapi_states:
        failures.append(f"missing nvapi coverage: {','.join(missing_nvapi_states)}")
    if missing_fsr_modes:
        failures.append(f"missing fsr coverage: {','.join(missing_fsr_modes)}")
    if missing_combinations:
        failures.append(f"missing matrix combinations: {len(missing_combinations)}")

    return AuditResult(
        scenarios=scenarios,
        malformed_labels=malformed_labels,
        missing_combinations=missing_combinations,
        missing_flavors=missing_flavors,
        missing_vpn_states=missing_vpn_states,
        missing_nvapi_states=missing_nvapi_states,
        missing_fsr_modes=missing_fsr_modes,
        failures=failures,
    )


def render_markdown(result: AuditResult, strict: bool) -> str:
    total = len(result.scenarios)
    status = "pass" if not result.failures else "fail"

    lines: List[str] = []
    lines.append("# RC-005 Device Matrix Audit")
    lines.append("")
    lines.append(f"- status: `{status}`")
    lines.append(f"- strict: `{1 if strict else 0}`")
    lines.append(f"- scenarios: `{total}`")
    lines.append(f"- malformed_labels: `{len(result.malformed_labels)}`")
    lines.append(f"- missing_combinations: `{len(result.missing_combinations)}`")
    lines.append("")

    lines.append("## Findings")
    if not result.failures:
        lines.append("")
        lines.append("- none")
    else:
        lines.append("")
        for issue in result.failures:
            lines.append(f"- {issue}")

    lines.append("")
    lines.append("## Scenario Summary")
    lines.append("")
    lines.append("| label | flavor | vpn | nvapi | fsr | conflict_artifacts | conflict_markers | sha_unique |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for s in sorted(result.scenarios, key=lambda x: x.label):
        sha_unique = len(set(s.sha_values))
        lines.append(
            "| {label} | {flavor} | {vpn} | {nvapi} | {fsr} | {art} | {markers} | {sha_unique} |".format(
                label=s.label,
                flavor=s.flavor,
                vpn=s.vpn_state,
                nvapi=s.nvapi_state,
                fsr=s.fsr_mode,
                art="1" if s.has_conflict_artifacts else "0",
                markers="1" if s.has_conflict_markers else "0",
                sha_unique=sha_unique,
            )
        )

    if result.malformed_labels:
        lines.append("")
        lines.append("## Malformed Labels")
        lines.append("")
        for path, label in result.malformed_labels:
            lines.append(f"- {path}: `{label}`")

    if result.missing_combinations:
        lines.append("")
        lines.append("## Missing Combinations")
        lines.append("")
        lines.append("| flavor | vpn | nvapi | fsr |")
        lines.append("| --- | --- | --- | --- |")
        for flavor, vpn_state, nvapi_state, fsr_mode in result.missing_combinations:
            lines.append(f"| {flavor} | {vpn_state} | {nvapi_state} | {fsr_mode} |")

    lines.append("")
    return "\n".join(lines)


def write_output(path: str, payload: str) -> None:
    if path == "-":
        sys.stdout.write(payload)
        return
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(payload, encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate RC-005 device matrix artifacts")
    parser.add_argument("--input", required=True, help="Root artifact directory")
    parser.add_argument("--output", default="-", help="Markdown report path or '-' for stdout")
    parser.add_argument(
        "--expected-flavors",
        default="wine11,protonwine10,protonge10,gamenative104",
        help="Comma-separated flavor labels",
    )
    parser.add_argument(
        "--expected-vpn-states",
        default="off,on",
        help="Comma-separated vpn states",
    )
    parser.add_argument(
        "--expected-nvapi-states",
        default="0,1",
        help="Comma-separated nvapi requested states",
    )
    parser.add_argument(
        "--expected-fsr-modes",
        default="quality,balanced,performance,ultra",
        help="Comma-separated Proton FSR modes",
    )
    parser.add_argument("--strict", action="store_true", help="Exit non-zero on any finding")
    return parser


def main(argv: Sequence[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    input_dir = Path(args.input)
    if not input_dir.is_dir():
        parser.error(f"input path is not a directory: {input_dir}")

    result = run_audit(
        input_dir=input_dir,
        expected_flavors=parse_csv_list(args.expected_flavors),
        expected_vpn_states=parse_csv_list(args.expected_vpn_states),
        expected_nvapi_states=parse_csv_list(args.expected_nvapi_states),
        expected_fsr_modes=parse_csv_list(args.expected_fsr_modes),
    )

    markdown = render_markdown(result, strict=args.strict)
    write_output(args.output, markdown)

    if args.strict and result.failures:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
