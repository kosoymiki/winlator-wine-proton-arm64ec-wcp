#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple


@dataclass
class RepoSpec:
    alias: str
    owner: str
    repo: str
    branch: str
    enabled_default: bool = True
    focus_paths: List[str] = field(default_factory=list)
    pinned_commits: List[str] = field(default_factory=list)


@dataclass
class SyncRule:
    kind: str
    source: str = ""
    target: str = ""
    ref: str = "head"
    allow_missing: bool = False
    source_prefix: str = ""
    target_prefix: str = ""
    include_suffixes: List[str] = field(default_factory=list)
    exclude_substrings: List[str] = field(default_factory=list)


@dataclass
class HarvestSpec:
    alias: str
    enabled: bool = True
    harvest_paths: List[str] = field(default_factory=list)
    commit_markers: List[str] = field(default_factory=list)
    sync_rules: List[SyncRule] = field(default_factory=list)


def run_text(cmd: Sequence[str], cwd: Optional[Path] = None, allow_fail: bool = False) -> str:
    proc = subprocess.run(
        list(cmd),
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0 and not allow_fail:
        err = (proc.stderr or proc.stdout or "command failed").strip()
        raise RuntimeError(f"command failed: {' '.join(cmd)}: {err[:260]}")
    return proc.stdout


def git_exists(repo_dir: Path, ref: str) -> bool:
    proc = subprocess.run(
        ["git", "cat-file", "-e", f"{ref}^{{commit}}"],
        cwd=str(repo_dir),
        text=True,
        capture_output=True,
    )
    return proc.returncode == 0


def ensure_repo(spec: RepoSpec, git_workdir: Path) -> Path:
    repo_dir = git_workdir / spec.alias
    remote_url = f"https://github.com/{spec.owner}/{spec.repo}.git"
    if not (repo_dir / ".git").exists():
        repo_dir.parent.mkdir(parents=True, exist_ok=True)
        run_text(["git", "clone", "--filter=blob:none", "--no-checkout", remote_url, str(repo_dir)])
    else:
        current = run_text(["git", "remote", "get-url", "origin"], cwd=repo_dir, allow_fail=True).strip()
        if not current:
            run_text(["git", "remote", "add", "origin", remote_url], cwd=repo_dir)
        elif current != remote_url:
            run_text(["git", "remote", "set-url", "origin", remote_url], cwd=repo_dir)
    return repo_dir


def resolve_remote_branch(repo_dir: Path, preferred_branch: str) -> str:
    branch = (preferred_branch or "").strip() or "main"
    probe = subprocess.run(
        ["git", "ls-remote", "--heads", "origin", branch],
        cwd=str(repo_dir),
        text=True,
        capture_output=True,
    )
    if probe.returncode == 0 and (probe.stdout or "").strip():
        return branch

    symref = run_text(["git", "ls-remote", "--symref", "origin", "HEAD"], cwd=repo_dir, allow_fail=True)
    match = re.search(r"ref:\s+refs/heads/([^\s]+)\s+HEAD", symref or "")
    if match:
        return match.group(1)

    for fallback in ("main", "master"):
        if fallback == branch:
            continue
        probe = subprocess.run(
            ["git", "ls-remote", "--heads", "origin", fallback],
            cwd=str(repo_dir),
            text=True,
            capture_output=True,
        )
        if probe.returncode == 0 and (probe.stdout or "").strip():
            return fallback
    return branch


def fetch_repo(repo_dir: Path, branch: str, commits: Sequence[str], depth: int) -> str:
    depth = max(1, depth)
    resolved_branch = resolve_remote_branch(repo_dir, branch)
    fetch_ref = f"+refs/heads/{resolved_branch}:refs/remotes/origin/{resolved_branch}"
    run_text(
        ["git", "fetch", "--depth", str(depth), "--filter=blob:none", "--no-tags", "origin", fetch_ref],
        cwd=repo_dir,
    )
    for sha in commits:
        if not sha.strip():
            continue
        if git_exists(repo_dir, sha):
            continue
        run_text(
            ["git", "fetch", "--depth", "1", "--filter=blob:none", "--no-tags", "origin", sha],
            cwd=repo_dir,
            allow_fail=True,
        )
    return resolved_branch


def configure_sparse_checkout(repo_dir: Path, harvest_paths: Sequence[str]) -> None:
    if not harvest_paths:
        return
    run_text(["git", "sparse-checkout", "init", "--no-cone"], cwd=repo_dir, allow_fail=True)
    normalized = [p.strip().lstrip("/") for p in harvest_paths if p.strip()]
    if normalized:
        run_text(["git", "sparse-checkout", "set", *normalized], cwd=repo_dir)


def checkout_head(repo_dir: Path, branch: str) -> str:
    target_ref = f"refs/remotes/origin/{branch}"
    run_text(["git", "checkout", "-f", target_ref], cwd=repo_dir)
    return run_text(["git", "rev-parse", target_ref], cwd=repo_dir).strip()


def parse_repo_specs(path: Path) -> Dict[str, RepoSpec]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    out: Dict[str, RepoSpec] = {}
    for row in raw:
        if not isinstance(row, dict):
            continue
        alias = str(row.get("alias", "")).strip()
        owner = str(row.get("owner", "")).strip()
        repo = str(row.get("repo", "")).strip()
        if not alias or not owner or not repo:
            continue
        branch = str(row.get("branch", "")).strip() or "main"
        enabled_default = bool(row.get("enabled_default", True))
        focus_paths = [str(x).strip().lstrip("/") for x in (row.get("focus_paths") or []) if str(x).strip()]
        pinned = [str(x).strip() for x in (row.get("pinned_commits") or []) if str(x).strip()]
        out[alias] = RepoSpec(
            alias=alias,
            owner=owner,
            repo=repo,
            branch=branch,
            enabled_default=enabled_default,
            focus_paths=focus_paths,
            pinned_commits=pinned,
        )
    return out


def parse_map(path: Path, aliases: Optional[set]) -> List[HarvestSpec]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    rows = raw.get("repos") if isinstance(raw, dict) else raw
    specs: List[HarvestSpec] = []
    if not isinstance(rows, list):
        return specs
    for row in rows:
        if not isinstance(row, dict):
            continue
        alias = str(row.get("alias", "")).strip()
        if not alias:
            continue
        if aliases and alias not in aliases:
            continue
        enabled = bool(row.get("enabled", True))
        harvest_paths = [str(x).strip() for x in (row.get("harvest_paths") or []) if str(x).strip()]
        commit_markers = [str(x).strip() for x in (row.get("commit_markers") or []) if str(x).strip()]
        sync_rules: List[SyncRule] = []
        for rule in (row.get("sync_rules") or []):
            if not isinstance(rule, dict):
                continue
            sync_rules.append(
                SyncRule(
                    kind=str(rule.get("kind", "")).strip(),
                    source=str(rule.get("source", "")).strip(),
                    target=str(rule.get("target", "")).strip(),
                    ref=str(rule.get("ref", "head")).strip() or "head",
                    allow_missing=bool(rule.get("allow_missing", False)),
                    source_prefix=str(rule.get("source_prefix", "")).strip(),
                    target_prefix=str(rule.get("target_prefix", "")).strip(),
                    include_suffixes=[str(x).strip() for x in (rule.get("include_suffixes") or []) if str(x).strip()],
                    exclude_substrings=[str(x).strip() for x in (rule.get("exclude_substrings") or []) if str(x).strip()],
                )
            )
        specs.append(
            HarvestSpec(
                alias=alias,
                enabled=enabled,
                harvest_paths=harvest_paths,
                commit_markers=commit_markers,
                sync_rules=sync_rules,
            )
        )
    return specs


def add_unmapped_specs(
    specs: List[HarvestSpec],
    repo_specs: Dict[str, RepoSpec],
    aliases: Optional[set],
) -> List[HarvestSpec]:
    seen = {spec.alias for spec in specs}
    augmented = list(specs)
    for alias, repo in sorted(repo_specs.items()):
        if alias in seen:
            continue
        if aliases and alias not in aliases:
            continue
        if not repo.focus_paths:
            continue
        augmented.append(
            HarvestSpec(
                alias=alias,
                enabled=repo.enabled_default,
                harvest_paths=list(repo.focus_paths),
                commit_markers=[],
                sync_rules=[],
            )
        )
    return augmented


def parse_commit_scan(path: Path) -> Dict[str, Dict]:
    if not path.exists():
        return {}
    raw = json.loads(path.read_text(encoding="utf-8"))
    reports = raw.get("reports") or {}
    return reports if isinstance(reports, dict) else {}


def select_commits(
    repo_spec: RepoSpec,
    harvest_spec: HarvestSpec,
    commit_scan_row: Dict,
    max_commits: int,
) -> Tuple[List[str], Dict[str, Dict], List[Dict]]:
    selected: List[str] = []
    seen = set()
    metadata: Dict[str, Dict] = {}
    commit_rows: List[Dict] = commit_scan_row.get("commits") or []
    wanted_markers = set(harvest_spec.commit_markers)

    for row in commit_rows:
        if not isinstance(row, dict):
            continue
        markers = {str(x).strip() for x in (row.get("markers") or []) if str(x).strip()}
        if wanted_markers and not (markers & wanted_markers):
            continue
        sha = str(row.get("sha_full") or row.get("sha") or "").strip()
        if not sha or sha in seen:
            continue
        seen.add(sha)
        selected.append(sha)
        metadata[sha] = row
        if len(selected) >= max_commits:
            break

    for sha in repo_spec.pinned_commits:
        if len(selected) >= max_commits:
            break
        s = sha.strip()
        if not s or s in seen:
            continue
        seen.add(s)
        selected.append(s)
        metadata.setdefault(s, {"sha_full": s, "markers": [], "changed_paths": []})

    return selected, metadata, commit_rows


def build_auto_focus_sync_rules(repo_spec: RepoSpec) -> List[SyncRule]:
    rules: List[SyncRule] = []
    for source in repo_spec.focus_paths:
        path = source.strip().lstrip("/")
        if not path:
            continue
        rules.append(
            SyncRule(
                kind="path_copy",
                source=path,
                target=f"ci/reverse/upstream_snapshots/{repo_spec.alias}/{path}",
                ref="head",
                allow_missing=True,
            )
        )
    return rules


def commit_changed_paths(repo_dir: Path, sha: str) -> List[str]:
    out = run_text(["git", "show", "--name-only", "--pretty=format:", sha], cwd=repo_dir)
    return [line.strip() for line in out.splitlines() if line.strip()]


def read_blob(repo_dir: Path, ref: str, path: str) -> bytes:
    proc = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        cwd=str(repo_dir),
        text=False,
        capture_output=True,
    )
    if proc.returncode != 0:
        raise RuntimeError((proc.stderr or b"blob read failed").decode("utf-8", errors="replace").strip()[:260])
    return proc.stdout


def write_file(path: Path, data: bytes) -> bool:
    if path.exists() and path.read_bytes() == data:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return True


def _canonicalize_gn_patch(target_rel: str, incoming: str) -> str:
    text = incoming

    if target_rel.endswith("programs_winebrowser_main_c.patch"):
        text = re.sub(
            r"send\(\s*sock_fd\s*,\s*&net_requestcode\s*,\s*sizeof\(net_requestcode\)\s*,\s*0\s*\)",
            "send(sock_fd, (const char *)&net_requestcode, sizeof(net_requestcode), 0)",
            text,
        )
        text = re.sub(
            r"send\(\s*sock_fd\s*,\s*&net_data_length\s*,\s*sizeof\(net_data_length\)\s*,\s*0\s*\)",
            "send(sock_fd, (const char *)&net_data_length, sizeof(net_data_length), 0)",
            text,
        )
        text = text.replace("WINE_OPEN_WITH_ANDROID_BROwSER", "WINE_OPEN_WITH_ANDROID_BROWSER")
        text = text.replace("static char *from_unix_to_dos_path", "static const char *from_unix_to_dos_path")
        text = text.replace("char *path = url + 7;", "const char *path = url + 7;")
        text = text.replace("char *new_url = NULL;", "const char *new_url = NULL;")

    elif target_rel.endswith("dlls_user32_clipboard_c.patch"):
        text = re.sub(
            r"send\(\s*sock_fd\s*,\s*&net_requestcode\s*,\s*sizeof\(net_requestcode\)\s*,\s*0\s*\)",
            "send(sock_fd, (const char *)&net_requestcode, sizeof(net_requestcode), 0)",
            text,
        )
        text = re.sub(
            r"send\(\s*sock_fd\s*,\s*&net_data_format\s*,\s*sizeof\(net_data_format\)\s*,\s*0\s*\)",
            "send(sock_fd, (const char *)&net_data_format, sizeof(net_data_format), 0)",
            text,
        )
        text = re.sub(
            r"send\(\s*sock_fd\s*,\s*&net_data_size\s*,\s*sizeof\(net_data_size\)\s*,\s*0\s*\)",
            "send(sock_fd, (const char *)&net_data_size, sizeof(net_data_size), 0)",
            text,
        )
        text = re.sub(
            r"recv\(\s*sock_fd\s*,\s*&net_data_format\s*,\s*sizeof\(net_data_format\)\s*,\s*0\s*\)",
            "recv(sock_fd, (char *)&net_data_format, sizeof(net_data_format), 0)",
            text,
        )
        text = re.sub(
            r"recv\(\s*sock_fd\s*,\s*&net_data_size\s*,\s*sizeof\(net_data_size\)\s*,\s*0\s*\)",
            "recv(sock_fd, (char *)&net_data_size, sizeof(net_data_size), 0)",
            text,
        )

    elif target_rel.endswith("dlls_ntdll_loader_c.patch"):
        if "pWow64SuspendLocalThread" not in text:
            before = text
            text = text.replace(
                "void (WINAPI *pWow64PrepareForException)( EXCEPTION_RECORD *rec, CONTEXT *context ) = NULL;\n",
                "void (WINAPI *pWow64PrepareForException)( EXCEPTION_RECORD *rec, CONTEXT *context ) = NULL;\n"
                "NTSTATUS (WINAPI *pWow64SuspendLocalThread)( HANDLE thread, ULONG *count ) = NULL;\n",
            )
            if text == before:
                text = text.rstrip() + (
                    "\n@@ -4479,6 +4479,7 @@ static void build_wow64_main_module(void)\n"
                    " static void (WINAPI *pWow64LdrpInitialize)( CONTEXT *ctx );\n"
                    " \n"
                    " void (WINAPI *pWow64PrepareForException)( EXCEPTION_RECORD *rec, CONTEXT *context ) = NULL;\n"
                    "+NTSTATUS (WINAPI *pWow64SuspendLocalThread)( HANDLE thread, ULONG *count ) = NULL;\n"
                    " \n"
                    " static void init_wow64( CONTEXT *context )\n"
                    " {\n"
                    "@@ -4503,6 +4504,7 @@ static void init_wow64( CONTEXT *context )\n"
                    " \n"
                    "         GET_PTR( Wow64LdrpInitialize );\n"
                    "         GET_PTR( Wow64PrepareForException );\n"
                    "+        GET_PTR( Wow64SuspendLocalThread );\n"
                    " #undef GET_PTR\n"
                    "         imports_fixup_done = TRUE;\n"
                    "     }\n"
                )
        if "GET_PTR( Wow64SuspendLocalThread );" not in text:
            text = text.replace(
                "        GET_PTR( Wow64PrepareForException );\n",
                "        GET_PTR( Wow64PrepareForException );\n"
                "        GET_PTR( Wow64SuspendLocalThread );\n",
            )

    elif target_rel.endswith("dlls_winex11_drv_mouse_c.patch"):
        text = text.replace(
            "#ifndef __ANDROID__",
            "#if !defined(__ANDROID__) && defined(HAVE_X11_EXTENSIONS_XFIXES_H) && defined(SONAME_LIBXFIXES)",
        )

    elif target_rel.endswith("test-bylaws/dlls_wow64_process_c.patch"):
        if "Wow64SuspendLocalThread" not in text:
            text = text.rstrip() + (
                "\n\n"
                "/**********************************************************************\n"
                " *           Wow64SuspendLocalThread  (wow64.@)\n"
                " */\n"
                "NTSTATUS WINAPI Wow64SuspendLocalThread( HANDLE thread, ULONG *count )\n"
                "{\n"
                "    return NtSuspendThread( thread, count );\n"
                "}\n"
            )

    return text


def merge_target_payload(repo_root: Path, target_rel: str, incoming: bytes) -> bytes:
    norm_rel = target_rel.strip().lstrip("/")
    if not (
        norm_rel.startswith("ci/gamenative/patchsets/28c3a06/android/patches/")
        and norm_rel.endswith(".patch")
    ):
        return incoming

    try:
        incoming_text = incoming.decode("utf-8")
    except UnicodeDecodeError:
        return incoming

    merged = _canonicalize_gn_patch(norm_rel, incoming_text)

    target_path = repo_root / norm_rel
    if target_path.exists():
        try:
            existing = target_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            existing = ""
        # Keep local patch index header stable to avoid noisy churn when
        # upstream changes only blob ids and not our effective patch contract.
        existing_index = re.search(r"^index\s+.+$", existing, flags=re.M)
        incoming_index = re.search(r"^index\s+.+$", merged, flags=re.M)
        if existing_index and incoming_index:
            merged = (
                merged[: incoming_index.start()]
                + existing_index.group(0)
                + merged[incoming_index.end() :]
            )
        # Preserve existing contract markers if upstream input drops them.
        if norm_rel.endswith("dlls_ntdll_loader_c.patch"):
            if "pWow64SuspendLocalThread" in existing and "pWow64SuspendLocalThread" not in merged:
                merged = _canonicalize_gn_patch(norm_rel, merged)
        elif norm_rel.endswith("test-bylaws/dlls_wow64_process_c.patch"):
            if "Wow64SuspendLocalThread" in existing and "Wow64SuspendLocalThread" not in merged:
                merged = _canonicalize_gn_patch(norm_rel, merged)

    return merged.encode("utf-8")


def in_repo(repo_root: Path, path: Path) -> bool:
    root = repo_root.resolve()
    target = path.resolve()
    return str(target) == str(root) or str(target).startswith(str(root) + os.sep)


def harvest_commit_artifacts(
    repo_dir: Path,
    out_dir: Path,
    sha: str,
    changed_paths: Sequence[str],
    harvest_paths: Sequence[str],
) -> None:
    commit_dir = out_dir / "commits" / sha[:12]
    commit_dir.mkdir(parents=True, exist_ok=True)

    touched = [p for p in changed_paths if p]
    wanted_prefixes = [p.rstrip("/").lstrip("/") for p in harvest_paths if p.strip()]
    if wanted_prefixes:
        touched = [
            p
            for p in touched
            if any(p == prefix or p.startswith(prefix + "/") for prefix in wanted_prefixes)
        ]

    meta = {
        "sha": sha,
        "changed_paths": touched,
    }
    (commit_dir / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if touched:
        patch = run_text(["git", "show", "--no-color", "--patch", sha, "--", *touched], cwd=repo_dir, allow_fail=True)
    else:
        patch = run_text(["git", "show", "--no-color", "--patch", "--stat", sha], cwd=repo_dir, allow_fail=True)
    (commit_dir / "commit.patch").write_text(patch, encoding="utf-8")


def resolve_ref(repo_spec: RepoSpec, rule_ref: str, commit_index: Dict[str, str]) -> str:
    ref = (rule_ref or "head").strip()
    if ref in {"head", "branch"}:
        return f"refs/remotes/origin/{repo_spec.branch}"
    if ref == "latest_commit":
        latest = commit_index.get("__latest_commit__")
        return latest or f"refs/remotes/origin/{repo_spec.branch}"
    if ref.startswith("commit:"):
        return ref.split(":", 1)[1].strip()
    return ref


def apply_sync_rules(
    repo_root: Path,
    repo_spec: RepoSpec,
    repo_dir: Path,
    harvest_out: Path,
    selected_commits: Sequence[str],
    commit_meta: Dict[str, Dict],
    rules: Sequence[SyncRule],
    apply_changes: bool,
) -> List[Dict]:
    results: List[Dict] = []
    commit_index: Dict[str, str] = {"__latest_commit__": selected_commits[0] if selected_commits else ""}

    for rule in rules:
        if rule.kind == "path_copy":
            ref = resolve_ref(repo_spec, rule.ref, commit_index)
            if not rule.source or not rule.target:
                continue
            result = {
                "kind": rule.kind,
                "source": rule.source,
                "target": rule.target,
                "ref": ref,
                "status": "skipped",
            }
            try:
                data = read_blob(repo_dir, ref, rule.source)
                data = merge_target_payload(repo_root, rule.target, data)
                shadow = harvest_out / "synced" / "path_copy" / Path(rule.source)
                write_file(shadow, data)
                target = (repo_root / rule.target).resolve()
                if not in_repo(repo_root, target):
                    result["status"] = "error"
                    result["error"] = "target escapes repo root"
                elif apply_changes:
                    changed = write_file(target, data)
                    result["status"] = "changed" if changed else "unchanged"
                else:
                    result["status"] = "planned"
            except Exception as exc:
                if rule.allow_missing:
                    result["status"] = "skipped_missing"
                else:
                    result["status"] = "error"
                    result["error"] = str(exc)
            results.append(result)
            continue

        if rule.kind != "changed_path_sync":
            continue

        source_prefix = rule.source_prefix.rstrip("/")
        target_prefix = rule.target_prefix.rstrip("/")
        if not source_prefix or not target_prefix:
            continue
        suffixes = tuple(rule.include_suffixes or [".patch"])
        excludes = tuple(rule.exclude_substrings or [])

        path_latest_commit: Dict[str, str] = {}
        for sha in selected_commits:
            row = commit_meta.get(sha, {})
            changed = [str(x).strip() for x in (row.get("changed_paths") or []) if str(x).strip()]
            if not changed:
                changed = commit_changed_paths(repo_dir, sha)
            for path in changed:
                if not path.startswith(source_prefix + "/"):
                    continue
                if suffixes and not any(path.endswith(sfx) for sfx in suffixes):
                    continue
                if excludes and any(token in path for token in excludes):
                    continue
                if path not in path_latest_commit:
                    path_latest_commit[path] = sha

        for src_path, sha in sorted(path_latest_commit.items()):
            rel = src_path[len(source_prefix) + 1 :]
            target_rel = f"{target_prefix}/{rel}"
            result = {
                "kind": rule.kind,
                "source": src_path,
                "target": target_rel,
                "ref": sha,
                "status": "skipped",
            }
            try:
                data = read_blob(repo_dir, sha, src_path)
                data = merge_target_payload(repo_root, target_rel, data)
                shadow = harvest_out / "synced" / "changed_path_sync" / Path(src_path)
                write_file(shadow, data)
                target = (repo_root / target_rel).resolve()
                if not in_repo(repo_root, target):
                    result["status"] = "error"
                    result["error"] = "target escapes repo root"
                elif apply_changes:
                    changed = write_file(target, data)
                    result["status"] = "changed" if changed else "unchanged"
                else:
                    result["status"] = "planned"
            except Exception as exc:
                result["status"] = "error"
                result["error"] = str(exc)
            results.append(result)

    return results


def write_report(out_dir: Path, payload: Dict) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / "transfer-report.json"
    md_path = out_dir / "transfer-report.md"
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines: List[str] = []
    lines.append("# Harvest Transfer Report")
    lines.append("")
    lines.append(f"- apply_changes: `{int(bool(payload.get('apply_changes')))}`")
    lines.append(f"- auto_focus_sync: `{int(bool(payload.get('auto_focus_sync')))}`")
    lines.append(f"- include_unmapped: `{int(bool(payload.get('include_unmapped')))}`")
    lines.append(f"- repo_errors: **{int(payload.get('repo_errors') or 0)}**")
    lines.append(f"- repos: **{len(payload.get('repos') or [])}**")
    lines.append("")
    for repo in payload.get("repos") or []:
        lines.append(f"## {repo.get('alias')}")
        lines.append("")
        lines.append(f"- repo: `{repo.get('repo')}`")
        lines.append(f"- branch: `{repo.get('branch')}`")
        if repo.get("resolved_branch"):
            lines.append(f"- resolved_branch: `{repo.get('resolved_branch')}`")
        lines.append(f"- head_sha: `{repo.get('head_sha', '')[:12]}`")
        lines.append(f"- status: `{repo.get('status', 'processed')}`")
        lines.append(f"- auto_focus_sync: `{int(bool(repo.get('auto_focus_sync', 0)))}`")
        lines.append(f"- selected_commits: **{len(repo.get('selected_commits') or [])}**")
        lines.append(f"- sync changed: **{repo.get('sync_changed', 0)}**")
        lines.append(f"- sync unchanged: **{repo.get('sync_unchanged', 0)}**")
        lines.append(f"- sync errors: **{repo.get('sync_errors', 0)}**")
        lines.append("")
        lines.append("| Source | Target | Ref | Status |")
        lines.append("| --- | --- | --- | --- |")
        for row in repo.get("sync_results") or []:
            lines.append(
                f"| `{row.get('source','')}` | `{row.get('target','')}` | `{row.get('ref','')}` | `{row.get('status','')}` |"
            )
        lines.append("")
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Harvest selected commits and apply local transfer rules")
    parser.add_argument("--repo-file", default="ci/reverse/online_intake_repos.json")
    parser.add_argument("--map-file", default="ci/reverse/transfer_map.json")
    parser.add_argument("--commit-scan-json", default="docs/reverse/online-intake/commit-scan.json")
    parser.add_argument("--git-workdir", default="docs/reverse/online-intake/_git-cache")
    parser.add_argument("--out-dir", default="docs/reverse/online-intake/harvest")
    parser.add_argument("--aliases", default="")
    parser.add_argument("--all-repos", action="store_true")
    parser.add_argument("--max-commits-per-repo", type=int, default=24)
    parser.add_argument("--git-depth", type=int, default=120)
    parser.add_argument("--apply", choices=("0", "1"), default="1")
    parser.add_argument("--skip-no-sync", choices=("0", "1"), default="1")
    parser.add_argument("--auto-focus-sync", choices=("0", "1"), default="1")
    parser.add_argument("--include-unmapped", choices=("0", "1"), default="1")
    parser.add_argument("--fail-on-repo-errors", choices=("0", "1"), default="0")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    repo_specs = parse_repo_specs((repo_root / args.repo_file))
    alias_filter = {x.strip() for x in args.aliases.split(",") if x.strip()}
    map_specs = parse_map((repo_root / args.map_file), alias_filter or None)
    include_unmapped = args.include_unmapped == "1"
    if include_unmapped:
        map_specs = add_unmapped_specs(map_specs, repo_specs, alias_filter or None)
    commit_scan = parse_commit_scan((repo_root / args.commit_scan_json))

    if not args.all_repos:
        map_specs = [spec for spec in map_specs if spec.enabled]
    if not map_specs:
        raise SystemExit("[harvest-transfer][error] no repo entries selected from transfer map")

    git_workdir = (repo_root / args.git_workdir)
    out_dir = (repo_root / args.out_dir)
    apply_changes = args.apply == "1"
    skip_no_sync = args.skip_no_sync == "1"
    auto_focus_sync = args.auto_focus_sync == "1"
    results = {
        "apply_changes": apply_changes,
        "skip_no_sync": skip_no_sync,
        "auto_focus_sync": auto_focus_sync,
        "include_unmapped": include_unmapped,
        "repo_errors": 0,
        "repos": [],
    }

    for harvest_spec in map_specs:
        if harvest_spec.alias not in repo_specs:
            results["repo_errors"] += 1
            results["repos"].append(
                {
                    "alias": harvest_spec.alias,
                    "error": "alias not found in repo-file",
                    "sync_results": [],
                    "status": "error",
                }
            )
            continue

        repo_spec = repo_specs[harvest_spec.alias]
        sync_rules: List[SyncRule] = list(harvest_spec.sync_rules)
        auto_focus_sync_applied = False
        if auto_focus_sync and not sync_rules and repo_spec.focus_paths:
            sync_rules = build_auto_focus_sync_rules(repo_spec)
            auto_focus_sync_applied = bool(sync_rules)

        if skip_no_sync and not sync_rules:
            results["repos"].append(
                {
                    "alias": harvest_spec.alias,
                    "repo": f"{repo_spec.owner}/{repo_spec.repo}",
                    "branch": repo_spec.branch,
                    "head_sha": "",
                    "selected_commits": [],
                    "sync_changed": 0,
                    "sync_unchanged": 0,
                    "sync_errors": 0,
                    "sync_results": [],
                    "status": "skipped_no_sync_rules",
                    "auto_focus_sync": 0,
                }
            )
            continue
        print(f"[harvest-transfer] processing {harvest_spec.alias}", flush=True)
        try:
            repo_dir = ensure_repo(repo_spec, git_workdir)
            selected_commits, commit_meta, _ = select_commits(
                repo_spec=repo_spec,
                harvest_spec=harvest_spec,
                commit_scan_row=commit_scan.get(harvest_spec.alias, {}),
                max_commits=max(1, args.max_commits_per_repo),
            )
            resolved_branch = fetch_repo(repo_dir, repo_spec.branch, selected_commits, args.git_depth)
            configure_sparse_checkout(repo_dir, harvest_spec.harvest_paths)
            head_sha = checkout_head(repo_dir, resolved_branch)
            repo_out = out_dir / harvest_spec.alias
            repo_out.mkdir(parents=True, exist_ok=True)

            for sha in selected_commits:
                row = commit_meta.get(sha, {})
                changed_paths = [str(x).strip() for x in (row.get("changed_paths") or []) if str(x).strip()]
                if not changed_paths:
                    changed_paths = commit_changed_paths(repo_dir, sha)
                    row["changed_paths"] = changed_paths
                    commit_meta[sha] = row
                harvest_commit_artifacts(
                    repo_dir=repo_dir,
                    out_dir=repo_out,
                    sha=sha,
                    changed_paths=changed_paths,
                    harvest_paths=harvest_spec.harvest_paths,
                )

            sync_results = apply_sync_rules(
                repo_root=repo_root,
                repo_spec=repo_spec,
                repo_dir=repo_dir,
                harvest_out=repo_out,
                selected_commits=selected_commits,
                commit_meta=commit_meta,
                rules=sync_rules,
                apply_changes=apply_changes,
            )

            changed = sum(1 for row in sync_results if row.get("status") == "changed")
            unchanged = sum(1 for row in sync_results if row.get("status") == "unchanged")
            errors = sum(1 for row in sync_results if row.get("status") == "error")
            results["repos"].append(
                {
                    "alias": harvest_spec.alias,
                    "repo": f"{repo_spec.owner}/{repo_spec.repo}",
                    "branch": repo_spec.branch,
                    "resolved_branch": resolved_branch,
                    "head_sha": head_sha,
                    "selected_commits": selected_commits,
                    "sync_changed": changed,
                    "sync_unchanged": unchanged,
                    "sync_errors": errors,
                    "sync_results": sync_results,
                    "auto_focus_sync": int(auto_focus_sync_applied),
                    "status": "processed",
                }
            )
            if errors:
                results["repo_errors"] += 1
        except Exception as exc:
            results["repo_errors"] += 1
            results["repos"].append(
                {
                    "alias": harvest_spec.alias,
                    "repo": f"{repo_spec.owner}/{repo_spec.repo}",
                    "branch": repo_spec.branch,
                    "head_sha": "",
                    "selected_commits": [],
                    "sync_changed": 0,
                    "sync_unchanged": 0,
                    "sync_errors": 1,
                    "sync_results": [],
                    "auto_focus_sync": int(auto_focus_sync_applied),
                    "status": "error",
                    "error": str(exc),
                }
            )

    write_report(out_dir, results)
    print(f"[harvest-transfer] wrote {out_dir / 'transfer-report.json'}")
    print(f"[harvest-transfer] wrote {out_dir / 'transfer-report.md'}")
    if args.fail_on_repo_errors == "1" and int(results.get("repo_errors") or 0) > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
