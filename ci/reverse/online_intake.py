#!/usr/bin/env python3
import argparse
import base64
import json
import subprocess
import time
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple


@dataclass
class RepoSpec:
    alias: str
    owner: str
    repo: str
    branch: Optional[str] = None
    enabled_default: bool = True
    focus_paths: List[str] = field(default_factory=list)
    pinned_commits: List[str] = field(default_factory=list)


CORE_SPECS = [
    RepoSpec("coffin_winlator", "coffincolors", "winlator", "cmod_bionic"),
    RepoSpec("coffin_wine", "coffincolors", "wine", "arm64ec"),
    RepoSpec("gamenative_protonwine", "GameNative", "proton-wine", "proton_10.0"),
    RepoSpec("froggingfamily_wine_tkg_git", "Frogging-Family", "wine-tkg-git", "master"),
]


GH_RETRIES = 4
GH_RETRY_DELAY_SEC = 1.5
CMD_TIMEOUT_SEC = 120.0
GIT_FETCH_TIMEOUT_SEC = 420.0


def run_text(cmd: Sequence[str], cwd: Optional[Path] = None, timeout_sec: Optional[float] = None) -> str:
    timeout = CMD_TIMEOUT_SEC if timeout_sec is None else max(1.0, timeout_sec)
    try:
        proc = subprocess.run(
            list(cmd),
            cwd=str(cwd) if cwd else None,
            text=True,
            capture_output=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"command timed out after {timeout:.0f}s: {' '.join(cmd)}")
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "command failed").strip()
        raise RuntimeError(f"command failed: {' '.join(cmd)}: {err[:260]}")
    return proc.stdout


def run_bytes(cmd: Sequence[str], cwd: Optional[Path] = None, timeout_sec: Optional[float] = None) -> bytes:
    timeout = CMD_TIMEOUT_SEC if timeout_sec is None else max(1.0, timeout_sec)
    try:
        proc = subprocess.run(
            list(cmd),
            cwd=str(cwd) if cwd else None,
            text=False,
            capture_output=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"command timed out after {timeout:.0f}s: {' '.join(cmd)}")
    if proc.returncode != 0:
        err = (proc.stderr or b"command failed").decode("utf-8", errors="replace").strip()
        raise RuntimeError(f"command failed: {' '.join(cmd)}: {err[:260]}")
    return proc.stdout


def should_retry_gh_error(message: str) -> bool:
    text = message.lower()
    retry_signals = (
        "http 500",
        "http 502",
        "http 503",
        "http 504",
        "timed out",
        "timeout",
        "connection reset",
        "connection refused",
        "temporary failure",
        "tls",
        "rate limit",
    )
    return any(token in text for token in retry_signals)


def gh_api(path: str) -> Dict:
    last_error = ""
    for attempt in range(GH_RETRIES + 1):
        proc = subprocess.run(["gh", "api", path], text=True, capture_output=True)
        if proc.returncode == 0:
            return json.loads(proc.stdout)
        message = (proc.stderr or proc.stdout or "unknown gh api error").strip()
        last_error = message
        if attempt >= GH_RETRIES or not should_retry_gh_error(message):
            break
        time.sleep(GH_RETRY_DELAY_SEC * (attempt + 1))
    raise RuntimeError(f"gh api failed for {path}: {last_error[:260]}")


def classify_path(path: str) -> str:
    p = path.lower()
    if "xserver" in p or "vulkan" in p or "turnip" in p or "winex11" in p:
        return "graphics_xserver"
    if "box64" in p or "fex" in p or "hangover" in p or "translator" in p:
        return "cpu_translation"
    if "launcher" in p or "xenvironment" in p:
        return "launcher_runtime"
    if "termux" in p or "proot" in p or "chroot" in p:
        return "termux_runtime"
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


def is_text_candidate(path: str) -> bool:
    p = path.lower()
    if p.endswith(
        (
            ".png",
            ".jpg",
            ".jpeg",
            ".webp",
            ".gif",
            ".ico",
            ".so",
            ".dll",
            ".exe",
            ".bin",
            ".tzst",
            ".zip",
            ".xz",
            ".7z",
            ".apk",
        )
    ):
        return False
    return True


def select_focus_paths(paths: List[str], max_paths: int, preferred_paths: Optional[List[str]] = None) -> List[str]:
    priority_patterns = [
        "xserver",
        "xenvironment",
        "guestprogramlauncher",
        "winex11",
        "mouse.c",
        "window.c",
        "winebrowser/main.c",
        "wineboot/wineboot.c",
        "loader.c",
        "ntdll.spec",
        "wow64",
        "containerdetailfragment",
        "adrenotoolsfragment",
        "contentsmanager",
        "graphicsdriverconfigdialog",
        "xserverdisplayactivity",
    ]

    out: List[str] = []
    seen = set()
    path_set = set(paths)
    path_lut = [(path, path.lower()) for path in paths]

    for pref in preferred_paths or []:
        wanted = pref.strip().lstrip("/")
        if not wanted:
            continue
        matches: List[str] = []
        if wanted in path_set:
            matches = [wanted]
        else:
            wl = wanted.lower()
            for path, lowered in path_lut:
                if lowered.endswith(wl) or wl in lowered:
                    matches.append(path)
        for path in sorted(matches):
            if not is_text_candidate(path) or path in seen:
                continue
            out.append(path)
            seen.add(path)
            if len(out) >= max_paths:
                return out

    scored = []
    for path in paths:
        p = path.lower()
        if not is_text_candidate(path) or path in seen:
            continue
        score = 0
        for idx, marker in enumerate(priority_patterns):
            if marker in p:
                score += len(priority_patterns) - idx
        if score:
            scored.append((score, path))
    scored.sort(key=lambda x: (-x[0], x[1]))

    for _, path in scored:
        if path in seen:
            continue
        seen.add(path)
        out.append(path)
        if len(out) >= max_paths:
            break
    return out


def extract_focus_markers(path: str, text: str) -> List[str]:
    if not text:
        return []
    markers = [
        "WRAPPER_VK_VERSION",
        "VK_API_VERSION",
        "MESA_VK_WSI_PRESENT_MODE",
        "TU_DEBUG",
        "ZINK_DESCRIPTORS",
        "NtUserSendHardwareInput",
        "SEND_HWMSG_NO_RAW",
        "get_send_mouse_flags",
        "BOX64_DYNAREC",
        "BOX64_DYNAREC_STRONGMEM",
        "BOX64_NOBANNER",
        "BOX64_LOG",
        "FEXCore",
        "FEXBash",
        "FEX_ROOTFS",
        "FEXINTERPRETER",
        "PROOT_TMP_DIR",
        "XDG_RUNTIME_DIR",
        "WINE_OPEN_WITH_ANDROID_BROWSER",
        "WINEDEBUG",
        "AERO_LIBRARY_CONFLICTS",
        "AERO_LIBRARY_CONFLICT_COUNT",
        "AERO_LIBRARY_CONFLICT_SHA256",
        "AERO_LIBRARY_REPRO_ID",
        "RUNTIME_LIBRARY_CONFLICT_SNAPSHOT",
        "RUNTIME_LIBRARY_CONFLICT_DETECTED",
        "AERO_RUNTIME_LOGGING_MODE",
        "AERO_RUNTIME_LOGGING_REQUIRED",
        "AERO_RUNTIME_LOGGING_COVERAGE",
        "AERO_RUNTIME_LOGGING_COVERAGE_SHA256",
        "DXVK",
        "VKD3D",
        "D8VK",
        "DXVK_NVAPI",
        "WINE_FULLSCREEN_FSR",
        "WINE_FULLSCREEN_FSR_STRENGTH",
        "WINE_FULLSCREEN_FSR_MODE",
        "VKBASALT_CONFIG",
        "AERO_DX_DIRECT_MAP_EXTENDED",
        "cnc-ddraw",
        "RtlWow64SuspendThread",
        "Wow64SuspendLocalThread",
        "libarm64ecfex.dll",
        "THREAD_CREATE_FLAGS_SKIP_LOADER_INIT",
        "THREAD_CREATE_FLAGS_BYPASS_PROCESS_FREEZE",
        "xinput2_available",
        "x11drv_xinput2_enable",
        "ContentProfile",
        "REMOTE_PROFILES",
    ]
    found = [m for m in markers if m in text]
    if "get_send_mouse_flags" in found and "SEND_HWMSG_NO_RAW" not in found:
        found.append("SEND_HWMSG_NO_RAW")
    if len(found) > 16:
        found = found[:16]
    return found


def extract_marker_snippets(text: str, markers: List[str], max_snippets: int = 8) -> List[Dict]:
    if not text or not markers:
        return []
    lines = text.splitlines()
    snippets: List[Dict] = []
    seen_markers = set()
    for idx, line in enumerate(lines, start=1):
        for marker in markers:
            if marker in seen_markers:
                continue
            if marker in line:
                snippet = line.strip()
                if len(snippet) > 220:
                    snippet = snippet[:217] + "..."
                snippets.append(
                    {
                        "marker": marker,
                        "line": idx,
                        "code": snippet,
                    }
                )
                seen_markers.add(marker)
                if len(snippets) >= max_snippets:
                    return snippets
                break
    return snippets


def collect_tree_paths_gh(spec: RepoSpec, branch: str) -> List[str]:
    tree = gh_api(f"repos/{spec.owner}/{spec.repo}/git/trees/{branch}?recursive=1")
    paths: List[str] = []
    for node in tree.get("tree", []):
        if node.get("type") != "blob":
            continue
        path = node.get("path", "")
        if path:
            paths.append(path)
    return paths


def fetch_text_file_gh(spec: RepoSpec, branch: str, path: str, max_bytes: int = 250_000) -> str:
    try:
        payload = gh_api(f"repos/{spec.owner}/{spec.repo}/contents/{path}?ref={branch}")
    except RuntimeError as exc:
        msg = str(exc).lower()
        if "not found" in msg or "http 404" in msg:
            return ""
        raise
    content = payload.get("content", "")
    encoding = payload.get("encoding", "")
    size = int(payload.get("size", 0) or 0)
    if not content or encoding != "base64" or size > max_bytes:
        return ""
    raw = base64.b64decode(content, validate=False)
    return raw.decode("utf-8", errors="replace")


def git_repo_url(spec: RepoSpec) -> str:
    return f"https://github.com/{spec.owner}/{spec.repo}.git"


def ensure_git_repo(spec: RepoSpec, git_workdir: Path) -> Path:
    repo_dir = git_workdir / spec.alias
    repo_dir.mkdir(parents=True, exist_ok=True)
    if not (repo_dir / ".git").exists():
        run_text(["git", "init"], cwd=repo_dir)
    lock_file = repo_dir / ".git" / "index.lock"
    if lock_file.exists():
        lock_file.unlink()

    remote_url = git_repo_url(spec)
    current_remote = ""
    try:
        current_remote = run_text(["git", "remote", "get-url", "origin"], cwd=repo_dir).strip()
    except RuntimeError:
        current_remote = ""

    if current_remote:
        if current_remote != remote_url:
            run_text(["git", "remote", "set-url", "origin", remote_url], cwd=repo_dir)
    else:
        run_text(["git", "remote", "add", "origin", remote_url], cwd=repo_dir)

    return repo_dir


def resolve_default_branch_git(spec: RepoSpec) -> str:
    raw = run_text(["git", "ls-remote", "--symref", git_repo_url(spec), "HEAD"])
    for line in raw.splitlines():
        line = line.strip()
        parts = line.split()
        if len(parts) < 3 or parts[0] != "ref:" or parts[-1] != "HEAD":
            continue
        ref_name = parts[1]
        if ref_name.startswith("refs/heads/"):
            return ref_name[len("refs/heads/") :]
    return "main"


def gh_branch_commits_exist(spec: RepoSpec, branch: str) -> bool:
    branch = (branch or "").strip()
    if not branch:
        return False
    try:
        payload = gh_api(f"repos/{spec.owner}/{spec.repo}/commits?sha={branch}&per_page=1")
    except Exception:
        return False
    return isinstance(payload, list)


def resolve_effective_branch_gh(spec: RepoSpec, repo_meta: Dict) -> Tuple[str, str]:
    requested = (spec.branch or "").strip()
    default = str(repo_meta.get("default_branch") or "").strip()
    candidates = [requested, default, "main", "master"]
    seen = set()
    for branch in candidates:
        value = (branch or "").strip()
        if not value or value in seen:
            continue
        seen.add(value)
        if gh_branch_commits_exist(spec, value):
            return value, default
    fallback = requested or default or "main"
    return fallback, default


def git_remote_branch_exists(repo_dir: Path, branch: str, timeout_sec: float = 120.0) -> bool:
    value = (branch or "").strip()
    if not value:
        return False
    raw = run_text(
        ["git", "ls-remote", "--heads", "origin", value],
        cwd=repo_dir,
        timeout_sec=timeout_sec,
    )
    return bool(raw.strip())


def resolve_effective_branch_git(spec: RepoSpec, repo_dir: Path) -> Tuple[str, str]:
    requested = (spec.branch or "").strip()
    default = resolve_default_branch_git(spec)
    candidates = [requested, default, "main", "master"]
    seen = set()
    for branch in candidates:
        value = (branch or "").strip()
        if not value or value in seen:
            continue
        seen.add(value)
        if git_remote_branch_exists(repo_dir, value):
            return value, default
    fallback = requested or default or "main"
    return fallback, default


def git_commit_exists(repo_dir: Path, sha: str) -> bool:
    proc = subprocess.run(
        ["git", "cat-file", "-e", f"{sha}^{{commit}}"],
        cwd=str(repo_dir),
        text=True,
        capture_output=True,
    )
    return proc.returncode == 0


def git_fetch_targeted(
    repo_dir: Path,
    branch: str,
    depth: int,
    pinned_commits: List[str],
    fetch_timeout_sec: float,
) -> None:
    depth = max(1, depth)
    fetch_ref = f"+refs/heads/{branch}:refs/remotes/origin/{branch}"
    run_text(
        ["git", "fetch", "--depth", str(depth), "--filter=blob:none", "--no-tags", "origin", fetch_ref],
        cwd=repo_dir,
        timeout_sec=fetch_timeout_sec,
    )
    for sha in pinned_commits:
        commit = sha.strip()
        if len(commit) < 7:
            continue
        try:
            run_text(
                ["git", "fetch", "--depth", "1", "--filter=blob:none", "--no-tags", "origin", commit],
                cwd=repo_dir,
                timeout_sec=max(60.0, fetch_timeout_sec / 2.0),
            )
        except RuntimeError:
            # Keep intake resilient if an optional pinned commit is unavailable.
            pass
    # No checkout: we work directly off remote refs via git show/log/ls-tree.


def collect_tree_paths_git(repo_dir: Path, ref: str = "HEAD") -> List[str]:
    raw = run_text(["git", "ls-tree", "-r", "--name-only", ref], cwd=repo_dir)
    return [line.strip() for line in raw.splitlines() if line.strip()]


def fetch_text_file_git(repo_dir: Path, ref: str, path: str, max_bytes: int = 250_000) -> str:
    try:
        size_text = run_text(["git", "cat-file", "-s", f"{ref}:{path}"], cwd=repo_dir).strip()
        size = int(size_text)
        if size > max_bytes:
            return ""
        raw = run_bytes(["git", "show", f"{ref}:{path}"], cwd=repo_dir)
        return raw.decode("utf-8", errors="replace")
    except Exception:
        return ""


def collect_repo_gh(spec: RepoSpec, limit: int, max_focus_files: int, mode: str, scope: str) -> Dict:
    repo_meta = gh_api(f"repos/{spec.owner}/{spec.repo}")
    effective_branch, default_branch = resolve_effective_branch_gh(spec, repo_meta)
    if not effective_branch:
        raise RuntimeError(f"unable to resolve branch for {spec.owner}/{spec.repo}")

    commits = []
    file_hits: Counter = Counter()
    cat_hits: Counter = Counter()
    author_hits: Counter = Counter()
    commit_rows: List[Dict] = []

    if mode == "full":
        commits = gh_api(f"repos/{spec.owner}/{spec.repo}/commits?sha={effective_branch}&per_page={limit}")
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

    focus_prefetch: Dict[str, str] = {}
    if scope == "focused" and spec.focus_paths:
        focus_paths = []
        seen = set()
        for value in spec.focus_paths:
            path = str(value).strip().lstrip("/")
            if not path or path in seen or not is_text_candidate(path):
                continue
            text = fetch_text_file_gh(spec, effective_branch, path)
            if not text:
                continue
            focus_paths.append(path)
            focus_prefetch[path] = text
            seen.add(path)
            if len(focus_paths) >= max_focus_files:
                break
        if focus_paths:
            tree_paths = list(focus_paths)
        else:
            tree_paths = collect_tree_paths_gh(spec, effective_branch)
            focus_paths = select_focus_paths(tree_paths, max_paths=max_focus_files, preferred_paths=spec.focus_paths)
    else:
        tree_paths = collect_tree_paths_gh(spec, effective_branch)
        focus_paths = select_focus_paths(tree_paths, max_paths=max_focus_files, preferred_paths=spec.focus_paths)

    tree_cat_hits: Counter = Counter()
    for path in tree_paths:
        tree_cat_hits[classify_path(path)] += 1

    if mode != "full":
        cat_hits = Counter(tree_cat_hits)

    if not focus_paths:
        focus_paths = select_focus_paths(tree_paths, max_paths=max_focus_files, preferred_paths=spec.focus_paths)
    focus_rows: List[Dict] = []
    for path in focus_paths:
        text = focus_prefetch.get(path)
        if text is None:
            text = fetch_text_file_gh(spec, effective_branch, path)
        markers = extract_focus_markers(path, text)
        snippets = extract_marker_snippets(text, markers)
        focus_rows.append(
            {
                "path": path,
                "markers": markers,
                "snippets": snippets,
            }
        )

    return {
        "repo": f"{spec.owner}/{spec.repo}",
        "transport": "gh",
        "mode": mode,
        "scope": scope,
        "requested_branch": spec.branch or "",
        "branch": effective_branch,
        "default_branch": default_branch,
        "updated_at": repo_meta.get("updated_at", ""),
        "stargazers_count": repo_meta.get("stargazers_count", 0),
        "open_issues_count": repo_meta.get("open_issues_count", 0),
        "commits_scanned": len(commits),
        "top_files": file_hits.most_common(40),
        "top_categories": cat_hits.most_common(),
        "tree_files_scanned": len(tree_paths),
        "tree_top_categories": tree_cat_hits.most_common(),
        "top_authors": author_hits.most_common(10),
        "recent_commits": commit_rows,
        "focus_files": focus_rows,
    }


def collect_repo_git(
    spec: RepoSpec,
    limit: int,
    max_focus_files: int,
    mode: str,
    scope: str,
    git_workdir: Path,
    git_depth: int,
    git_fetch_timeout_sec: float,
) -> Dict:
    repo_dir = ensure_git_repo(spec, git_workdir)
    effective_branch, default_branch = resolve_effective_branch_git(spec, repo_dir)
    if not effective_branch:
        raise RuntimeError(f"unable to resolve branch for {spec.owner}/{spec.repo}")

    git_fetch_targeted(repo_dir, effective_branch, git_depth, spec.pinned_commits, git_fetch_timeout_sec)
    target_ref = f"refs/remotes/origin/{effective_branch}"
    head_sha = run_text(["git", "rev-parse", target_ref], cwd=repo_dir).strip()
    updated_at = run_text(["git", "show", "-s", "--format=%cI", head_sha], cwd=repo_dir).strip()

    file_hits: Counter = Counter()
    cat_hits: Counter = Counter()
    author_hits: Counter = Counter()
    commit_rows: List[Dict] = []
    commit_shas: List[str] = []

    if mode == "full":
        log_lines = run_text(
            ["git", "log", f"--max-count={max(1, limit)}", "--pretty=format:%H%x1f%an%x1f%s", target_ref],
            cwd=repo_dir,
        ).splitlines()
        commit_meta: Dict[str, Dict[str, str]] = {}
        for line in log_lines:
            parts = line.split("\x1f", 2)
            if len(parts) != 3:
                continue
            sha, author, subject = parts
            commit_shas.append(sha)
            commit_meta[sha] = {"author": author, "subject": subject}

        for sha in spec.pinned_commits:
            pinned_sha = sha.strip()
            if not pinned_sha or pinned_sha in commit_meta:
                continue
            if not git_commit_exists(repo_dir, pinned_sha):
                continue
            meta_line = run_text(["git", "show", "-s", "--format=%H%x1f%an%x1f%s", pinned_sha], cwd=repo_dir).strip()
            parts = meta_line.split("\x1f", 2)
            if len(parts) != 3:
                continue
            canonical_sha, author, subject = parts
            if canonical_sha in commit_meta:
                continue
            commit_shas.append(canonical_sha)
            commit_meta[canonical_sha] = {"author": author, "subject": subject}

        for sha in commit_shas:
            meta = commit_meta.get(sha, {})
            author = meta.get("author", "unknown")
            subject = meta.get("subject", "")
            author_hits[author] += 1
            touched_raw = run_text(["git", "show", "--name-only", "--pretty=format:", sha], cwd=repo_dir)
            touched = [line.strip() for line in touched_raw.splitlines() if line.strip()]
            for path in touched:
                file_hits[path] += 1
                cat_hits[classify_path(path)] += 1
            commit_rows.append(
                {
                    "sha": sha,
                    "subject": subject,
                    "author": author,
                    "files": touched,
                }
            )

    focus_prefetch: Dict[str, str] = {}
    if scope == "focused" and spec.focus_paths:
        focus_paths = []
        seen = set()
        for value in spec.focus_paths:
            path = str(value).strip().lstrip("/")
            if not path or path in seen or not is_text_candidate(path):
                continue
            text = fetch_text_file_git(repo_dir, target_ref, path)
            if not text:
                continue
            focus_paths.append(path)
            focus_prefetch[path] = text
            seen.add(path)
            if len(focus_paths) >= max_focus_files:
                break
        if focus_paths:
            tree_paths = list(focus_paths)
        else:
            tree_paths = collect_tree_paths_git(repo_dir, ref=target_ref)
            focus_paths = select_focus_paths(tree_paths, max_paths=max_focus_files, preferred_paths=spec.focus_paths)
    else:
        tree_paths = collect_tree_paths_git(repo_dir, ref=target_ref)
        focus_paths = select_focus_paths(tree_paths, max_paths=max_focus_files, preferred_paths=spec.focus_paths)

    tree_cat_hits: Counter = Counter()
    for path in tree_paths:
        tree_cat_hits[classify_path(path)] += 1

    if mode != "full":
        cat_hits = Counter(tree_cat_hits)

    if not focus_paths:
        focus_paths = select_focus_paths(tree_paths, max_paths=max_focus_files, preferred_paths=spec.focus_paths)
    focus_rows: List[Dict] = []
    for path in focus_paths:
        text = focus_prefetch.get(path)
        if text is None:
            text = fetch_text_file_git(repo_dir, target_ref, path)
        markers = extract_focus_markers(path, text)
        snippets = extract_marker_snippets(text, markers)
        focus_rows.append(
            {
                "path": path,
                "markers": markers,
                "snippets": snippets,
            }
        )

    return {
        "repo": f"{spec.owner}/{spec.repo}",
        "transport": "git",
        "mode": mode,
        "scope": scope,
        "requested_branch": spec.branch or "",
        "branch": effective_branch,
        "default_branch": default_branch,
        "updated_at": updated_at,
        "stargazers_count": 0,
        "open_issues_count": 0,
        "head_sha": head_sha,
        "commits_scanned": len(commit_rows),
        "top_files": file_hits.most_common(40),
        "top_categories": cat_hits.most_common(),
        "tree_files_scanned": len(tree_paths),
        "tree_top_categories": tree_cat_hits.most_common(),
        "top_authors": author_hits.most_common(10),
        "recent_commits": commit_rows,
        "focus_files": focus_rows,
    }


def write_repo_markdown(report: Dict, out_file: Path) -> None:
    lines: List[str] = []
    lines.append(f"# Online Intake: `{report['repo']}`")
    lines.append("")
    lines.append(f"- Transport: `{report.get('transport', 'gh')}`")
    lines.append(f"- Scope: `{report.get('scope', 'tree')}`")
    lines.append(f"- Branch analyzed: `{report['branch']}`")
    lines.append(f"- Intake mode: `{report.get('mode', 'full')}`")
    lines.append(f"- Default branch: `{report['default_branch']}`")
    lines.append(f"- Updated at: `{report['updated_at']}`")
    lines.append(f"- Commits scanned: `{report['commits_scanned']}`")
    if report.get("head_sha"):
        lines.append(f"- Head SHA: `{report['head_sha'][:12]}`")
    if report.get("stale_cache"):
        reason = str(report.get("stale_cache_reason", "")).strip()
        lines.append(f"- Stale cache: `true` ({reason[:180]})")
    lines.append("")

    lines.append("## Top categories")
    lines.append("")
    for cat, n in report.get("top_categories", []):
        lines.append(f"- `{cat}`: **{n}**")
    lines.append("")

    lines.append("## Tree-wide categories (all files)")
    lines.append("")
    lines.append(f"- files scanned: **{report.get('tree_files_scanned', 0)}**")
    for cat, n in report.get("tree_top_categories", []):
        lines.append(f"- `{cat}`: **{n}**")
    lines.append("")

    lines.append("## Top touched files")
    lines.append("")
    top_files = report.get("top_files") or []
    if top_files:
        for fn, n in top_files[:25]:
            lines.append(f"- `{fn}`: **{n}**")
    else:
        lines.append("- commit diff scan disabled in code-only mode")
    lines.append("")

    lines.append("## Recent commit subjects")
    lines.append("")
    if report.get("recent_commits"):
        for row in report["recent_commits"][:20]:
            lines.append(f"- `{row['sha'][:8]}` {row['subject']}")
    else:
        lines.append("- commit scan disabled in code-only mode")
    lines.append("")

    lines.append("## Focus file markers")
    lines.append("")
    for row in report.get("focus_files", [])[:20]:
        markers = ", ".join(row.get("markers") or []) or "-"
        lines.append(f"- `{row['path']}` -> {markers}")
        for snippet in row.get("snippets", [])[:4]:
            lines.append(
                f"  - `L{snippet.get('line', 0)}` `{snippet.get('marker', '')}`: `{snippet.get('code', '')}`"
            )

    out_file.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_combined(reports: Dict[str, Dict], errors: Dict[str, str], out_file: Path) -> None:
    def top_category_mix(report: Dict, limit: int = 6) -> str:
        items = report.get("top_categories") or []
        if not items:
            return "-"
        return ", ".join(f"{cat}={n}" for cat, n in items[:limit])

    def top_focus_markers(report: Dict, limit: int = 6) -> List[str]:
        marker_hits: Counter = Counter()
        for row in report.get("focus_files", []):
            for marker in row.get("markers") or []:
                marker_hits[marker] += 1
        return [name for name, _ in marker_hits.most_common(limit)]

    lines: List[str] = []
    lines.append("# Online Intake Combined Matrix")
    lines.append("")
    transports = sorted({report.get("transport", "gh") for report in reports.values()})
    if transports:
        lines.append(f"Transports used: {', '.join(f'`{t}`' for t in transports)}.")
    else:
        lines.append("Transports used: none.")
    lines.append("")

    lines.append("## Repo snapshots")
    lines.append("")
    if not reports:
        lines.append("- no successful reports")
    for alias, report in reports.items():
        lines.append(f"### {alias}: `{report['repo']}`")
        lines.append("")
        lines.append(f"- transport: `{report.get('transport', 'gh')}`")
        lines.append(f"- scope: `{report.get('scope', 'tree')}`")
        lines.append(f"- mode: `{report.get('mode', 'full')}`")
        lines.append(f"- branch: `{report['branch']}`")
        lines.append(f"- commits scanned: **{report['commits_scanned']}**")
        lines.append(f"- files scanned (tree): **{report.get('tree_files_scanned', 0)}**")
        if report.get("stale_cache"):
            lines.append("- stale cache: `true`")
        lines.append(f"- category mix: {top_category_mix(report)}")
        markers = ", ".join(top_focus_markers(report)) or "-"
        lines.append(f"- focus markers: {markers}")
        lines.append("")

    if errors:
        lines.append("## Intake errors")
        lines.append("")
        for alias, err in errors.items():
            lines.append(f"- `{alias}`: {err}")
        lines.append("")

    lines.append("## Cross-source marker heat")
    lines.append("")
    marker_repo_hits: Dict[str, set] = {}
    for alias, report in reports.items():
        for row in report.get("focus_files", []):
            for marker in row.get("markers") or []:
                marker_repo_hits.setdefault(marker, set()).add(alias)
    if marker_repo_hits:
        ranked = sorted(marker_repo_hits.items(), key=lambda kv: (-len(kv[1]), kv[0]))[:12]
        for marker, repo_aliases in ranked:
            alias_view = ", ".join(sorted(repo_aliases))
            lines.append(f"- `{marker}`: {len(repo_aliases)} repo(s) -> {alias_view}")
    else:
        lines.append("- no markers extracted")
    lines.append("")

    lines.append("## Cross-source focus")
    lines.append("")
    lines.append("- Runtime stability first: prioritize `arm64ec_core`, `launcher_runtime`, `container_flow`.")
    lines.append("- Defer risky `HACK`/revert clusters behind gated lanes before mainline promotion.")
    lines.append("")

    out_file.write_text("\n".join(lines) + "\n", encoding="utf-8")


def load_repo_specs(repo_file: Path, include_all: bool, aliases: Optional[set] = None) -> List[RepoSpec]:
    if not repo_file.exists():
        specs = CORE_SPECS
        if aliases:
            specs = [s for s in specs if s.alias in aliases]
        return specs

    raw = json.loads(repo_file.read_text(encoding="utf-8"))
    specs: List[RepoSpec] = []
    for item in raw:
        alias = (item.get("alias") or "").strip()
        owner = (item.get("owner") or "").strip()
        repo = (item.get("repo") or "").strip()
        branch = (item.get("branch") or "").strip() or None
        enabled_default = bool(item.get("enabled_default", True))
        focus_paths = [
            str(value).strip()
            for value in (item.get("focus_paths") or [])
            if str(value).strip()
        ]
        pinned_commits = [
            str(value).strip()
            for value in (item.get("pinned_commits") or [])
            if str(value).strip()
        ]
        if not alias or not owner or not repo:
            continue
        if aliases and alias not in aliases:
            continue
        if not include_all and not enabled_default:
            continue
        specs.append(
            RepoSpec(
                alias=alias,
                owner=owner,
                repo=repo,
                branch=branch,
                enabled_default=enabled_default,
                focus_paths=focus_paths,
                pinned_commits=pinned_commits,
            )
        )
    return specs


def load_available_aliases(repo_file: Path) -> set:
    if not repo_file.exists():
        return {spec.alias for spec in CORE_SPECS}
    try:
        raw = json.loads(repo_file.read_text(encoding="utf-8"))
    except Exception:
        return set()
    aliases = set()
    if isinstance(raw, list):
        for item in raw:
            if not isinstance(item, dict):
                continue
            alias = str(item.get("alias", "")).strip()
            if alias:
                aliases.add(alias)
    return aliases


def main() -> int:
    global GH_RETRIES, GH_RETRY_DELAY_SEC, CMD_TIMEOUT_SEC, GIT_FETCH_TIMEOUT_SEC
    parser = argparse.ArgumentParser(description="Online reverse intake via GitHub API or targeted git clone")
    parser.add_argument("--out-dir", default="docs/reverse/online-intake")
    parser.add_argument("--limit", type=int, default=8)
    parser.add_argument("--max-focus-files", type=int, default=6)
    parser.add_argument("--repo-file", default="ci/reverse/online_intake_repos.json")
    parser.add_argument("--all-repos", action="store_true")
    parser.add_argument("--aliases", default="", help="comma-separated repo aliases to include")
    parser.add_argument("--mode", choices=("code-only", "full"), default="code-only")
    parser.add_argument("--scope", choices=("focused", "tree"), default="focused")
    parser.add_argument("--transport", choices=("gh", "git"), default="gh")
    parser.add_argument("--git-workdir", default="docs/reverse/online-intake/_git-cache")
    parser.add_argument("--git-depth", type=int, default=80)
    parser.add_argument("--cmd-timeout-sec", type=float, default=120.0)
    parser.add_argument("--git-fetch-timeout-sec", type=float, default=420.0)
    parser.add_argument("--gh-retries", type=int, default=4)
    parser.add_argument("--gh-retry-delay-sec", type=float, default=1.5)
    args = parser.parse_args()
    GH_RETRIES = max(0, args.gh_retries)
    GH_RETRY_DELAY_SEC = max(0.2, args.gh_retry_delay_sec)
    CMD_TIMEOUT_SEC = max(10.0, args.cmd_timeout_sec)
    GIT_FETCH_TIMEOUT_SEC = max(30.0, args.git_fetch_timeout_sec)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    repo_file = Path(args.repo_file)
    alias_filter = {x.strip() for x in args.aliases.split(",") if x.strip()}
    available_aliases = load_available_aliases(repo_file)
    if alias_filter:
        missing_aliases = sorted(alias_filter - available_aliases)
        if missing_aliases:
            raise SystemExit(
                f"[online-intake][error] unknown aliases: {', '.join(missing_aliases)}; "
                f"available: {', '.join(sorted(available_aliases))}"
            )
    specs = load_repo_specs(repo_file, include_all=args.all_repos, aliases=alias_filter or None)
    if not specs:
        raise SystemExit("[online-intake][error] no repositories selected for intake")
    git_workdir = Path(args.git_workdir)
    if args.transport == "git":
        git_workdir.mkdir(parents=True, exist_ok=True)

    reports: Dict[str, Dict] = {}
    errors: Dict[str, str] = {}
    for spec in specs:
        json_path = out_dir / f"{spec.alias}.json"
        md_path = out_dir / f"{spec.alias}.md"
        print(f"[online-intake] collecting {spec.alias} via {args.transport}", flush=True)
        try:
            if args.transport == "git":
                report = collect_repo_git(
                    spec=spec,
                    limit=args.limit,
                    max_focus_files=args.max_focus_files,
                    mode=args.mode,
                    scope=args.scope,
                    git_workdir=git_workdir,
                    git_depth=args.git_depth,
                    git_fetch_timeout_sec=GIT_FETCH_TIMEOUT_SEC,
                )
            else:
                report = collect_repo_gh(spec, args.limit, args.max_focus_files, args.mode, args.scope)
            reports[spec.alias] = report
            json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            write_repo_markdown(report, md_path)
            print(f"[online-intake] done {spec.alias}", flush=True)
        except Exception as exc:
            errors[spec.alias] = str(exc)
            print(f"[online-intake][warn] failed {spec.alias}: {exc}", flush=True)
            if json_path.exists():
                try:
                    stale_report = json.loads(json_path.read_text(encoding="utf-8"))
                    if isinstance(stale_report, dict) and stale_report:
                        stale_report["stale_cache"] = True
                        stale_report["stale_cache_reason"] = str(exc)
                        stale_report["stale_cache_transport"] = args.transport
                        reports[spec.alias] = stale_report
                        write_repo_markdown(stale_report, md_path)
                except Exception:
                    pass

    combined_json = out_dir / "combined-matrix.json"
    combined_md = out_dir / "combined-matrix.md"
    combined_json.write_text(
        json.dumps({"reports": reports, "errors": errors}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    write_combined(reports, errors, combined_md)
    print(f"[online-intake] wrote {combined_md}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
