#!/usr/bin/env python3
"""Audit GameNative patchset ownership and report overlap risks.

This script keeps the patch pipeline compact by checking that files owned by the
manifest patchset are not also patched ad-hoc in other CI scripts.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
from collections import Counter, defaultdict
from pathlib import Path
import re
import sys
from typing import Dict, Iterable, List, Set, Tuple

ALLOWED_OWNERSHIP_FILES = {
    "ci/gamenative/apply-android-patchset.sh",
    "ci/validation/check-gamenative-patch-contract.sh",
}

SCRIPT_SUFFIXES = {".sh", ".py", ".yml", ".yaml"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit GN patchset ownership overlap")
    parser.add_argument(
        "--manifest",
        default="ci/gamenative/patchsets/28c3a06/manifest.tsv",
        help="Path to manifest TSV",
    )
    parser.add_argument(
        "--patch-root",
        default="ci/gamenative/patchsets/28c3a06/android/patches",
        help="Directory with .patch files referenced by manifest",
    )
    parser.add_argument(
        "--scan-root",
        default="ci",
        help="Root path to scan for duplicate ownership",
    )
    parser.add_argument(
        "--output",
        default="-",
        help="Output markdown path (default: stdout)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero if ownership overlaps are detected",
    )
    return parser.parse_args()


def read_manifest(path: Path) -> List[Dict[str, str]]:
    if not path.is_file():
        raise FileNotFoundError(f"manifest not found: {path}")
    rows: List[Dict[str, str]] = []
    with path.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        for row in reader:
            row = {k: (v or "").strip() for k, v in row.items()}
            if not row.get("patch") or row["patch"].startswith("#"):
                continue
            rows.append(row)
    return rows


def parse_patch_files_changed(path: Path) -> Set[str]:
    files: Set[str] = set()
    if not path.is_file():
        return files
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not line.startswith("diff --git "):
            continue
        parts = line.split()
        if len(parts) < 4:
            continue
        a_path = parts[2]
        if a_path.startswith("a/"):
            a_path = a_path[2:]
        if a_path != "/dev/null":
            files.add(a_path)
    return files


def build_patch_ownership(rows: Iterable[Dict[str, str]], patch_root: Path) -> Tuple[Dict[str, Set[str]], Dict[str, Set[str]]]:
    patch_to_files: Dict[str, Set[str]] = {}
    file_to_patches: Dict[str, Set[str]] = defaultdict(set)
    for row in rows:
        patch_name = row["patch"]
        changed = parse_patch_files_changed(patch_root / patch_name)
        patch_to_files[patch_name] = changed
        for rel_file in changed:
            file_to_patches[rel_file].add(patch_name)
    return patch_to_files, file_to_patches


def iter_scan_files(scan_root: Path) -> Iterable[Path]:
    for path in scan_root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix not in SCRIPT_SUFFIXES:
            continue
        yield path


def find_overlap_references(repo_root: Path, scan_root: Path, owned_files: Iterable[str]) -> Dict[str, Set[str]]:
    owned = sorted(set(owned_files))
    overlaps: Dict[str, Set[str]] = defaultdict(set)

    for candidate in iter_scan_files(scan_root):
        rel_candidate = candidate.relative_to(repo_root).as_posix()
        if rel_candidate in ALLOWED_OWNERSHIP_FILES:
            continue
        if rel_candidate.startswith("ci/gamenative/patchsets/"):
            continue

        text = candidate.read_text(encoding="utf-8", errors="ignore")
        for rel_owned in owned:
            if rel_owned in text:
                overlaps[rel_owned].add(rel_candidate)
    return overlaps


def action_stats(rows: Iterable[Dict[str, str]], target_key: str) -> Counter:
    ctr: Counter = Counter()
    for row in rows:
        action = row.get(target_key, "")
        if not action:
            action = "(empty)"
        ctr[action] += 1
    return ctr


def required_mismatches(rows: Iterable[Dict[str, str]]) -> List[str]:
    issues: List[str] = []
    for row in rows:
        patch = row["patch"]
        required = row.get("required", "").lower()
        for target, key in (("wine", "wine_action"), ("protonge", "protonge_action")):
            required_for_target = required in {"both", "all", target}
            if required_for_target and row.get(key, "") == "skip":
                issues.append(f"{patch}: required={required} but {target} action is skip")
    return issues


def render_markdown(
    rows: List[Dict[str, str]],
    patch_to_files: Dict[str, Set[str]],
    overlaps: Dict[str, Set[str]],
    mismatches: List[str],
) -> str:
    generated = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    total_patches = len(rows)
    unique_files = len({f for files in patch_to_files.values() for f in files})

    wine_stats = action_stats(rows, "wine_action")
    ge_stats = action_stats(rows, "protonge_action")

    lines: List[str] = []
    lines.append("# GameNative Patchset Conflict Audit")
    lines.append("")
    lines.append(f"Generated: `{generated}`")
    lines.append("")
    lines.append("## Scope")
    lines.append("")
    lines.append(f"- Manifest entries: `{total_patches}`")
    lines.append(f"- Unique owned source files: `{unique_files}`")
    lines.append("- Ownership contract: manifest + `apply-android-patchset.sh` is the single source of truth")
    lines.append("")

    lines.append("## Action Distribution")
    lines.append("")
    lines.append("### wine")
    lines.append("")
    for action, count in sorted(wine_stats.items()):
        lines.append(f"- `{action}`: {count}")
    lines.append("")
    lines.append("### protonge")
    lines.append("")
    for action, count in sorted(ge_stats.items()):
        lines.append(f"- `{action}`: {count}")
    lines.append("")

    lines.append("## Required Mapping Sanity")
    lines.append("")
    if mismatches:
        lines.append("Detected required/action mismatches:")
        for issue in mismatches:
            lines.append(f"- {issue}")
    else:
        lines.append("- No required/action mismatch detected in manifest.")
    lines.append("")

    lines.append("## Potential Ownership Overlaps")
    lines.append("")
    if overlaps:
        lines.append("The files below are owned by GN patchset and are also referenced elsewhere in CI scripts:")
        lines.append("")
        for owned_file in sorted(overlaps):
            refs = ", ".join(f"`{r}`" for r in sorted(overlaps[owned_file]))
            lines.append(f"- `{owned_file}` -> {refs}")
    else:
        lines.append("- No overlapping ownership references detected outside allowed files.")
    lines.append("")

    lines.append("## Next Actions")
    lines.append("")
    lines.append("- Keep patch ownership centralized in `ci/gamenative/apply-android-patchset.sh`.")
    lines.append("- Use workflow input `gn_patchset_enable` for full vs normalize-only operation.")
    lines.append("- If overlap appears, remove ad-hoc patching from per-package scripts instead of duplicating fixes.")
    lines.append("")

    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[2]
    manifest = (repo_root / args.manifest).resolve()
    patch_root = (repo_root / args.patch_root).resolve()
    scan_root = (repo_root / args.scan_root).resolve()

    rows = read_manifest(manifest)
    patch_to_files, file_to_patches = build_patch_ownership(rows, patch_root)
    overlaps = find_overlap_references(repo_root, scan_root, file_to_patches.keys())
    mismatches = required_mismatches(rows)

    markdown = render_markdown(rows, patch_to_files, overlaps, mismatches)

    if args.output == "-":
        print(markdown)
    else:
        out = (repo_root / args.output).resolve()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(markdown + "\n", encoding="utf-8")
        print(f"wrote {out}")

    if args.strict and overlaps:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
