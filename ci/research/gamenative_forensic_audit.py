#!/usr/bin/env python3
"""Generate a repeatable GameNative branch/PR forensic audit report."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote


DEFAULT_REPO = "utkarshdalal/GameNative"
DEFAULT_REPORT = Path("docs/GAMENATIVE_BRANCH_AUDIT_LOG.md")
DEFAULT_OUT_DIR = Path("docs/research")


@dataclass
class CompareResult:
    branch: str
    topic: str
    risk: str
    status: str
    ahead_by: int
    behind_by: int
    total_commits: int
    files_changed: int
    portability: str
    changed_dirs: list[str]
    changed_files_sample: list[str]
    compare_url: str
    api_error: str | None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=DEFAULT_REPO, help="GitHub repo in owner/name format")
    parser.add_argument("--report", default=str(DEFAULT_REPORT), help="Main markdown report path")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR), help="Output directory for raw files")
    parser.add_argument(
        "--branch-limit",
        type=int,
        default=0,
        help="Optional cap for branches compared (0 means all)",
    )
    parser.add_argument(
        "--max-prs",
        type=int,
        default=120,
        help="Maximum PRs to include in report snapshots",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=45,
        help="Timeout in seconds for each gh api call",
    )
    return parser.parse_args()


def log(msg: str) -> None:
    print(f"[gamenative-audit] {msg}", file=sys.stderr)


def parse_json_documents(raw: str) -> list[Any]:
    docs: list[Any] = []
    decoder = json.JSONDecoder()
    idx = 0
    size = len(raw)
    while idx < size:
        while idx < size and raw[idx].isspace():
            idx += 1
        if idx >= size:
            break
        doc, end_idx = decoder.raw_decode(raw, idx)
        docs.append(doc)
        idx = end_idx
    return docs


def run_gh_api(endpoint: str, *, paginate: bool, timeout: int, retries: int = 2) -> Any:
    cmd = ["gh", "api", endpoint]
    if paginate:
        cmd.append("--paginate")

    env = os.environ.copy()
    env.setdefault("GH_PAGER", "cat")

    last_error = ""
    for attempt in range(1, retries + 1):
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            env=env,
            check=False,
        )
        if proc.returncode == 0:
            docs = parse_json_documents(proc.stdout)
            if not docs:
                return [] if paginate else {}
            if paginate:
                merged: list[Any] = []
                for doc in docs:
                    if isinstance(doc, list):
                        merged.extend(doc)
                    else:
                        merged.append(doc)
                return merged
            return docs[0]

        last_error = (proc.stderr or "gh api failed").strip().splitlines()[-1]
        if attempt < retries:
            time.sleep(0.6 * attempt)

    raise RuntimeError(f"{endpoint}: {last_error}")


def classify_topic(branch_name: str) -> str:
    name = branch_name.lower()
    if any(k in name for k in ("glibc", "bionic", "targetsdk", "sdk", "wow64", "fex", "box64")):
        return "runtime"
    if any(k in name for k in ("driver", "adreno", "vulkan", "mesa", "dxvk", "vkd3d", "render")):
        return "graphics"
    if any(k in name for k in ("cloud", "manifest", "download", "repo", "catalog", "sync", "cdn")):
        return "content-delivery"
    if any(k in name for k in ("ui", "theme", "dialog", "layout", "compose", "settings")):
        return "ui"
    if any(k in name for k in ("audio", "input", "touch", "gamepad", "controller")):
        return "io"
    if any(k in name for k in ("perf", "opt", "benchmark", "latency", "speed")):
        return "performance"
    if any(k in name for k in ("fix", "bug", "hotfix", "crash", "patch")):
        return "bugfix"
    if any(k in name for k in ("release", "version", "tag")):
        return "release"
    return "misc"


def classify_risk(ahead: int, behind: int, files_changed: int, status: str, api_error: str | None) -> str:
    if api_error:
        return "unknown"
    if status == "identical":
        return "low"
    if behind >= 350 or files_changed >= 220 or ahead >= 220:
        return "high"
    if behind >= 120 or files_changed >= 70 or ahead >= 60:
        return "medium"
    return "low"


def classify_portability(
    *, status: str, ahead: int, behind: int, files_changed: int, api_error: str | None
) -> str:
    if api_error:
        return "manual-inspection-required"
    if status == "identical":
        return "already-in-default"
    if behind >= 250:
        return "rebase-first"
    if files_changed >= 160:
        return "manual-port-only"
    if ahead <= 12 and behind <= 45 and files_changed <= 28:
        return "good-cherry-pick-candidate"
    return "selective-cherry-pick"


def build_changed_dirs(file_paths: list[str], cap: int = 10) -> list[str]:
    counts: Counter[str] = Counter()
    for path in file_paths:
        if "/" in path:
            top = path.split("/", 1)[0]
        else:
            top = path
        counts[top] += 1
    ordered = [f"{name} ({count})" for name, count in counts.most_common(cap)]
    return ordered


def slugify_branch(branch: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", branch).strip("-")
    return slug or "branch"


def collect_branch_compare(
    repo: str,
    default_branch: str,
    branch_name: str,
    *,
    timeout: int,
) -> CompareResult:
    compare_endpoint = (
        f"/repos/{repo}/compare/{quote(default_branch, safe='')}...{quote(branch_name, safe='')}"
    )
    compare_url = f"https://github.com/{repo}/compare/{default_branch}...{branch_name}"

    try:
        data = run_gh_api(compare_endpoint, paginate=False, timeout=timeout)
        files = data.get("files") or []
        file_paths = [f.get("filename", "") for f in files if isinstance(f, dict)]
        ahead = int(data.get("ahead_by") or 0)
        behind = int(data.get("behind_by") or 0)
        status = str(data.get("status") or "unknown")
        total_commits = int(data.get("total_commits") or 0)
        files_changed = int(data.get("files", []) and len(files) or data.get("files_changed") or 0)
        api_error = None
    except Exception as exc:  # noqa: BLE001 - keep audit running on partial failures
        file_paths = []
        ahead = behind = total_commits = files_changed = 0
        status = "error"
        api_error = str(exc)

    topic = classify_topic(branch_name)
    risk = classify_risk(ahead, behind, files_changed, status, api_error)
    portability = classify_portability(
        status=status,
        ahead=ahead,
        behind=behind,
        files_changed=files_changed,
        api_error=api_error,
    )

    return CompareResult(
        branch=branch_name,
        topic=topic,
        risk=risk,
        status=status,
        ahead_by=ahead,
        behind_by=behind,
        total_commits=total_commits,
        files_changed=files_changed,
        portability=portability,
        changed_dirs=build_changed_dirs(file_paths),
        changed_files_sample=file_paths[:24],
        compare_url=compare_url,
        api_error=api_error,
    )


def render_branch_report(
    repo: str,
    default_branch: str,
    generated_at: str,
    result: CompareResult,
) -> str:
    lines: list[str] = []
    lines.append(f"# Branch Audit: `{result.branch}`")
    lines.append("")
    lines.append(f"- Generated (UTC): `{generated_at}`")
    lines.append(f"- Repo: `{repo}`")
    lines.append(f"- Base branch: `{default_branch}`")
    lines.append(f"- Compare URL: {result.compare_url}")
    lines.append("")
    lines.append("## Snapshot")
    lines.append("")
    lines.append(f"- Topic: `{result.topic}`")
    lines.append(f"- Risk: `{result.risk}`")
    lines.append(f"- Portability: `{result.portability}`")
    lines.append(f"- Compare status: `{result.status}`")
    lines.append(f"- Ahead/Behind: `{result.ahead_by}` / `{result.behind_by}`")
    lines.append(f"- Total commits in compare: `{result.total_commits}`")
    lines.append(f"- Files changed (API sample): `{result.files_changed}`")

    if result.api_error:
        lines.append(f"- API note: `{result.api_error}`")

    if result.changed_dirs:
        lines.append("")
        lines.append("## Touched areas")
        lines.append("")
        for item in result.changed_dirs:
            lines.append(f"- {item}")

    if result.changed_files_sample:
        lines.append("")
        lines.append("## File sample")
        lines.append("")
        for path in result.changed_files_sample:
            lines.append(f"- `{path}`")

    lines.append("")
    return "\n".join(lines)


def render_main_report(
    *,
    repo: str,
    repo_info: dict[str, Any],
    generated_at: str,
    branch_results: list[CompareResult],
    prs: list[dict[str, Any]],
) -> str:
    default_branch = repo_info.get("default_branch", "main")
    branch_total = len(branch_results)
    risk_counts = Counter(r.risk for r in branch_results)
    topic_counts = Counter(r.topic for r in branch_results)

    branch_results_sorted = sorted(
        branch_results,
        key=lambda r: (
            {"high": 0, "medium": 1, "low": 2, "unknown": 3}.get(r.risk, 4),
            -r.behind_by,
            -r.files_changed,
        ),
    )

    candidates = [
        r
        for r in branch_results
        if r.portability == "good-cherry-pick-candidate" and r.risk in {"low", "medium"}
    ]

    lines: list[str] = []
    lines.append("# GameNative Branch Audit Log")
    lines.append("")
    lines.append(f"- Generated (UTC): `{generated_at}`")
    lines.append(f"- Source repo: `{repo}`")
    lines.append(f"- Default branch: `{default_branch}`")
    lines.append(f"- Branches audited: `{branch_total}`")
    lines.append(f"- PR sample size: `{len(prs)}`")
    lines.append("")
    lines.append("## Branch risk distribution")
    lines.append("")
    lines.append("| Risk | Count |")
    lines.append("| --- | ---: |")
    for risk in ("high", "medium", "low", "unknown"):
        lines.append(f"| `{risk}` | {risk_counts.get(risk, 0)} |")

    lines.append("")
    lines.append("## Branch topics")
    lines.append("")
    lines.append("| Topic | Count |")
    lines.append("| --- | ---: |")
    for topic, count in topic_counts.most_common():
        lines.append(f"| `{topic}` | {count} |")

    lines.append("")
    lines.append("## Candidate branches for selective backport")
    lines.append("")
    lines.append("| Branch | Topic | Ahead | Behind | Files | Portability |")
    lines.append("| --- | --- | ---: | ---: | ---: | --- |")
    if candidates:
        for result in sorted(candidates, key=lambda r: (r.behind_by, r.files_changed, r.branch))[:24]:
            lines.append(
                f"| `{result.branch}` | `{result.topic}` | {result.ahead_by} | {result.behind_by} "
                f"| {result.files_changed} | `{result.portability}` |"
            )
    else:
        lines.append("| _none_ | - | - | - | - | - |")

    lines.append("")
    lines.append("## High-risk branches (manual study first)")
    lines.append("")
    lines.append("| Branch | Status | Ahead | Behind | Files | Topic |")
    lines.append("| --- | --- | ---: | ---: | ---: | --- |")
    high_rows = [r for r in branch_results_sorted if r.risk == "high"]
    if high_rows:
        for result in high_rows[:30]:
            lines.append(
                f"| `{result.branch}` | `{result.status}` | {result.ahead_by} | {result.behind_by} "
                f"| {result.files_changed} | `{result.topic}` |"
            )
    else:
        lines.append("| _none_ | - | - | - | - | - |")

    lines.append("")
    lines.append("## Recent PR snapshot")
    lines.append("")
    lines.append("| PR | State | Updated | Branch | Title |")
    lines.append("| ---: | --- | --- | --- | --- |")
    for pr in prs[:24]:
        number = pr.get("number", "-")
        state = pr.get("state", "-")
        updated = str(pr.get("updated_at", "-"))[:10]
        head_ref = str(pr.get("head_ref") or (pr.get("head") or {}).get("ref") or "-")
        title = str(pr.get("title", "")).replace("|", "\\|")
        lines.append(f"| {number} | `{state}` | `{updated}` | `{head_ref}` | {title} |")

    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- This report is generated via GitHub API and should be treated as triage, not as an auto-merge list.")
    lines.append("- Branches with large behind/ahead deltas require manual semantic review before porting.")
    lines.append("- For Winlator CMOD, prioritize runtime/content-delivery branches with low drift first.")
    lines.append("")

    return "\n".join(lines)


def compact_pr_row(pr: dict[str, Any]) -> dict[str, Any]:
    head = pr.get("head") or {}
    base = pr.get("base") or {}
    user = pr.get("user") or {}
    return {
        "number": pr.get("number"),
        "state": pr.get("state"),
        "title": pr.get("title"),
        "updated_at": pr.get("updated_at"),
        "created_at": pr.get("created_at"),
        "merged_at": pr.get("merged_at"),
        "url": pr.get("html_url"),
        "head_ref": head.get("ref"),
        "base_ref": base.get("ref"),
        "author": user.get("login"),
        "draft": bool(pr.get("draft") or False),
    }


def main() -> int:
    args = parse_args()
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    report_path = Path(args.report)
    out_dir = Path(args.out_dir)
    per_branch_dir = out_dir / "gamenative-branch-reports"

    report_path.parent.mkdir(parents=True, exist_ok=True)
    out_dir.mkdir(parents=True, exist_ok=True)
    per_branch_dir.mkdir(parents=True, exist_ok=True)

    repo = args.repo.strip()
    if "/" not in repo:
        raise SystemExit("--repo must be owner/name")

    log(f"fetch repo metadata: {repo}")
    repo_info = run_gh_api(f"/repos/{repo}", paginate=False, timeout=args.timeout)
    default_branch = str(repo_info.get("default_branch") or "main")

    log("fetch branches")
    branches = run_gh_api(
        f"/repos/{repo}/branches?per_page=100",
        paginate=True,
        timeout=args.timeout,
    )
    branch_names = [b.get("name", "") for b in branches if isinstance(b, dict) and b.get("name")]
    branch_names = [b for b in branch_names if b != default_branch]
    branch_names.sort(key=str.lower)

    if args.branch_limit and args.branch_limit > 0:
        branch_names = branch_names[: args.branch_limit]

    log(f"compare {len(branch_names)} branches vs {default_branch}")
    results: list[CompareResult] = []
    for idx, branch in enumerate(branch_names, start=1):
        log(f"[{idx}/{len(branch_names)}] {branch}")
        result = collect_branch_compare(repo, default_branch, branch, timeout=args.timeout)
        results.append(result)
        branch_report = render_branch_report(repo, default_branch, generated_at, result)
        branch_file = per_branch_dir / f"{slugify_branch(branch)}.md"
        branch_file.write_text(branch_report, encoding="utf-8")

    log("fetch pull request snapshot")
    prs = run_gh_api(
        f"/repos/{repo}/pulls?state=all&sort=updated&direction=desc&per_page=100",
        paginate=True,
        timeout=args.timeout,
    )
    prs = [pr for pr in prs if isinstance(pr, dict)]
    if args.max_prs > 0:
        prs = prs[: args.max_prs]
    compact_prs = [compact_pr_row(pr) for pr in prs]

    main_report = render_main_report(
        repo=repo,
        repo_info=repo_info,
        generated_at=generated_at,
        branch_results=results,
        prs=compact_prs,
    )
    report_path.write_text(main_report, encoding="utf-8")

    raw_payload = {
        "generated_at_utc": generated_at,
        "repo": repo,
        "repo_info": {
            "name": repo_info.get("full_name"),
            "default_branch": repo_info.get("default_branch"),
            "open_issues_count": repo_info.get("open_issues_count"),
            "stargazers_count": repo_info.get("stargazers_count"),
            "forks_count": repo_info.get("forks_count"),
            "updated_at": repo_info.get("updated_at"),
        },
        "summary": {
            "branches_audited": len(results),
            "risk_counts": Counter(r.risk for r in results),
            "topic_counts": Counter(r.topic for r in results),
        },
        "branch_results": [r.__dict__ for r in results],
        "prs": compact_prs,
    }

    raw_path = out_dir / "gamenative_branch_audit_raw.json"
    raw_path.write_text(json.dumps(raw_payload, ensure_ascii=False, indent=2), encoding="utf-8")

    log(f"wrote report: {report_path}")
    log(f"wrote raw json: {raw_path}")
    log(f"wrote branch detail dir: {per_branch_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
