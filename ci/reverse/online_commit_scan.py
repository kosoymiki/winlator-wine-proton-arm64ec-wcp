#!/usr/bin/env python3
import argparse
import json
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Sequence


@dataclass
class RepoSpec:
    alias: str
    owner: str
    repo: str
    branch: str


def run_gh_json(path: str, retries: int, retry_delay: float) -> Dict | List:
    last_err = ""
    for attempt in range(retries + 1):
        proc = subprocess.run(["gh", "api", path], capture_output=True, text=True)
        if proc.returncode == 0:
            return json.loads(proc.stdout or "{}")
        last_err = (proc.stderr or proc.stdout or "unknown gh api error").strip()
        if attempt >= retries:
            break
        time.sleep(retry_delay * (attempt + 1))
    raise RuntimeError(f"gh api failed: {path}: {last_err[:260]}")


def load_specs(repo_file: Path, aliases_csv: str) -> List[RepoSpec]:
    raw = json.loads(repo_file.read_text(encoding="utf-8"))
    if not isinstance(raw, list):
        raise RuntimeError("repo file must contain an array")
    aliases = {x.strip() for x in aliases_csv.split(",") if x.strip()}
    specs: List[RepoSpec] = []
    for row in raw:
        if not isinstance(row, dict):
            continue
        alias = str(row.get("alias", "")).strip()
        if not alias:
            continue
        if aliases and alias not in aliases:
            continue
        branch = str(row.get("branch", "") or "HEAD").strip()
        specs.append(
            RepoSpec(
                alias=alias,
                owner=str(row.get("owner", "")).strip(),
                repo=str(row.get("repo", "")).strip(),
                branch=branch,
            )
        )
    return specs


def marker_hits_in_commit(commit: Dict, markers: Sequence[str]) -> Dict[str, int]:
    files = commit.get("files") or []
    out: Dict[str, int] = {m: 0 for m in markers}
    for row in files:
        path = str(row.get("filename", "") or "")
        patch = str(row.get("patch", "") or "")
        blob = f"{path}\n{patch}"
        for marker in markers:
            if marker in blob:
                out[marker] += 1
    return out


def fetch_commits_with_branch_fallback(
    spec: RepoSpec,
    commits_per_repo: int,
    retries: int,
    retry_delay: float,
) -> tuple[list, str]:
    requested = (spec.branch or "").strip() or "HEAD"
    attempts: List[str] = []
    for candidate in [requested, "HEAD"]:
        branch = candidate.strip()
        if not branch or branch in attempts:
            continue
        attempts.append(branch)
        try:
            rows = run_gh_json(
                f"repos/{spec.owner}/{spec.repo}/commits?sha={branch}&per_page={commits_per_repo}",
                retries,
                retry_delay,
            )
            if isinstance(rows, list):
                return rows, branch
        except Exception:
            pass

    repo_meta = run_gh_json(f"repos/{spec.owner}/{spec.repo}", retries, retry_delay)
    default_branch = str((repo_meta or {}).get("default_branch") or "").strip()
    for candidate in [default_branch, "main", "master"]:
        branch = candidate.strip()
        if not branch or branch in attempts:
            continue
        attempts.append(branch)
        rows = run_gh_json(
            f"repos/{spec.owner}/{spec.repo}/commits?sha={branch}&per_page={commits_per_repo}",
            retries,
            retry_delay,
        )
        if isinstance(rows, list):
            return rows, branch
    raise RuntimeError(
        f"unable to fetch commits for {spec.owner}/{spec.repo}; tried branches: {', '.join(attempts)}"
    )


def build_scan(
    specs: List[RepoSpec],
    commits_per_repo: int,
    markers: Sequence[str],
    retries: int,
    retry_delay: float,
) -> Dict:
    reports: Dict[str, Dict] = {}
    errors: Dict[str, str] = {}
    for spec in specs:
        try:
            commit_rows, resolved_branch = fetch_commits_with_branch_fallback(
                spec=spec,
                commits_per_repo=commits_per_repo,
                retries=retries,
                retry_delay=retry_delay,
            )
            items: List[Dict] = []
            marker_totals: Dict[str, int] = {m: 0 for m in markers}
            for row in commit_rows:
                sha = str(row.get("sha", "")).strip()
                if not sha:
                    continue
                detail = run_gh_json(
                    f"repos/{spec.owner}/{spec.repo}/commits/{sha}",
                    retries,
                    retry_delay,
                )
                commit = detail.get("commit") or {}
                message = str(commit.get("message", "") or "").splitlines()[0][:220]
                files = detail.get("files") or []
                hits = marker_hits_in_commit(detail, markers)
                touched_markers = [m for m, cnt in hits.items() if cnt > 0]
                changed_paths = [
                    str(file_row.get("filename", "")).strip()
                    for file_row in files
                    if str(file_row.get("filename", "")).strip()
                ]
                for marker in touched_markers:
                    marker_totals[marker] += hits[marker]
                items.append(
                    {
                        "sha": sha[:12],
                        "sha_full": sha,
                        "date": ((commit.get("author") or {}).get("date") or ""),
                        "message": message,
                        "files": len(files),
                        "changed_paths": changed_paths,
                        "marker_hits": {m: hits[m] for m in touched_markers},
                        "markers": touched_markers,
                    }
                )
            reports[spec.alias] = {
                "owner": spec.owner,
                "repo": spec.repo,
                "branch_requested": spec.branch,
                "branch": resolved_branch,
                "commits": items,
                "marker_totals": {k: v for k, v in marker_totals.items() if v > 0},
            }
        except Exception as exc:
            errors[spec.alias] = str(exc)
    return {
        "repos_scanned": len(specs),
        "errors": errors,
        "reports": reports,
    }


def write_md(out_file: Path, payload: Dict) -> None:
    reports = payload.get("reports") or {}
    errors = payload.get("errors") or {}
    lines: List[str] = []
    lines.append("# Online Commit Scan")
    lines.append("")
    lines.append("- source: GitHub API (`gh api`) only")
    lines.append(f"- repos scanned: **{len(reports)}**")
    lines.append(f"- errors: **{len(errors)}**")
    lines.append("")
    if errors:
        lines.append("## Errors")
        lines.append("")
        for alias, err in sorted(errors.items()):
            lines.append(f"- `{alias}`: {err}")
        lines.append("")

    lines.append("## Repo Summaries")
    lines.append("")
    for alias, rep in sorted(reports.items()):
        lines.append(f"### {alias}")
        lines.append("")
        lines.append(f"- repo: `{rep.get('owner')}/{rep.get('repo')}`")
        lines.append(f"- branch: `{rep.get('branch')}`")
        requested = str(rep.get("branch_requested") or "").strip()
        resolved = str(rep.get("branch") or "").strip()
        if requested and resolved and requested != resolved:
            lines.append(f"- branch_requested: `{requested}`")
        marker_totals = rep.get("marker_totals") or {}
        if marker_totals:
            marker_line = ", ".join(f"`{k}`={v}" for k, v in sorted(marker_totals.items()))
            lines.append(f"- marker totals: {marker_line}")
        else:
            lines.append("- marker totals: none")
        lines.append("")
        lines.append("| SHA | Date | Files | Paths | Markers | Message |")
        lines.append("| --- | --- | ---: | ---: | --- | --- |")
        for row in rep.get("commits") or []:
            marker_text = ", ".join(row.get("markers") or [])
            path_count = len(row.get("changed_paths") or [])
            lines.append(
                f"| `{row.get('sha','')}` | `{row.get('date','')}` | {row.get('files',0)} | {path_count} | {marker_text} | {row.get('message','')} |"
            )
        lines.append("")
    out_file.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Scan recent commits online for marker touches")
    parser.add_argument("--repo-file", default="ci/reverse/online_intake_repos.json")
    parser.add_argument("--aliases", default="")
    parser.add_argument("--commits-per-repo", type=int, default=12)
    parser.add_argument("--markers", default="x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION,ContentProfile,REMOTE_PROFILES,WINEDEBUG,MESA_VK_WSI_PRESENT_MODE,TU_DEBUG,DXVK,VKD3D,D8VK,DXVK_NVAPI,WINE_FULLSCREEN_FSR,WINE_FULLSCREEN_FSR_STRENGTH,WINE_FULLSCREEN_FSR_MODE,VKBASALT_CONFIG")
    parser.add_argument("--gh-retries", type=int, default=3)
    parser.add_argument("--gh-retry-delay-sec", type=float, default=1.5)
    parser.add_argument("--out-json", default="docs/reverse/online-intake/commit-scan.json")
    parser.add_argument("--out-md", default="docs/reverse/online-intake/commit-scan.md")
    args = parser.parse_args()

    repo_file = Path(args.repo_file)
    if not repo_file.exists():
        raise SystemExit(f"[online-commit-scan][error] missing repo file: {repo_file}")

    markers = [m.strip() for m in args.markers.split(",") if m.strip()]
    specs = load_specs(repo_file, args.aliases)
    payload = build_scan(specs, max(1, args.commits_per_repo), markers, max(0, args.gh_retries), max(0.1, args.gh_retry_delay_sec))

    out_json = Path(args.out_json)
    out_md = Path(args.out_md)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_md(out_md, payload)

    print(f"[online-commit-scan] wrote {out_json}")
    print(f"[online-commit-scan] wrote {out_md}")
    print(f"[online-commit-scan] repos_scanned={payload.get('repos_scanned',0)} errors={len(payload.get('errors') or {})}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
