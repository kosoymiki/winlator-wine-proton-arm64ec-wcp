#!/usr/bin/env python3
"""Reflective audit for Winlator patch stack stability."""

from __future__ import annotations

import argparse
import datetime as dt
from collections import defaultdict
from pathlib import Path
import re
import sys
from typing import Dict, Iterable, List, Sequence, Set, Tuple

KEY_HOTSPOT_GROUPS: Sequence[Tuple[str, Tuple[str, ...]]] = (
    (
        "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java",
        (
            "app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java",
            "app/src/main/java/com/winlator/XServerDisplayActivity.java",
        ),
    ),
    (
        "app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java",
        (
            "app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java",
            "app/src/main/java/com/winlator/core/GuestProgramLauncherComponent.java",
        ),
    ),
    (
        "app/src/main/java/com/winlator/cmod/container/Container.java",
        (
            "app/src/main/java/com/winlator/cmod/container/Container.java",
            "app/src/main/java/com/winlator/container/Container.java",
        ),
    ),
    (
        "app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java",
        (
            "app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java",
            "app/src/main/java/com/winlator/container/ContainerDetailFragment.java",
        ),
    ),
    (
        "app/src/main/java/com/winlator/cmod/ContentsFragment.java",
        (
            "app/src/main/java/com/winlator/cmod/ContentsFragment.java",
            "app/src/main/java/com/winlator/contents/ContentsFragment.java",
        ),
    ),
    (
        "app/src/main/java/com/winlator/cmod/contents/ContentsManager.java",
        (
            "app/src/main/java/com/winlator/cmod/contents/ContentsManager.java",
            "app/src/main/java/com/winlator/contents/ContentsManager.java",
        ),
    ),
    (
        "app/src/main/java/com/winlator/cmod/AdrenotoolsFragment.java",
        (
            "app/src/main/java/com/winlator/cmod/AdrenotoolsFragment.java",
            "app/src/main/java/com/winlator/contents/AdrenotoolsFragment.java",
        ),
    ),
    (
        "app/src/main/java/com/winlator/cmod/contents/AdrenotoolsManager.java",
        (
            "app/src/main/java/com/winlator/cmod/contents/AdrenotoolsManager.java",
            "app/src/main/java/com/winlator/contents/AdrenotoolsManager.java",
        ),
    ),
)

PATCH_PREFIX_RE = re.compile(r"^(?P<prefix>\d{4})-")
KEY_HOTSPOT_ALIASES = {alias for _, aliases in KEY_HOTSPOT_GROUPS for alias in aliases}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate reflective overlap audit for Winlator patch stack"
    )
    parser.add_argument(
        "--patch-dir",
        default="ci/winlator/patches",
        help="Directory containing ordered *.patch files",
    )
    parser.add_argument(
        "--output",
        default="docs/PATCH_STACK_REFLECTIVE_AUDIT.md",
        help="Markdown output path ('-' for stdout)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero when numbering contract violations are found",
    )
    return parser.parse_args()


def parse_patch_stats(path: Path) -> Tuple[Set[str], int, int]:
    files: Set[str] = set()
    added = 0
    removed = 0

    for raw_line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw_line.rstrip("\n")
        if line.startswith("diff --git "):
            parts = line.split()
            if len(parts) >= 4:
                rel = parts[2]
                if rel.startswith("a/"):
                    rel = rel[2:]
                if rel != "/dev/null":
                    files.add(rel)
            continue
        if line.startswith("+++ ") or line.startswith("--- "):
            continue
        if line.startswith("+"):
            added += 1
        elif line.startswith("-"):
            removed += 1

    return files, added, removed


def classify_risk(file_path: str, touch_count: int) -> str:
    if file_path in KEY_HOTSPOT_ALIASES and touch_count >= 4:
        return "critical"
    if touch_count >= 8:
        return "critical"
    if touch_count >= 6:
        return "high"
    if touch_count >= 3:
        return "medium"
    return "low"


def parse_prefix_issues(patches: Iterable[Path]) -> Tuple[Dict[str, List[str]], List[str]]:
    by_prefix: Dict[str, List[str]] = defaultdict(list)
    unnumbered: List[str] = []
    for patch in patches:
        match = PATCH_PREFIX_RE.match(patch.name)
        if not match:
            unnumbered.append(patch.name)
            continue
        by_prefix[match.group("prefix")].append(patch.name)

    duplicates: Dict[str, List[str]] = {
        prefix: sorted(names)
        for prefix, names in by_prefix.items()
        if len(names) > 1
    }
    return duplicates, sorted(unnumbered)


def render_markdown(
    patches: Sequence[Path],
    patch_to_files: Dict[str, Set[str]],
    patch_stats: Dict[str, Tuple[int, int]],
    file_to_patches: Dict[str, List[str]],
    duplicates: Dict[str, List[str]],
    unnumbered: List[str],
) -> str:
    generated = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    patch_count = len(patches)
    unique_files = len(file_to_patches)
    total_added = sum(stats[0] for stats in patch_stats.values())
    total_removed = sum(stats[1] for stats in patch_stats.values())
    avg_files_per_patch = (
        sum(len(files) for files in patch_to_files.values()) / patch_count if patch_count else 0
    )

    hotspot_rows = sorted(
        ((path, len(set(names)), sorted(set(names))) for path, names in file_to_patches.items()),
        key=lambda row: (-row[1], row[0]),
    )

    risk_buckets: Dict[str, List[Tuple[str, int, List[str]]]] = defaultdict(list)
    for path, count, patch_names in hotspot_rows:
        risk = classify_risk(path, count)
        if risk == "low":
            continue
        risk_buckets[risk].append((path, count, patch_names))

    lines: List[str] = []
    lines.append("# Winlator Patch Stack Reflective Audit")
    lines.append("")
    lines.append(f"Generated: `{generated}`")
    lines.append("")
    lines.append("## Snapshot")
    lines.append("")
    lines.append(f"- Patch count: `{patch_count}`")
    lines.append(f"- Unique touched source files: `{unique_files}`")
    lines.append(f"- Diff volume across stack: `+{total_added} / -{total_removed}`")
    lines.append(f"- Mean files touched per patch: `{avg_files_per_patch:.2f}`")
    lines.append("")

    lines.append("## Numbering Contract")
    lines.append("")
    if duplicates or unnumbered:
        if duplicates:
            lines.append("- Duplicate numeric prefixes detected:")
            for prefix, names in sorted(duplicates.items()):
                lines.append(f"  - `{prefix}` -> {', '.join(f'`{name}`' for name in names)}")
        if unnumbered:
            lines.append("- Patches without `NNNN-` prefix:")
            for name in unnumbered:
                lines.append(f"  - `{name}`")
    else:
        lines.append("- Numbering contract is clean (`NNNN-` unique prefixes).")
    lines.append("")

    lines.append("## High-Overlap Hotspots")
    lines.append("")
    if not hotspot_rows:
        lines.append("- No patch files found in stack.")
        lines.append("")
    else:
        top_rows = hotspot_rows[:15]
        for path, count, patch_names in top_rows:
            lines.append(f"- `{path}` touched by `{count}` patches")
            lines.append(f"  - {', '.join(f'`{name}`' for name in patch_names[:8])}" + (" ..." if len(patch_names) > 8 else ""))
        lines.append("")

    lines.append("## Risk Buckets")
    lines.append("")
    for risk in ("critical", "high", "medium"):
        entries = risk_buckets.get(risk, [])
        if not entries:
            lines.append(f"- `{risk}`: none")
            continue
        lines.append(f"- `{risk}` ({len(entries)} files):")
        for path, count, _ in entries[:8]:
            lines.append(f"  - `{path}` ({count} patches)")
    lines.append("")

    lines.append("## Key Runtime Integration Coverage")
    lines.append("")
    for canonical, aliases in KEY_HOTSPOT_GROUPS:
        covered_patches: Set[str] = set()
        for alias in aliases:
            covered_patches.update(file_to_patches.get(alias, []))
        count = len(covered_patches)
        marker = "yes" if count else "no"
        lines.append(f"- `{canonical}` -> touched: `{marker}` ({count} patches)")
    lines.append("")

    lines.append("## Action Rules")
    lines.append("")
    lines.append("- Keep runtime launch flow changes in smallest possible follow-up patches.")
    lines.append("- For files in `critical` bucket, run `ci/winlator/check-patch-stack.sh` before push.")
    lines.append("- Any new patch touching `XServerDisplayActivity` or `GuestProgramLauncherComponent` must include forensic markers and fallback reason codes.")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[2]
    patch_dir = (repo_root / args.patch_dir).resolve()
    if not patch_dir.is_dir():
        raise FileNotFoundError(f"patch dir not found: {patch_dir}")

    patches = sorted(patch_dir.glob("*.patch"))
    patch_to_files: Dict[str, Set[str]] = {}
    patch_stats: Dict[str, Tuple[int, int]] = {}
    file_to_patches: Dict[str, List[str]] = defaultdict(list)

    for patch in patches:
        touched_files, added, removed = parse_patch_stats(patch)
        patch_to_files[patch.name] = touched_files
        patch_stats[patch.name] = (added, removed)
        for rel_file in touched_files:
            file_to_patches[rel_file].append(patch.name)

    duplicates, unnumbered = parse_prefix_issues(patches)
    markdown = render_markdown(
        patches=patches,
        patch_to_files=patch_to_files,
        patch_stats=patch_stats,
        file_to_patches=file_to_patches,
        duplicates=duplicates,
        unnumbered=unnumbered,
    )

    if args.output == "-":
        print(markdown)
    else:
        out_path = (repo_root / args.output).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(markdown + "\n", encoding="utf-8")
        print(f"wrote {out_path}")

    if args.strict and (duplicates or unnumbered):
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
