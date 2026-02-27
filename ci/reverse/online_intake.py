#!/usr/bin/env python3
import argparse
import json
import subprocess
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List


@dataclass
class RepoSpec:
    alias: str
    owner: str
    repo: str
    branch: str


SPECS = [
    RepoSpec("coffin_winlator", "coffincolors", "winlator", "cmod_bionic"),
    RepoSpec("coffin_wine", "coffincolors", "wine", "arm64ec"),
    RepoSpec("gamenative_protonwine", "GameNative", "proton-wine", "proton_10.0"),
]


def gh_api(path: str) -> Dict:
    out = subprocess.check_output(["gh", "api", path], text=True)
    return json.loads(out)


def classify_path(path: str) -> str:
    p = path.lower()
    if "xserver" in p or "vulkan" in p or "turnip" in p or "winex11" in p:
        return "graphics_xserver"
    if "launcher" in p or "xenvironment" in p:
        return "launcher_runtime"
    if "container" in p or "shortcut" in p or "imagefs" in p or "contents" in p:
        return "container_flow"
    if "controller" in p or "input" in p or "evshim" in p or "mouse" in p:
        return "input_stack"
    if "audio" in p or "alsa" in p or "pulse" in p or "gstreamer" in p:
        return "audio_stack"
    if "ntdll" in p or "wow64" in p or "arm64ec" in p or "loader" in p:
        return "arm64ec_core"
    if "configure" in p or "build" in p or "workflow" in p:
        return "build_ci"
    return "misc"


def collect_repo(spec: RepoSpec, limit: int) -> Dict:
    repo_meta = gh_api(f"repos/{spec.owner}/{spec.repo}")
    commits = gh_api(f"repos/{spec.owner}/{spec.repo}/commits?sha={spec.branch}&per_page={limit}")

    file_hits: Counter = Counter()
    cat_hits: Counter = Counter()
    author_hits: Counter = Counter()
    commit_rows: List[Dict] = []

    for c in commits:
        sha = c["sha"]
        author = (c.get("author") or {}).get("login") or (c.get("commit", {}).get("author", {}).get("name")) or "unknown"
        subject = (c.get("commit", {}).get("message") or "").split("\n")[0]
        author_hits[author] += 1

        det = gh_api(f"repos/{spec.owner}/{spec.repo}/commits/{sha}")
        touched = []
        for f in det.get("files", []):
            fn = f.get("filename", "")
            if not fn:
                continue
            file_hits[fn] += 1
            cat_hits[classify_path(fn)] += 1
            touched.append(fn)

        commit_rows.append(
            {
                "sha": sha,
                "subject": subject,
                "author": author,
                "files": touched,
            }
        )

    return {
        "repo": f"{spec.owner}/{spec.repo}",
        "branch": spec.branch,
        "default_branch": repo_meta.get("default_branch", ""),
        "updated_at": repo_meta.get("updated_at", ""),
        "stargazers_count": repo_meta.get("stargazers_count", 0),
        "open_issues_count": repo_meta.get("open_issues_count", 0),
        "commits_scanned": len(commits),
        "top_files": file_hits.most_common(40),
        "top_categories": cat_hits.most_common(),
        "top_authors": author_hits.most_common(10),
        "recent_commits": commit_rows,
    }


def write_repo_markdown(report: Dict, out_file: Path) -> None:
    lines: List[str] = []
    lines.append(f"# Online Intake: `{report['repo']}`")
    lines.append("")
    lines.append(f"- Branch analyzed: `{report['branch']}`")
    lines.append(f"- Default branch: `{report['default_branch']}`")
    lines.append(f"- Updated at: `{report['updated_at']}`")
    lines.append(f"- Commits scanned: `{report['commits_scanned']}`")
    lines.append("")

    lines.append("## Top categories")
    lines.append("")
    for cat, n in report["top_categories"]:
        lines.append(f"- `{cat}`: **{n}**")
    lines.append("")

    lines.append("## Top touched files")
    lines.append("")
    for fn, n in report["top_files"][:25]:
        lines.append(f"- `{fn}`: **{n}**")
    lines.append("")

    lines.append("## Recent commit subjects")
    lines.append("")
    for row in report["recent_commits"][:20]:
        lines.append(f"- `{row['sha'][:8]}` {row['subject']}")

    out_file.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_combined(reports: Dict[str, Dict], out_file: Path) -> None:
    lines: List[str] = []
    lines.append("# Online Intake Combined Matrix")
    lines.append("")
    lines.append("This report is produced via GitHub API only (no source clone).")
    lines.append("")

    for alias, report in reports.items():
        lines.append(f"## {alias}: `{report['repo']}`")
        lines.append("")
        lines.append(f"- branch: `{report['branch']}`")
        lines.append(f"- commits scanned: **{report['commits_scanned']}**")
        cat_view = ", ".join(f"{cat}={n}" for cat, n in report["top_categories"][:6])
        lines.append(f"- category mix: {cat_view}")
        lines.append("")

    lines.append("## Cross-source focus")
    lines.append("")
    lines.append("- Runtime stability first: prioritize `arm64ec_core`, `launcher_runtime`, `container_flow`.")
    lines.append("- Defer risky `HACK`/revert clusters behind gated lanes before promoting to mainline.")
    lines.append("")

    out_file.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Online-only reverse intake via GitHub API")
    parser.add_argument("--out-dir", default="docs/reverse/online-intake")
    parser.add_argument("--limit", type=int, default=25)
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    reports: Dict[str, Dict] = {}
    for spec in SPECS:
        report = collect_repo(spec, args.limit)
        reports[spec.alias] = report
        json_path = out_dir / f"{spec.alias}.json"
        md_path = out_dir / f"{spec.alias}.md"
        json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        write_repo_markdown(report, md_path)

    combined_json = out_dir / "combined-matrix.json"
    combined_md = out_dir / "combined-matrix.md"
    combined_json.write_text(json.dumps(reports, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_combined(reports, combined_md)
    print(f"[online-intake] wrote {combined_md}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
