#!/usr/bin/env python3
"""Runtime contract audit for Winlator patch stack."""

from __future__ import annotations

import argparse
import datetime as dt
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
import re
import sys
from typing import Dict, Iterable, List, Sequence, Tuple


@dataclass(frozen=True)
class TokenRule:
    name: str
    patterns: Tuple[str, ...]


@dataclass(frozen=True)
class GroupRule:
    name: str
    aliases: Tuple[str, ...]
    checks: Tuple[TokenRule, ...]


GROUP_RULES: Tuple[GroupRule, ...] = (
    GroupRule(
        name="XServerDisplayActivity",
        aliases=(
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java",
            "app/src/main/java/com/winlator/XServerDisplayActivity.java",
        ),
        checks=(
            TokenRule("telemetry_calls", (r"ForensicLogger\.logEvent\(",)),
            TokenRule("reason_markers", (r'"reason"\s*,', r"_reason", r"GUARD_REASON")),
            TokenRule("fallback_guardrails", (r"fallback", r"deferred", r"guard")),
            TokenRule(
                "external_signal_inputs",
                (r"WINLATOR_SIGNAL_INPUT_ROUTE", r"WINLATOR_SIGNAL_INPUT_LAUNCH_KIND", r"RUNTIME_SIGNAL_INPUTS_PREPARED"),
            ),
            TokenRule(
                "launch_env_signal_fields",
                (r"signal_input_route", r"signal_input_launch_kind", r"signal_input_precheck_reason"),
            ),
            TokenRule("contract_helper_usage", (r"RuntimeSignalContract\.",)),
        ),
    ),
    GroupRule(
        name="GuestProgramLauncherComponent",
        aliases=(
            "app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java",
            "app/src/main/java/com/winlator/core/GuestProgramLauncherComponent.java",
        ),
        checks=(
            TokenRule("telemetry_calls", (r"ForensicLogger\.logEvent\(",)),
            TokenRule("reason_markers", (r'"reason"\s*,', r"_reason", r"GUARD_REASON")),
            TokenRule(
                "runtime_contract_markers",
                (r"WINLATOR_RUNTIME_PRESET_GUARD_REASON", r"WINLATOR_UPSCALER_BINDING_GUARD_REASON"),
            ),
            TokenRule(
                "external_signal_markers",
                (r"WINLATOR_SIGNAL_POLICY", r"WINLATOR_SIGNAL_SOURCES", r"RUNTIME_SIGNAL_POLICY_APPLIED"),
            ),
            TokenRule("contract_helper_usage", (r"RuntimeSignalContract\.",)),
        ),
    ),
    GroupRule(
        name="RuntimeSignalContract",
        aliases=(
            "app/src/main/java/com/winlator/cmod/contract/RuntimeSignalContract.java",
        ),
        checks=(
            TokenRule("policy_markers_constants", (r"WINLATOR_SIGNAL_POLICY", r"WINLATOR_SIGNAL_DECISION_HASH")),
            TokenRule("input_markers_constants", (r"WINLATOR_SIGNAL_INPUT_ROUTE", r"WINLATOR_SIGNAL_INPUT_PRECHECK_FALLBACK")),
            TokenRule("policy_hashing", (r"sha1Hex", r"MessageDigest")),
        ),
    ),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate runtime forensic contract tokens in Winlator patch stack"
    )
    parser.add_argument(
        "--patch-dir",
        default="ci/winlator/patches",
        help="Directory with ordered *.patch files",
    )
    parser.add_argument(
        "--output",
        default="docs/PATCH_STACK_RUNTIME_CONTRACT_AUDIT.md",
        help="Markdown output file ('-' for stdout)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero if any contract check is missing",
    )
    return parser.parse_args()


def parse_added_lines(
    patch_path: Path, group_aliases: Dict[str, str]
) -> Dict[str, List[Tuple[str, str]]]:
    group_lines: Dict[str, List[Tuple[str, str]]] = defaultdict(list)
    current_file = ""

    for raw_line in patch_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw_line.rstrip("\n")
        if line.startswith("diff --git "):
            parts = line.split()
            current_file = ""
            if len(parts) >= 4:
                rel = parts[2]
                if rel.startswith("a/"):
                    rel = rel[2:]
                current_file = group_aliases.get(rel, "")
            continue
        if not current_file:
            continue
        if line.startswith("+++ ") or line.startswith("--- "):
            continue
        if line.startswith("+"):
            group_lines[current_file].append((patch_path.name, line[1:]))

    return group_lines


def audit_groups(
    patch_dir: Path,
) -> Tuple[Dict[str, Dict[str, List[str]]], Dict[str, Dict[str, str]], int]:
    group_aliases: Dict[str, str] = {}
    for group in GROUP_RULES:
        for alias in group.aliases:
            group_aliases[alias] = group.name

    grouped_lines: Dict[str, List[Tuple[str, str]]] = defaultdict(list)
    patch_count = 0
    for patch_path in sorted(patch_dir.glob("*.patch")):
        patch_count += 1
        added = parse_added_lines(patch_path, group_aliases)
        for group_name, lines in added.items():
            grouped_lines[group_name].extend(lines)

    hits: Dict[str, Dict[str, List[str]]] = defaultdict(lambda: defaultdict(list))
    status: Dict[str, Dict[str, str]] = defaultdict(dict)

    for group in GROUP_RULES:
        lines = grouped_lines.get(group.name, [])
        for token_rule in group.checks:
            found_patches: List[str] = []
            compiled = [re.compile(pattern, re.IGNORECASE) for pattern in token_rule.patterns]
            for patch_name, line in lines:
                if any(regex.search(line) for regex in compiled):
                    found_patches.append(patch_name)
            dedup = sorted(set(found_patches))
            hits[group.name][token_rule.name] = dedup
            status[group.name][token_rule.name] = "ok" if dedup else "missing"

    return hits, status, patch_count


def render_markdown(
    hits: Dict[str, Dict[str, List[str]]],
    status: Dict[str, Dict[str, str]],
    patch_count: int,
) -> str:
    generated = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    lines: List[str] = []
    lines.append("# Winlator Patch Stack Runtime Contract Audit")
    lines.append("")
    lines.append(f"Generated: `{generated}`")
    lines.append("")
    lines.append("## Scope")
    lines.append("")
    lines.append(f"- Patch files scanned: `{patch_count}`")
    lines.append("- Target groups: `XServerDisplayActivity`, `GuestProgramLauncherComponent`, `RuntimeSignalContract`")
    lines.append("- Contract: forensic telemetry + reason markers + runtime guard markers")
    lines.append("")
    lines.append("## Results")
    lines.append("")

    missing_total = 0
    for group in GROUP_RULES:
        lines.append(f"### {group.name}")
        lines.append("")
        for token_rule in group.checks:
            st = status.get(group.name, {}).get(token_rule.name, "missing")
            refs = hits.get(group.name, {}).get(token_rule.name, [])
            if st != "ok":
                missing_total += 1
                lines.append(f"- `{token_rule.name}`: `missing`")
                continue
            ref_preview = ", ".join(f"`{name}`" for name in refs[:6])
            suffix = " ..." if len(refs) > 6 else ""
            lines.append(f"- `{token_rule.name}`: `ok` ({len(refs)} patches) -> {ref_preview}{suffix}")
        lines.append("")

    lines.append("## Contract Summary")
    lines.append("")
    if missing_total:
        lines.append(f"- Missing checks: `{missing_total}`")
        lines.append("- Action: add follow-up patch preserving forensic reason-codes and runtime markers.")
    else:
        lines.append("- All required runtime-contract checks are present in current patch stack.")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[2]
    patch_dir = (repo_root / args.patch_dir).resolve()
    if not patch_dir.is_dir():
        raise FileNotFoundError(f"patch dir not found: {patch_dir}")

    hits, status, patch_count = audit_groups(patch_dir)
    markdown = render_markdown(hits, status, patch_count)

    if args.output == "-":
        print(markdown)
    else:
        out_path = (repo_root / args.output).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(markdown + "\n", encoding="utf-8")
        print(f"wrote {out_path}")

    missing = 0
    for group in GROUP_RULES:
        for token_rule in group.checks:
            if status.get(group.name, {}).get(token_rule.name) != "ok":
                missing += 1
    if args.strict and missing:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
