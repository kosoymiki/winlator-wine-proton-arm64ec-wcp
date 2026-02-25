#!/usr/bin/env python3
"""Generate provenance report for GameHub-related upstream repos."""

from __future__ import annotations

import argparse
import base64
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


DEFAULT_REPOS = [
    "gamehublite/gamehub-oss",
    "Producdevity/gamehub-lite",
    "tkashkin/GameHub",
]
DEFAULT_REPORT = Path("docs/GAMEHUB_PROVENANCE_REPORT.md")
DEFAULT_OUT_DIR = Path("docs/research")


PATCH_PATH_RE = re.compile(r"(^|/)(patch(es)?|diffs?)(/|$)|\.patch$", re.IGNORECASE)
PATCH_TOOL_RE = re.compile(
    r"(apktool|jadx|smali|baksmali|zipalign|apksigner|decompile|repack|autopatch|patcher)",
    re.IGNORECASE,
)
SOURCE_ANDROID_RE = re.compile(r"(^|/)app/src/main/(java|kotlin)/", re.IGNORECASE)
SOURCE_KOTLIN_RE = re.compile(r"\.(kt|kts)$", re.IGNORECASE)
SOURCE_JAVA_RE = re.compile(r"\.java$", re.IGNORECASE)
SOURCE_VALA_RE = re.compile(r"\.vala$", re.IGNORECASE)


@dataclass
class RepoAudit:
    repo: str
    default_branch: str
    classification: str
    confidence: str
    rationale: str
    readme_signals: list[str]
    patch_signals: list[str]
    source_signals: list[str]
    evidence_paths: list[str]
    stars: int
    forks: int
    open_issues: int
    updated_at: str
    api_errors: list[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", action="append", default=[], help="Repo in owner/name format (repeatable)")
    parser.add_argument("--report", default=str(DEFAULT_REPORT), help="Output markdown report path")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR), help="Output directory for raw json")
    parser.add_argument("--timeout", type=int, default=45, help="Timeout in seconds per gh call")
    return parser.parse_args()


def log(msg: str) -> None:
    print(f"[gamehub-provenance] {msg}", file=sys.stderr)


def parse_json_documents(raw: str) -> list[Any]:
    docs: list[Any] = []
    decoder = json.JSONDecoder()
    idx = 0
    while idx < len(raw):
        while idx < len(raw) and raw[idx].isspace():
            idx += 1
        if idx >= len(raw):
            break
        doc, end_idx = decoder.raw_decode(raw, idx)
        docs.append(doc)
        idx = end_idx
    return docs


def run_gh_api(endpoint: str, *, timeout: int, paginate: bool = False, retries: int = 2) -> Any:
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
            time.sleep(0.7 * attempt)

    raise RuntimeError(f"{endpoint}: {last_error}")


def decode_readme(readme_obj: dict[str, Any]) -> str:
    content = str(readme_obj.get("content") or "")
    if not content:
        return ""
    try:
        decoded = base64.b64decode(content, validate=False)
        return decoded.decode("utf-8", errors="replace")
    except Exception:  # noqa: BLE001 - best effort
        return ""


def collect_signals_from_readme(text: str) -> list[str]:
    lowered = text.lower()
    signals: list[str] = []

    checks = {
        "patches official app": ["patches the official", "patch official apk", "autopatcher", "patched apk"],
        "mentions reverse engineering": ["reverse", "decompile", "apktool", "smali", "jadx"],
        "claims source build": ["build from source", "source code", "open source"],
        "mentions upstream mirroring": ["fork of", "upstream", "based on"],
    }

    for label, needles in checks.items():
        if any(needle in lowered for needle in needles):
            signals.append(label)

    return signals


def analyze_tree_paths(paths: list[str]) -> tuple[list[str], list[str], list[str], list[str]]:
    patch_signals: list[str] = []
    source_signals: list[str] = []
    patch_evidence: list[str] = []
    source_evidence: list[str] = []

    patch_count = 0
    patch_tool_count = 0
    android_source_count = 0
    kotlin_java_count = 0
    vala_count = 0

    for path in paths:
        lower = path.lower()

        if PATCH_PATH_RE.search(path):
            patch_count += 1
            if len(patch_evidence) < 10:
                patch_evidence.append(path)
        if PATCH_TOOL_RE.search(lower):
            patch_tool_count += 1
            if len(patch_evidence) < 10 and path not in patch_evidence:
                patch_evidence.append(path)

        if SOURCE_ANDROID_RE.search(path):
            android_source_count += 1
            if len(source_evidence) < 10:
                source_evidence.append(path)
        if SOURCE_KOTLIN_RE.search(path) or SOURCE_JAVA_RE.search(path):
            kotlin_java_count += 1
            if len(source_evidence) < 10 and path not in source_evidence:
                source_evidence.append(path)
        if SOURCE_VALA_RE.search(path):
            vala_count += 1
            if len(source_evidence) < 10 and path not in source_evidence:
                source_evidence.append(path)

    if patch_count:
        patch_signals.append(f"patch-path markers: {patch_count}")
    if patch_tool_count:
        patch_signals.append(f"apk-patching/decompile tool markers: {patch_tool_count}")

    if android_source_count:
        source_signals.append(f"android source tree markers: {android_source_count}")
    if kotlin_java_count:
        source_signals.append(f"kotlin/java file markers: {kotlin_java_count}")
    if vala_count:
        source_signals.append(f"vala source markers: {vala_count}")

    return patch_signals, source_signals, patch_evidence, source_evidence


def classify_repo(
    *,
    readme_signals: list[str],
    patch_signals: list[str],
    source_signals: list[str],
) -> tuple[str, str, str]:
    readme_joined = " ".join(readme_signals).lower()
    patch_strength = len(patch_signals)
    source_strength = len(source_signals)

    if ("patches official app" in readme_joined or "mentions reverse engineering" in readme_joined) and patch_strength:
        return (
            "apk-patchset-overlay",
            "high",
            "Repository appears to distribute patch layers over upstream APKs rather than full source ownership.",
        )

    if patch_strength >= 2 and source_strength <= 1:
        return (
            "apk-patchset-overlay",
            "medium",
            "Tree is dominated by patch/decompile indicators with weak direct source-tree evidence.",
        )

    if source_strength >= 2 and patch_strength == 0:
        return (
            "source-first-project",
            "high",
            "Tree contains direct source structure with minimal patch/decompile artifacts.",
        )

    if source_strength >= 1 and patch_strength >= 1:
        return (
            "hybrid-source-and-patch",
            "medium",
            "Repository combines source files with patch/decompile artifacts; selective reuse is required.",
        )

    return (
        "unclear",
        "low",
        "Insufficient structural evidence for a strict provenance label.",
    )


def audit_repo(repo: str, *, timeout: int) -> RepoAudit:
    errors: list[str] = []

    repo_info: dict[str, Any] = {}
    try:
        repo_info = run_gh_api(f"/repos/{repo}", timeout=timeout)
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(f"failed to read repo metadata for {repo}: {exc}") from exc

    default_branch = str(repo_info.get("default_branch") or "main")

    readme_text = ""
    try:
        readme_obj = run_gh_api(f"/repos/{repo}/readme", timeout=timeout)
        if isinstance(readme_obj, dict):
            readme_text = decode_readme(readme_obj)
    except Exception as exc:  # noqa: BLE001
        errors.append(f"readme: {exc}")

    tree_paths: list[str] = []
    try:
        branch_data = run_gh_api(f"/repos/{repo}/branches/{default_branch}", timeout=timeout)
        branch_sha = ((branch_data.get("commit") or {}).get("sha") or "").strip()
        if branch_sha:
            tree_data = run_gh_api(
                f"/repos/{repo}/git/trees/{branch_sha}?recursive=1",
                timeout=timeout,
            )
            tree = tree_data.get("tree") if isinstance(tree_data, dict) else []
            tree_paths = [node.get("path", "") for node in tree if isinstance(node, dict) and node.get("path")]
    except Exception as exc:  # noqa: BLE001
        errors.append(f"tree: {exc}")

    readme_signals = collect_signals_from_readme(readme_text)
    patch_signals, source_signals, patch_evidence, source_evidence = analyze_tree_paths(tree_paths)
    classification, confidence, rationale = classify_repo(
        readme_signals=readme_signals,
        patch_signals=patch_signals,
        source_signals=source_signals,
    )

    evidence_paths = []
    for item in patch_evidence + source_evidence:
        if item not in evidence_paths:
            evidence_paths.append(item)
        if len(evidence_paths) >= 16:
            break

    return RepoAudit(
        repo=repo,
        default_branch=default_branch,
        classification=classification,
        confidence=confidence,
        rationale=rationale,
        readme_signals=readme_signals,
        patch_signals=patch_signals,
        source_signals=source_signals,
        evidence_paths=evidence_paths,
        stars=int(repo_info.get("stargazers_count") or 0),
        forks=int(repo_info.get("forks_count") or 0),
        open_issues=int(repo_info.get("open_issues_count") or 0),
        updated_at=str(repo_info.get("updated_at") or ""),
        api_errors=errors,
    )


def render_markdown(generated_at: str, audits: list[RepoAudit]) -> str:
    model_counts = Counter(a.classification for a in audits)

    lines: list[str] = []
    lines.append("# GameHub Provenance Report")
    lines.append("")
    lines.append(f"- Generated (UTC): `{generated_at}`")
    lines.append("- Scope: provenance model for GameHub-related repos referenced during optimization research")
    lines.append("")
    lines.append("## Executive Summary")
    lines.append("")
    lines.append("| Repo | Model | Confidence | Default Branch | Stars | Updated |")
    lines.append("| --- | --- | --- | --- | ---: | --- |")
    for audit in audits:
        lines.append(
            f"| `{audit.repo}` | `{audit.classification}` | `{audit.confidence}` | `{audit.default_branch}` "
            f"| {audit.stars} | `{audit.updated_at[:10]}` |"
        )

    lines.append("")
    lines.append("## Model Distribution")
    lines.append("")
    lines.append("| Model | Count |")
    lines.append("| --- | ---: |")
    for model, count in model_counts.most_common():
        lines.append(f"| `{model}` | {count} |")

    for audit in audits:
        lines.append("")
        lines.append(f"## {audit.repo}")
        lines.append("")
        lines.append(f"- Classification: `{audit.classification}` ({audit.confidence} confidence)")
        lines.append(f"- Rationale: {audit.rationale}")
        lines.append(f"- Branch: `{audit.default_branch}`")
        lines.append(f"- Stars/Forks/Open issues: `{audit.stars}` / `{audit.forks}` / `{audit.open_issues}`")

        if audit.readme_signals:
            lines.append(f"- README signals: {', '.join(f'`{s}`' for s in audit.readme_signals)}")
        if audit.patch_signals:
            lines.append(f"- Patch/decompile signals: {', '.join(f'`{s}`' for s in audit.patch_signals)}")
        if audit.source_signals:
            lines.append(f"- Source-structure signals: {', '.join(f'`{s}`' for s in audit.source_signals)}")
        if audit.api_errors:
            lines.append(f"- API notes: {', '.join(f'`{e}`' for e in audit.api_errors)}")

        if audit.evidence_paths:
            lines.append("")
            lines.append("Evidence paths:")
            for path in audit.evidence_paths:
                lines.append(f"- `{path}`")

    lines.append("")
    lines.append("## Reuse Guidance for Winlator CMOD")
    lines.append("")
    lines.append("- Treat `apk-patchset-overlay` repos as idea references; do not import binaries or smali patch flows into mainline CI.")
    lines.append("- Prefer source-first repos for direct code borrowing, then port only minimal, testable deltas.")
    lines.append("- Keep provenance tags in commit messages when adopting logic influenced by these upstreams.")
    lines.append("")

    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    repos = args.repo if args.repo else list(DEFAULT_REPOS)

    report_path = Path(args.report)
    out_dir = Path(args.out_dir)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    out_dir.mkdir(parents=True, exist_ok=True)

    audits: list[RepoAudit] = []
    for repo in repos:
        if "/" not in repo:
            raise SystemExit(f"invalid repo name: {repo}")
        log(f"audit {repo}")
        audits.append(audit_repo(repo, timeout=args.timeout))

    report_content = render_markdown(generated_at, audits)
    report_path.write_text(report_content, encoding="utf-8")

    raw_path = out_dir / "gamehub_provenance_raw.json"
    raw_payload = {
        "generated_at_utc": generated_at,
        "repos": repos,
        "audits": [audit.__dict__ for audit in audits],
    }
    raw_path.write_text(json.dumps(raw_payload, ensure_ascii=False, indent=2), encoding="utf-8")

    log(f"wrote report: {report_path}")
    log(f"wrote raw json: {raw_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
