#!/usr/bin/env python3
import argparse
import json
import subprocess
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, List, Tuple


MARKER_RULES: Dict[str, Dict[str, str]] = {
    "NtUserSendHardwareInput": {
        "priority": "high",
        "target": "ci/gamenative/patchsets/28c3a06/android/patches/dlls_winex11_drv_mouse_c_wm_input_fix.patch",
        "action": "Verify WM_INPUT path keeps raw-input policy compatible with no-XInput2 builds.",
    },
    "SEND_HWMSG_NO_RAW": {
        "priority": "high",
        "target": "ci/validation/check-gamenative-patch-contract.sh",
        "action": "Reject hardcoded NO_RAW dispatch unless helper or zero-flag fallback is present.",
    },
    "get_send_mouse_flags": {
        "priority": "high",
        "target": "ci/gamenative/apply-android-patchset.sh",
        "action": "Preserve helper-based mouse send flags during patch drift normalization.",
    },
    "x11drv_xinput2_enable": {
        "priority": "high",
        "target": "ci/gamenative/patchsets/28c3a06/manifest.tsv",
        "action": "Keep no-XInput2 safeguards for X11 mouse/controller path.",
    },
    "xinput2_available": {
        "priority": "high",
        "target": "ci/validation/check-gamenative-patch-contract.sh",
        "action": "Enforce helper-gated NO_RAW behavior on xinput2_available builds.",
    },
    "WRAPPER_VK_VERSION": {
        "priority": "high",
        "target": "ci/winlator/patches/0001-mainline-full-stack-consolidated.patch",
        "action": "Track requested/detected/effective Vulkan negotiation markers and runtime env export.",
    },
    "VK_API_VERSION": {
        "priority": "high",
        "target": "ci/winlator/patches/0001-mainline-full-stack-consolidated.patch",
        "action": "Confirm Vulkan API upgrades never bypass wrapper capability ceiling checks.",
    },
    "REMOTE_PROFILES": {
        "priority": "medium",
        "target": "ci/winlator/patches/0001-mainline-full-stack-consolidated.patch",
        "action": "Harden profile source fallback chain for VPN/DNS transient failures.",
    },
    "ContentProfile": {
        "priority": "medium",
        "target": "docs/CONTENT_PACKAGES_ARCHITECTURE.md",
        "action": "Keep internal type canonicalization aligned with Wine-family aliases.",
    },
    "libarm64ecfex.dll": {
        "priority": "medium",
        "target": "ci/validation/check-gamenative-patch-contract.sh",
        "action": "Keep loader contract checks for external FEX dll naming and placement.",
    },
    "Wow64SuspendLocalThread": {
        "priority": "medium",
        "target": "ci/validation/inspect-wcp-runtime-contract.sh",
        "action": "Preserve wow64 export checks in strict runtime contract mode.",
    },
    "RtlWow64SuspendThread": {
        "priority": "medium",
        "target": "ci/validation/inspect-wcp-runtime-contract.sh",
        "action": "Validate wow64 suspend-path exports against GameNative baseline.",
    },
    "BOX64_DYNAREC": {
        "priority": "low",
        "target": "ci/winlator/patches/0001-mainline-full-stack-consolidated.patch",
        "action": "Track Box64 dynarec knobs against unified runtime profile defaults.",
    },
    "BOX64_LOG": {
        "priority": "low",
        "target": "ci/winlator/patches/0001-mainline-full-stack-consolidated.patch",
        "action": "Retain deterministic Box64 log controls for forensics capture presets.",
    },
    "BOX64_DYNAREC_STRONGMEM": {
        "priority": "low",
        "target": "ci/winlator/patches/0001-mainline-full-stack-consolidated.patch",
        "action": "Review strongmem toggles for device-tier overlays before promotion.",
    },
    "BOX64_NOBANNER": {
        "priority": "low",
        "target": "ci/winlator/patches/0001-mainline-full-stack-consolidated.patch",
        "action": "Keep startup-noise controls deterministic across profile presets.",
    },
    "FEXCore": {
        "priority": "low",
        "target": "ci/winlator/patches/0001-mainline-full-stack-consolidated.patch",
        "action": "Cross-check FEX profile surface against external-only runtime contract.",
    },
    "FEXBash": {
        "priority": "low",
        "target": "ci/winlator/patches/0001-mainline-full-stack-consolidated.patch",
        "action": "Mirror launch-shell assumptions from external FEX lanes without embedding payloads.",
    },
    "WINEDEBUG": {
        "priority": "low",
        "target": "docs/UNIFIED_RUNTIME_CONTRACT.md",
        "action": "Preserve canonical WINEDEBUG injection path and diagnostics envelope export.",
    },
    "WINE_OPEN_WITH_ANDROID_BROWSER": {
        "priority": "low",
        "target": "ci/validation/check-gamenative-patch-contract.sh",
        "action": "Keep android-browser env key canonicalized in winebrowser normalization path.",
    },
    "MESA_VK_WSI_PRESENT_MODE": {
        "priority": "low",
        "target": "docs/UNIFIED_RUNTIME_CONTRACT.md",
        "action": "Keep present-mode negotiation deterministic for wrapper/upscaler integration.",
    },
    "TU_DEBUG": {
        "priority": "low",
        "target": "docs/UNIFIED_RUNTIME_CONTRACT.md",
        "action": "Preserve TU_DEBUG routing for adreno device-tier diagnostics presets.",
    },
    "cnc-ddraw": {
        "priority": "low",
        "target": "ci/winlator/patches/0001-mainline-full-stack-consolidated.patch",
        "action": "Keep DX8 cnc-ddraw wrapper branch wired in runtime env assembly.",
    },
    "PROOT_TMP_DIR": {
        "priority": "low",
        "target": "docs/EXTERNAL_SIGNAL_CONTRACT.md",
        "action": "Capture proot/temp path assumptions as external signal inputs.",
    },
    "XDG_RUNTIME_DIR": {
        "priority": "low",
        "target": "docs/X11_TERMUX_COMPAT_CONTRACT.md",
        "action": "Track runtime-dir expectations for termux-x11 compatibility.",
    },
    "DXVK": {
        "priority": "low",
        "target": "docs/CONTENT_PACKAGES_ARCHITECTURE.md",
        "action": "Keep DXVK path references consistent with external content packaging.",
    },
    "VKD3D": {
        "priority": "low",
        "target": "docs/CONTENT_PACKAGES_ARCHITECTURE.md",
        "action": "Keep VKD3D path references consistent with external content packaging.",
    },
    "D8VK": {
        "priority": "low",
        "target": "docs/CONTENT_PACKAGES_ARCHITECTURE.md",
        "action": "Track DX8 wrapper-lane hints for later patch-base reconciliation.",
    },
    "DXVK_NVAPI": {
        "priority": "low",
        "target": "docs/UNIFIED_RUNTIME_CONTRACT.md",
        "action": "Track NVAPI-side DXVK toggles for compatibility/perf regressions across forks.",
    },
    "WINE_FULLSCREEN_FSR": {
        "priority": "low",
        "target": "docs/UNIFIED_RUNTIME_CONTRACT.md",
        "action": "Preserve Proton/Wine fullscreen FSR hack contract for X11 launch path.",
    },
    "WINE_FULLSCREEN_FSR_STRENGTH": {
        "priority": "low",
        "target": "docs/UNIFIED_RUNTIME_CONTRACT.md",
        "action": "Keep FSR strength policy deterministic across container and shortcut overlays.",
    },
    "WINE_FULLSCREEN_FSR_MODE": {
        "priority": "low",
        "target": "docs/UNIFIED_RUNTIME_CONTRACT.md",
        "action": "Track explicit FSR mode export to avoid silent mode drift.",
    },
    "VKBASALT_CONFIG": {
        "priority": "low",
        "target": "docs/UNIFIED_RUNTIME_CONTRACT.md",
        "action": "Ensure vkBasalt pipeline config remains explicit in runtime env assembly.",
    },
}


def load_combined(path: Path) -> Dict:
    return json.loads(path.read_text(encoding="utf-8"))


def collect_markers(reports: Dict[str, Dict]) -> Tuple[Counter, Dict[str, List[str]]]:
    marker_hits: Counter = Counter()
    marker_repos: Dict[str, List[str]] = defaultdict(list)
    for alias, report in reports.items():
        seen = set()
        for row in report.get("focus_files", []):
            for marker in row.get("markers") or []:
                marker_hits[marker] += 1
                seen.add(marker)
        for marker in sorted(seen):
            marker_repos[marker].append(alias)
    return marker_hits, marker_repos


def collect_markers_from_commit_scan(payload: Dict) -> Tuple[Counter, Dict[str, List[str]], Dict[str, List[Dict[str, str]]], int]:
    marker_hits: Counter = Counter()
    marker_repos: Dict[str, List[str]] = defaultdict(list)
    marker_evidence: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    errors = payload.get("errors") or {}
    reports = payload.get("reports") or {}
    if not isinstance(reports, dict):
        return marker_hits, marker_repos, marker_evidence, len(errors)

    seen_evidence = set()
    for alias, report in reports.items():
        if not isinstance(report, dict):
            continue
        marker_totals = report.get("marker_totals") or {}
        seen_markers = set()
        for marker, count in marker_totals.items():
            marker = str(marker).strip()
            if not marker:
                continue
            try:
                value = int(count)
            except Exception:
                value = 1
            if value < 1:
                continue
            marker_hits[marker] += value
            seen_markers.add(marker)

        commits = report.get("commits") or []
        for commit in commits:
            if not isinstance(commit, dict):
                continue
            sha = str(commit.get("sha", "")).strip()
            message = str(commit.get("message", "")).strip()
            for marker in commit.get("markers") or []:
                marker = str(marker).strip()
                if not marker:
                    continue
                if marker not in marker_totals:
                    marker_hits[marker] += 1
                seen_markers.add(marker)
                evidence_key = (marker, alias, sha, message)
                if evidence_key in seen_evidence:
                    continue
                seen_evidence.add(evidence_key)
                marker_evidence[marker].append(
                    {
                        "repo_alias": str(alias),
                        "path": f"commit:{sha}" if sha else "commit",
                        "line": "",
                        "code": message,
                        "source": "commit_scan",
                    }
                )

        for marker in sorted(seen_markers):
            marker_repos[marker].append(str(alias))

    return marker_hits, marker_repos, marker_evidence, len(errors)


def collect_marker_evidence(reports: Dict[str, Dict]) -> Dict[str, List[Dict[str, str]]]:
    evidence: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    seen = set()
    for alias, report in reports.items():
        for row in report.get("focus_files", []):
            path = str(row.get("path", "")).strip()
            snippet_rows = row.get("snippets") or []
            for snippet in snippet_rows:
                marker = str(snippet.get("marker", "")).strip()
                if not marker:
                    continue
                key = (
                    marker,
                    alias,
                    path,
                    str(snippet.get("line", "")),
                    str(snippet.get("code", "")).strip(),
                )
                if key in seen:
                    continue
                seen.add(key)
                evidence[marker].append(
                    {
                        "repo_alias": alias,
                        "path": path,
                        "line": str(snippet.get("line", "")),
                        "code": str(snippet.get("code", "")).strip(),
                        "source": "focus",
                    }
                )
            if snippet_rows:
                continue
            for marker in row.get("markers") or []:
                marker = str(marker).strip()
                if not marker:
                    continue
                key = (marker, alias, path, "", "")
                if key in seen:
                    continue
                seen.add(key)
                evidence[marker].append(
                    {
                        "repo_alias": alias,
                        "path": path,
                        "line": "",
                        "code": "",
                        "source": "focus",
                    }
                )
    return evidence


def merge_repo_maps(base: Dict[str, List[str]], extra: Dict[str, List[str]]) -> Dict[str, List[str]]:
    merged: Dict[str, set] = defaultdict(set)
    for marker, repos in base.items():
        merged[marker].update(str(repo) for repo in repos if str(repo).strip())
    for marker, repos in extra.items():
        merged[marker].update(str(repo) for repo in repos if str(repo).strip())
    return {marker: sorted(values) for marker, values in merged.items()}


def merge_marker_evidence(
    base: Dict[str, List[Dict[str, str]]],
    extra: Dict[str, List[Dict[str, str]]],
) -> Dict[str, List[Dict[str, str]]]:
    merged: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    seen = set()
    for source in (base, extra):
        for marker, rows in source.items():
            for row in rows:
                item = {
                    "repo_alias": str(row.get("repo_alias", "")).strip(),
                    "path": str(row.get("path", "")).strip(),
                    "line": str(row.get("line", "")).strip(),
                    "code": str(row.get("code", "")).strip(),
                    "source": str(row.get("source", "focus") or "focus").strip(),
                }
                key = (marker, item["repo_alias"], item["path"], item["line"], item["code"], item["source"])
                if key in seen:
                    continue
                seen.add(key)
                merged[marker].append(item)
    return merged


def collect_categories(reports: Dict[str, Dict]) -> Counter:
    category_hits: Counter = Counter()
    for report in reports.values():
        for name, count in report.get("tree_top_categories", []):
            try:
                category_hits[name] += int(count)
            except Exception:
                continue
    return category_hits


def build_backlog_rows(
    marker_hits: Counter,
    marker_repos: Dict[str, List[str]],
    marker_evidence: Dict[str, List[Dict[str, str]]],
    source_breakdown: Dict[str, Dict[str, int]],
) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for marker, hit_count in marker_hits.most_common():
        rule = MARKER_RULES.get(marker)
        if not rule:
            continue
        evidence_rows = marker_evidence.get(marker, [])
        first = evidence_rows[0] if evidence_rows else {}
        first_loc = ""
        if first:
            line = first.get("line", "")
            first_loc = f"{first.get('repo_alias', '')}:{first.get('path', '')}"
            if line:
                first_loc = f"{first_loc}:{line}"
        rows.append(
            {
                "marker": marker,
                "hits": str(hit_count),
                "repos": ", ".join(sorted(marker_repos.get(marker, []))),
                "priority": rule["priority"],
                "target": rule["target"],
                "action": rule["action"],
                "evidence": evidence_rows[:6],
                "first_evidence": first_loc,
                "focus_hits": str(int(source_breakdown.get(marker, {}).get("focus", 0))),
                "commit_hits": str(int(source_breakdown.get(marker, {}).get("commit_scan", 0))),
            }
        )
    return rows


def load_changed_paths(repo_root: Path) -> set:
    try:
        out = subprocess.check_output(
            ["git", "-C", str(repo_root), "status", "--porcelain"],
            text=True,
        )
    except Exception:
        return set()
    changed = set()
    for line in out.splitlines():
        if len(line) < 4:
            continue
        path = line[3:].strip()
        if " -> " in path:
            path = path.split(" -> ", 1)[1].strip()
        if path:
            changed.add(path)
    return changed


def attach_row_status(rows: List[Dict[str, str]], repo_root: Path) -> List[Dict[str, str]]:
    changed_paths = load_changed_paths(repo_root)

    def marker_is_validated(marker: str, target_path: Path) -> bool:
        try:
            text = target_path.read_text(encoding="utf-8")
        except Exception:
            return False
        if marker == "SEND_HWMSG_NO_RAW":
            return (
                "check_absent_regex" in text
                and "SEND_HWMSG_NO_RAW" in text
                and "winex11 mouse does not hardcode SEND_HWMSG_NO_RAW" in text
            )
        if marker == "NtUserSendHardwareInput":
            return "NtUserSendHardwareInput" in text
        if marker == "x11drv_xinput2_enable":
            return (
                "dlls_winex11_drv_mouse_c_wm_input_fix.patch" in text
                and "backport_winex11_mouse_wm_input" in text
            )
        if marker == "xinput2_available":
            return "xinput2_available" in text and "SEND_HWMSG_NO_RAW" in text
        if marker == "WRAPPER_VK_VERSION":
            return "WRAPPER_VK_VERSION" in text
        if marker == "VK_API_VERSION":
            return "VK_API_VERSION" in text and "WRAPPER_VK_VERSION" in text
        if marker == "get_send_mouse_flags":
            return "get_send_mouse_flags" in text and "NtUserSendHardwareInput" in text
        if marker == "Wow64SuspendLocalThread":
            return "Wow64SuspendLocalThread" in text
        if marker == "RtlWow64SuspendThread":
            return "RtlWow64SuspendThread" in text
        if marker == "libarm64ecfex.dll":
            return "libarm64ecfex.dll" in text
        if marker == "ContentProfile":
            return (
                "internalType" in text
                and "type=Wine" in text
                and "wine/protonge/protonwine" in text
            )
        if marker == "REMOTE_PROFILES":
            return (
                "REMOTE_PROFILES" in text
                and (
                    "sourceFallbackChain" in text
                    or "fallbackChain" in text
                    or "downloadable_contents_url" in text
                )
            )
        if marker in {
            "BOX64_DYNAREC",
            "BOX64_LOG",
            "BOX64_DYNAREC_STRONGMEM",
            "BOX64_NOBANNER",
            "FEXCore",
            "FEXBash",
            "PROOT_TMP_DIR",
            "XDG_RUNTIME_DIR",
            "WINEDEBUG",
            "MESA_VK_WSI_PRESENT_MODE",
            "TU_DEBUG",
        }:
            return marker in text
        if marker == "WINE_OPEN_WITH_ANDROID_BROWSER":
            return "WINE_OPEN_WITH_ANDROID_BROWSER" in text
        if marker == "DXVK":
            lower = text.lower()
            return "dxvk" in lower
        if marker == "VKD3D":
            lower = text.lower()
            return "vkd3d" in lower
        if marker == "D8VK":
            lower = text.lower()
            return "d8vk" in lower
        if marker == "DXVK_NVAPI":
            lower = text.lower()
            return "dxvk_nvapi" in lower or "nvapi" in lower
        if marker in {"WINE_FULLSCREEN_FSR", "WINE_FULLSCREEN_FSR_STRENGTH", "WINE_FULLSCREEN_FSR_MODE"}:
            return marker in text
        if marker == "VKBASALT_CONFIG":
            return "VKBASALT_CONFIG" in text
        if marker == "cnc-ddraw":
            lower = text.lower()
            return "cnc-ddraw" in lower or "ddrawrapper" in lower
        return False

    for row in rows:
        marker = row["marker"]
        target = row["target"]
        target_path = repo_root / target
        if not target_path.exists():
            row["status"] = "missing_target"
        else:
            validated = marker_is_validated(marker, target_path)
            if target in changed_paths:
                row["status"] = "ready_validated" if validated else "needs_review"
            else:
                row["status"] = "ready_validated" if validated else "ready"
    return rows


def write_markdown(
    out_file: Path,
    reports: Dict[str, Dict],
    errors: Dict[str, str],
    category_hits: Counter,
    rows: List[Dict[str, str]],
) -> None:
    lines: List[str] = []
    lines.append("# Online Intake Patch Backlog")
    lines.append("")
    lines.append("Generated from `docs/reverse/online-intake/combined-matrix.json`.")
    lines.append("")
    lines.append(f"- scanned repos: **{len(reports)}**")
    lines.append(f"- intake errors: **{len(errors)}**")
    lines.append("")

    lines.append("## Category pressure (tree-wide)")
    lines.append("")
    for name, count in category_hits.most_common(10):
        lines.append(f"- `{name}`: **{count}**")
    lines.append("")

    lines.append("## Marker-driven patch queue")
    lines.append("")
    if not rows:
        lines.append("- no mapped markers found in current intake window")
    else:
        lines.append("| Priority | Marker | Hits | Focus/Commits | Repos | Target | Status | Action |")
        lines.append("| --- | --- | ---: | --- | --- | --- | --- | --- |")
        for row in rows:
            lines.append(
                f"| `{row['priority']}` | `{row['marker']}` | {row['hits']} | {row.get('focus_hits','0')}/{row.get('commit_hits','0')} | {row['repos']} | `{row['target']}` | `{row['status']}` | {row['action']} |"
            )
            evidence = row.get("evidence") or []
            for item in evidence[:2]:
                location = f"{item.get('repo_alias', '')}:{item.get('path', '')}"
                if item.get("line"):
                    location = f"{location}:{item.get('line')}"
                code = (item.get("code") or "").strip()
                source = str(item.get("source", "focus") or "focus").strip()
                if code:
                    lines.append(f"  - evidence[{source}] `{location}` -> `{code}`")
                else:
                    lines.append(f"  - evidence[{source}] `{location}`")
    lines.append("")

    lines.append("## Execution rule")
    lines.append("")
    lines.append("- Apply `high` rows first, then rerun `ci/reverse/online-intake.sh` and regenerate this backlog.")
    lines.append("- Keep `medium` rows gated behind existing runtime contract and Runtime Contract checks.")
    lines.append("- Treat `low` rows as backlog candidates for patch-base expansion after `high/medium` are clean.")
    lines.append("")

    out_file.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_json(
    out_file: Path,
    reports: Dict[str, Dict],
    errors: Dict[str, str],
    rows: List[Dict[str, str]],
    commit_scan_used: bool,
    commit_scan_errors: int,
) -> None:
    payload = {
        "scanned_repos": len(reports),
        "intake_errors": len(errors),
        "commit_scan_used": bool(commit_scan_used),
        "commit_scan_errors": int(commit_scan_errors),
        "rows": rows,
    }
    out_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate patch backlog from online intake combined matrix")
    parser.add_argument("--combined-json", default="docs/reverse/online-intake/combined-matrix.json")
    parser.add_argument("--commit-scan-json", default="")
    parser.add_argument("--out-md", default="docs/reverse/online-intake/PATCH_TRANSFER_BACKLOG.md")
    parser.add_argument("--out-json", default="docs/reverse/online-intake/PATCH_TRANSFER_BACKLOG.json")
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    combined_path = Path(args.combined_json)
    out_path = Path(args.out_md)
    out_json_path = Path(args.out_json)
    repo_root = Path(args.repo_root).resolve()
    payload = load_combined(combined_path)
    reports = payload.get("reports") or {}
    errors = payload.get("errors") or {}

    marker_hits_focus, marker_repos_focus = collect_markers(reports)
    marker_evidence_focus = collect_marker_evidence(reports)
    marker_hits = Counter(marker_hits_focus)
    marker_repos = dict(marker_repos_focus)
    marker_evidence = dict(marker_evidence_focus)
    source_breakdown: Dict[str, Dict[str, int]] = defaultdict(lambda: {"focus": 0, "commit_scan": 0})
    for marker, value in marker_hits_focus.items():
        source_breakdown[marker]["focus"] += int(value)

    commit_scan_path = Path(args.commit_scan_json) if args.commit_scan_json else (combined_path.parent / "commit-scan.json")
    commit_scan_used = False
    commit_scan_errors = 0
    if commit_scan_path.exists():
        commit_scan_payload = json.loads(commit_scan_path.read_text(encoding="utf-8"))
        commit_hits, commit_repos, commit_evidence, commit_scan_errors = collect_markers_from_commit_scan(commit_scan_payload)
        marker_hits.update(commit_hits)
        marker_repos = merge_repo_maps(marker_repos, commit_repos)
        marker_evidence = merge_marker_evidence(marker_evidence, commit_evidence)
        for marker, value in commit_hits.items():
            source_breakdown[marker]["commit_scan"] += int(value)
        commit_scan_used = True

    category_hits = collect_categories(reports)
    rows = build_backlog_rows(marker_hits, marker_repos, marker_evidence, source_breakdown)
    rows = attach_row_status(rows, repo_root)
    write_markdown(out_path, reports, errors, category_hits, rows)
    write_json(out_json_path, reports, errors, rows, commit_scan_used, commit_scan_errors)
    print(f"[online-backlog] wrote {out_path}")
    print(f"[online-backlog] wrote {out_json_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
