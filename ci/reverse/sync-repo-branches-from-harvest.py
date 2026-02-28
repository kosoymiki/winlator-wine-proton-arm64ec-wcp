#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from typing import Dict, List, Tuple


def load_resolved_branches(report_path: Path) -> Dict[str, str]:
    payload = json.loads(report_path.read_text(encoding="utf-8"))
    out: Dict[str, str] = {}
    for row in (payload.get("repos") or []):
        if not isinstance(row, dict):
            continue
        alias = str(row.get("alias") or "").strip()
        if not alias:
            continue
        resolved = str(row.get("resolved_branch") or row.get("branch") or "").strip()
        if resolved:
            out[alias] = resolved
    return out


def sync_repo_file(repo_file: Path, branches: Dict[str, str], write_changes: bool) -> List[Tuple[str, str, str]]:
    rows = json.loads(repo_file.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise RuntimeError(f"{repo_file} must be an array")
    changed: List[Tuple[str, str, str]] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        alias = str(row.get("alias") or "").strip()
        if not alias:
            continue
        resolved = branches.get(alias, "").strip()
        if not resolved:
            continue
        current = str(row.get("branch") or "").strip()
        if current != resolved:
            row["branch"] = resolved
            changed.append((alias, current, resolved))
    if write_changes and changed:
        repo_file.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync online_intake_repos branch pins from harvest transfer report")
    parser.add_argument("--repo-file", default="ci/reverse/online_intake_repos.json")
    parser.add_argument("--report-file", default="docs/reverse/online-intake/harvest/transfer-report.json")
    parser.add_argument("--write", choices=("0", "1"), default="1")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    repo_file = (repo_root / args.repo_file).resolve()
    report_file = (repo_root / args.report_file).resolve()

    branches = load_resolved_branches(report_file)
    changed = sync_repo_file(repo_file, branches, write_changes=(args.write == "1"))

    mode = "write" if args.write == "1" else "dry-run"
    print(f"[branch-sync] mode={mode} repo_file={repo_file}")
    print(f"[branch-sync] report_file={report_file}")
    print(f"[branch-sync] resolved_aliases={len(branches)} changed={len(changed)}")
    for alias, current, resolved in changed:
        old = current or "<none>"
        print(f"[branch-sync] {alias}: {old} -> {resolved}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
