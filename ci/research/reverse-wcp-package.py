#!/usr/bin/env python3
"""Reverse-inspect a WCP package (archive or directory) and compare contracts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path
from typing import Any


KEY_EXPORT_SYMBOLS = [
    "RtlWow64SuspendThread",
    "Wow64SuspendLocalThread",
    "NtCreateUserProcess",
    "RtlCreateUserThread",
    "RtlWow64GetThreadContext",
    "RtlWow64SetThreadContext",
    "NtUserSendInput",
    "NtUserGetRawInputData",
]

KEY_EXPORT_DLLS = [
    "lib/wine/aarch64-windows/ntdll.dll",
    "lib/wine/aarch64-windows/wow64.dll",
    "lib/wine/aarch64-windows/wow64win.dll",
    "lib/wine/aarch64-windows/win32u.dll",
    "lib/wine/aarch64-windows/kernel32.dll",
    "lib/wine/aarch64-windows/kernelbase.dll",
    "lib/wine/aarch64-windows/user32.dll",
]

INTERESTING_REL_PATHS = [
    "bin/wine",
    "bin/wineserver",
    "lib/wine/aarch64-unix/ntdll.so",
    "lib/wine/aarch64-unix/win32u.so",
    "lib/wine/aarch64-unix/winevulkan.so",
    "lib/wine/aarch64-unix/winex11.so",
    "lib/wine/aarch64-unix/winebus.so",
    "lib/wine/aarch64-unix/winepulse.so",
    "lib/wine/aarch64-windows/ntdll.dll",
    "lib/wine/aarch64-windows/wow64.dll",
    "lib/wine/aarch64-windows/wow64win.dll",
    "lib/wine/aarch64-windows/win32u.dll",
    "lib/wine/aarch64-windows/kernel32.dll",
    "lib/wine/aarch64-windows/kernelbase.dll",
    "lib/wine/aarch64-windows/user32.dll",
]

MARKER_PATTERNS = {
    "fex": re.compile(r"(fex|arm64ecfex|wow64fex)", re.IGNORECASE),
    "glibc": re.compile(r"(glibc|ld-linux|libc\.so\.6)", re.IGNORECASE),
    "wow64": re.compile(r"wow64", re.IGNORECASE),
    "box64": re.compile(r"box64", re.IGNORECASE),
    "hangover": re.compile(r"hangover", re.IGNORECASE),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="Path to .wcp/.wcp.xz/.wcp.zst archive or extracted package dir")
    parser.add_argument(
        "--compare",
        default="",
        help="Optional path to second archive or extracted dir for contract diff",
    )
    parser.add_argument(
        "--output-json",
        default="docs/WCP_REVERSE_ANALYSIS.json",
        help="Output JSON path",
    )
    parser.add_argument(
        "--output-md",
        default="docs/WCP_REVERSE_ANALYSIS.md",
        help="Output markdown path",
    )
    parser.add_argument(
        "--full-inventory",
        action="store_true",
        help="Include full per-file inventory (sha256, size, kind, and ELF metadata)",
    )
    parser.add_argument(
        "--inventory-prefix",
        action="append",
        default=[],
        help="Optional relative path prefix filter for --full-inventory (can be passed multiple times)",
    )
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while True:
            chunk = stream.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def run_capture(cmd: list[str]) -> str:
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return proc.stdout if proc.returncode == 0 else ""


def extract_archive(src: Path, dst: Path) -> None:
    try:
        with tarfile.open(src, "r:*") as tar:
            tar.extractall(dst)
            return
    except Exception:
        pass
    proc = subprocess.run(["tar", "-xf", str(src), "-C", str(dst)], capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"cannot extract {src}: {proc.stderr.strip()}")


def load_package_root(input_path: Path, temp_root: Path) -> Path:
    if input_path.is_dir():
        return input_path
    out = temp_root / "extract"
    out.mkdir(parents=True, exist_ok=True)
    extract_archive(input_path, out)
    return out


def read_text_safe(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""


def read_profile(root: Path) -> dict[str, Any]:
    profile = root / "profile.json"
    if not profile.is_file():
        return {}
    try:
        return json.loads(profile.read_text(encoding="utf-8"))
    except Exception:
        return {}


def detect_elf(path: Path) -> bool:
    try:
        with path.open("rb") as stream:
            return stream.read(4) == b"\x7fELF"
    except Exception:
        return False


def detect_pe(path: Path) -> bool:
    try:
        with path.open("rb") as stream:
            return stream.read(2) == b"MZ"
    except Exception:
        return False


def analyze_elf(path: Path, root: Path) -> dict[str, Any]:
    rel = str(path.relative_to(root))
    h = run_capture(["readelf", "-h", str(path)])
    l = run_capture(["readelf", "-l", str(path)])
    d = run_capture(["readelf", "-d", str(path)])

    machine = ""
    m = re.search(r"Machine:\s+(.+)", h)
    if m:
        machine = m.group(1).strip()
    interpreter = ""
    m = re.search(r"Requesting program interpreter:\s*(.+?)\]", l)
    if m:
        interpreter = m.group(1).strip()
    runpath = ""
    m = re.search(r"RUNPATH\)\s+Library runpath: \[(.+?)\]", d)
    if m:
        runpath = m.group(1).strip()
    rpath = ""
    m = re.search(r"RPATH\)\s+Library rpath: \[(.+?)\]", d)
    if m:
        rpath = m.group(1).strip()
    needed = re.findall(r"Shared library: \[(.+?)\]", d)
    return {
        "path": rel,
        "machine": machine,
        "interpreter": interpreter,
        "runpath": runpath,
        "rpath": rpath,
        "needed": needed,
    }


def analyze_exports(dll_path: Path) -> dict[str, Any]:
    out = run_capture(["llvm-readobj", "--coff-exports", str(dll_path)])
    names = re.findall(r"Name: (.+)", out)
    present = {name: (name in names) for name in KEY_EXPORT_SYMBOLS}
    return {
        "count": len(names),
        "keySymbolPresent": present,
        "allNames": names,
    }


def analyze_launchers(root: Path, elf_map: dict[str, dict[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for name in ("wine", "wineserver"):
        path = root / "bin" / name
        entry: dict[str, Any] = {"exists": path.is_file(), "path": f"bin/{name}"}
        if not path.is_file():
            result[name] = entry
            continue
        if detect_elf(path):
            entry["kind"] = "elf"
            rel = f"bin/{name}"
            elf = elf_map.get(rel, {})
            entry["interpreter"] = elf.get("interpreter", "")
            entry["runpath"] = elf.get("runpath", "")
            entry["needed"] = elf.get("needed", [])
        else:
            txt = read_text_safe(path)
            entry["kind"] = "script"
            entry["shebang"] = txt.splitlines()[0] if txt.startswith("#!") else ""
            entry["glibcHint"] = bool(re.search(r"(glibc|ld-linux|wine\.glibc-real)", txt, re.IGNORECASE))
        result[name] = entry
    return result


def classify_runtime(launchers: dict[str, Any], elf_rows: list[dict[str, Any]]) -> tuple[str, bool]:
    launcher_kinds = {launchers.get("wine", {}).get("kind"), launchers.get("wineserver", {}).get("kind")}
    if launcher_kinds == {"script"}:
        glibc_hint = launchers.get("wine", {}).get("glibcHint") or launchers.get("wineserver", {}).get("glibcHint")
        if glibc_hint:
            return ("glibc-wrapped", True)
    if launcher_kinds == {"elf"}:
        interpreters = {
            launchers.get("wine", {}).get("interpreter", ""),
            launchers.get("wineserver", {}).get("interpreter", ""),
        }
        glibc_ref = False
        for row in elf_rows:
            hay = " ".join([row.get("interpreter", ""), row.get("runpath", ""), row.get("rpath", ""), " ".join(row.get("needed", []))])
            if "ld-linux" in hay or "libc.so.6" in hay:
                glibc_ref = True
                break
        if interpreters == {"/system/bin/linker64"}:
            return ("bionic-native", glibc_ref)
    return ("mixed-or-unknown", False)


def list_markers(root: Path) -> dict[str, list[str]]:
    markers: dict[str, list[str]] = {k: [] for k in MARKER_PATTERNS}
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        rel = str(path.relative_to(root))
        for key, pattern in MARKER_PATTERNS.items():
            if pattern.search(rel):
                markers[key].append(rel)
    return markers


def path_in_prefixes(rel: str, prefixes: list[str]) -> bool:
    if not prefixes:
        return True
    clean = rel.strip("/")
    for pref in prefixes:
        p = pref.strip().strip("/")
        if not p:
            continue
        if clean == p or clean.startswith(p + "/"):
            return True
    return False


def build_full_inventory(root: Path, files: list[Path], elf_map: dict[str, dict[str, Any]], prefixes: list[str]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in sorted(files):
        rel = str(path.relative_to(root))
        if not path_in_prefixes(rel, prefixes):
            continue
        row: dict[str, Any] = {
            "path": rel,
            "size": path.stat().st_size,
            "sha256": sha256_file(path),
        }
        if detect_elf(path):
            row["kind"] = "elf"
            elf = elf_map.get(rel, {})
            row["machine"] = elf.get("machine", "")
            row["interpreter"] = elf.get("interpreter", "")
            row["runpath"] = elf.get("runpath", "")
            row["rpath"] = elf.get("rpath", "")
            row["needed"] = elf.get("needed", [])
        elif detect_pe(path):
            row["kind"] = "pe"
        else:
            row["kind"] = "other"
        rows.append(row)
    return rows


def compare_inventory(base_rows: list[dict[str, Any]], other_rows: list[dict[str, Any]]) -> dict[str, Any]:
    base_map = {str(row.get("path", "")): row for row in base_rows if row.get("path")}
    other_map = {str(row.get("path", "")): row for row in other_rows if row.get("path")}
    base_paths = set(base_map)
    other_paths = set(other_map)
    both = sorted(base_paths & other_paths)
    changed = [p for p in both if base_map[p].get("sha256", "") != other_map[p].get("sha256", "")]
    only_base = sorted(base_paths - other_paths)
    only_other = sorted(other_paths - base_paths)
    return {
        "baseCount": len(base_paths),
        "otherCount": len(other_paths),
        "commonCount": len(both),
        "changedShaCount": len(changed),
        "baseOnlyCount": len(only_base),
        "otherOnlyCount": len(only_other),
        "changedShaSample": changed[:120],
        "baseOnlySample": only_base[:120],
        "otherOnlySample": only_other[:120],
    }


def top_level_members(root: Path) -> list[str]:
    names = []
    for path in root.iterdir():
        names.append(path.name + ("/" if path.is_dir() else ""))
    return sorted(names)


def inspect_package(input_path: Path, *, full_inventory: bool = False, inventory_prefixes: list[str] | None = None) -> dict[str, Any]:
    temp_root = Path(tempfile.mkdtemp(prefix="wcp_reverse_"))
    try:
        root = load_package_root(input_path, temp_root)
        prefixes = inventory_prefixes or []
        files = [p for p in root.rglob("*") if p.is_file()]
        elf_files = [p for p in files if detect_elf(p)]
        pe_like = [
            p
            for p in files
            if p.suffix.lower() in {".dll", ".exe", ".sys", ".drv", ".ocx", ".cpl", ".ax", ".acm"}
        ]
        elf_rows = [analyze_elf(p, root) for p in sorted(elf_files)]
        elf_map = {row["path"]: row for row in elf_rows}
        launchers = analyze_launchers(root, elf_map)
        runtime_class, has_glibc_elf_refs = classify_runtime(launchers, elf_rows)

        export_rows: dict[str, Any] = {}
        for rel in KEY_EXPORT_DLLS:
            path = root / rel
            if path.is_file():
                export_rows[rel] = analyze_exports(path)

        interesting: dict[str, Any] = {}
        for rel in INTERESTING_REL_PATHS:
            path = root / rel
            row: dict[str, Any] = {"exists": path.is_file(), "path": rel}
            if path.is_file():
                row["size"] = path.stat().st_size
                row["sha256"] = sha256_file(path)
                if detect_elf(path):
                    row["kind"] = "elf"
                    elf = elf_map.get(rel, {})
                    row["interpreter"] = elf.get("interpreter", "")
                    row["runpath"] = elf.get("runpath", "")
                    row["needed"] = elf.get("needed", [])
                elif rel.endswith(".dll") or rel.endswith(".exe"):
                    row["kind"] = "pe"
                    if rel in export_rows:
                        row["exportCount"] = export_rows[rel].get("count", 0)
                        row["keySymbolPresent"] = export_rows[rel].get("keySymbolPresent", {})
                else:
                    row["kind"] = "other"
            interesting[rel] = row

        pkg: dict[str, Any] = {
            "inputPath": str(input_path),
            "inputSha256": sha256_file(input_path) if input_path.is_file() else "",
            "topLevel": top_level_members(root),
            "profile": read_profile(root),
            "stats": {
                "fileCount": len(files),
                "elfCount": len(elf_files),
                "peLikeCount": len(pe_like),
            },
            "markers": list_markers(root),
            "launchers": launchers,
            "runtimeClass": runtime_class,
            "hasGlibcElfRefs": has_glibc_elf_refs,
            "elf": elf_rows,
            "exports": export_rows,
            "interesting": interesting,
        }
        if full_inventory:
            inventory_rows = build_full_inventory(root, files, elf_map, prefixes)
            pkg["inventory"] = {
                "prefixes": prefixes,
                "rows": inventory_rows,
                "count": len(inventory_rows),
            }
        return pkg
    finally:
        shutil.rmtree(temp_root, ignore_errors=True)


def compare_reports(base: dict[str, Any], other: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {
        "runtimeClass": {"base": base.get("runtimeClass", ""), "other": other.get("runtimeClass", "")},
        "launcherRunpath": {},
        "markerCounts": {},
    }
    for name in ("wine", "wineserver"):
        out["launcherRunpath"][name] = {
            "base": base.get("launchers", {}).get(name, {}).get("runpath", ""),
            "other": other.get("launchers", {}).get(name, {}).get("runpath", ""),
        }
    for key in MARKER_PATTERNS:
        out["markerCounts"][key] = {
            "base": len(base.get("markers", {}).get(key, [])),
            "other": len(other.get("markers", {}).get(key, [])),
        }

    base_nt = set(base.get("exports", {}).get("lib/wine/aarch64-windows/ntdll.dll", {}).get("allNames", []))
    other_nt = set(other.get("exports", {}).get("lib/wine/aarch64-windows/ntdll.dll", {}).get("allNames", []))
    out["ntdllExportDiff"] = {
        "baseOnlyCount": len(base_nt - other_nt),
        "otherOnlyCount": len(other_nt - base_nt),
        "baseOnlySample": sorted(base_nt - other_nt)[:40],
        "otherOnlySample": sorted(other_nt - base_nt)[:40],
    }

    interesting_diff: dict[str, Any] = {}
    base_i = base.get("interesting", {})
    other_i = other.get("interesting", {})
    for rel in INTERESTING_REL_PATHS:
        b = base_i.get(rel, {})
        o = other_i.get(rel, {})
        diff_row = {
            "baseExists": bool(b.get("exists")),
            "otherExists": bool(o.get("exists")),
            "baseSha256": b.get("sha256", ""),
            "otherSha256": o.get("sha256", ""),
            "shaEqual": b.get("sha256", "") == o.get("sha256", "") and bool(b.get("sha256", "")),
            "baseSize": b.get("size", 0),
            "otherSize": o.get("size", 0),
            "kind": b.get("kind", "") or o.get("kind", ""),
        }
        if diff_row["kind"] == "elf":
            diff_row["runpathBase"] = b.get("runpath", "")
            diff_row["runpathOther"] = o.get("runpath", "")
        if diff_row["kind"] == "pe":
            diff_row["exportCountBase"] = b.get("exportCount", 0)
            diff_row["exportCountOther"] = o.get("exportCount", 0)
            bkey = b.get("keySymbolPresent", {}) if isinstance(b.get("keySymbolPresent"), dict) else {}
            okey = o.get("keySymbolPresent", {}) if isinstance(o.get("keySymbolPresent"), dict) else {}
            diff_row["keySymbolsDifferent"] = sorted(
                [k for k in KEY_EXPORT_SYMBOLS if bool(bkey.get(k)) != bool(okey.get(k))]
            )
        interesting_diff[rel] = diff_row
    out["interestingDiff"] = interesting_diff
    base_inv = (base.get("inventory") or {}).get("rows", [])
    other_inv = (other.get("inventory") or {}).get("rows", [])
    if isinstance(base_inv, list) and isinstance(other_inv, list) and (base_inv or other_inv):
        out["inventoryDiff"] = compare_inventory(base_inv, other_inv)
    return out


def strip_export_name_lists(report: dict[str, Any]) -> None:
    for key in ("base", "compareTarget"):
        block = report.get(key)
        if not isinstance(block, dict):
            continue
        exports = block.get("exports")
        if not isinstance(exports, dict):
            continue
        for data in exports.values():
            if isinstance(data, dict):
                data.pop("allNames", None)


def write_markdown(path: Path, base: dict[str, Any], cmp: dict[str, Any] | None) -> None:
    lines: list[str] = []
    lines.append("# WCP Reverse Analysis")
    lines.append("")
    lines.append(f"- Input: `{base.get('inputPath','')}`")
    if base.get("inputSha256"):
        lines.append(f"- Input SHA256: `{base['inputSha256']}`")
    lines.append(f"- Runtime class: `{base.get('runtimeClass','')}`")
    lines.append(f"- ELF glibc refs present: `{base.get('hasGlibcElfRefs', False)}`")
    lines.append(f"- Top-level: `{', '.join(base.get('topLevel', []))}`")
    lines.append(
        f"- Stats: files `{base.get('stats',{}).get('fileCount',0)}`, ELF `{base.get('stats',{}).get('elfCount',0)}`, PE-like `{base.get('stats',{}).get('peLikeCount',0)}`"
    )
    lines.append("")
    lines.append("## Launchers")
    lines.append("")
    for name in ("wine", "wineserver"):
        row = base.get("launchers", {}).get(name, {})
        lines.append(
            f"- `{name}`: kind `{row.get('kind','missing')}`, interpreter `{row.get('interpreter','')}`, runpath `{row.get('runpath','')}`"
        )
    lines.append("")
    lines.append("## Marker Counts")
    lines.append("")
    for key in MARKER_PATTERNS:
        lines.append(f"- `{key}`: {len(base.get('markers', {}).get(key, []))}")
    lines.append("")
    lines.append("## Key Export Presence")
    lines.append("")
    for dll, data in sorted(base.get("exports", {}).items()):
        flags = data.get("keySymbolPresent", {})
        present = [sym for sym, ok in flags.items() if ok]
        lines.append(f"- `{dll}`: exports `{data.get('count',0)}`, key present `{', '.join(present) if present else 'none'}`")
    inventory = base.get("inventory", {})
    rows = inventory.get("rows", []) if isinstance(inventory, dict) else []
    if rows:
        lines.append("")
        lines.append("## Full Inventory")
        lines.append("")
        lines.append(f"- Rows: `{inventory.get('count', len(rows))}`")
        lines.append(f"- Prefixes: `{', '.join(inventory.get('prefixes', [])) or '(all files)'}`")
        kind_counts: dict[str, int] = {}
        for row in rows:
            kind = str(row.get("kind", "other"))
            kind_counts[kind] = kind_counts.get(kind, 0) + 1
        for kind in sorted(kind_counts):
            lines.append(f"- `{kind}`: {kind_counts[kind]}")
    if cmp is not None:
        lines.append("")
        lines.append("## Compare")
        lines.append("")
        lines.append(
            f"- Runtime class: base `{cmp['runtimeClass']['base']}` vs other `{cmp['runtimeClass']['other']}`"
        )
        lines.append(
            f"- NTDLL export diff: base-only `{cmp['ntdllExportDiff']['baseOnlyCount']}`, other-only `{cmp['ntdllExportDiff']['otherOnlyCount']}`"
        )
        for name in ("wine", "wineserver"):
            row = cmp["launcherRunpath"][name]
            lines.append(f"- `{name}` runpath: base `{row['base']}` vs other `{row['other']}`")
        inv = cmp.get("inventoryDiff", {})
        if inv:
            lines.append(
                f"- Inventory diff: common `{inv.get('commonCount',0)}`, changed sha `{inv.get('changedShaCount',0)}`, base-only `{inv.get('baseOnlyCount',0)}`, other-only `{inv.get('otherOnlyCount',0)}`"
            )
        lines.append("")
        lines.append("## Interesting Library Delta")
        lines.append("")
        lines.append("| Path | Kind | SHA equal | Base size | Other size | Extra |")
        lines.append("| --- | --- | --- | ---: | ---: | --- |")
        for rel in INTERESTING_REL_PATHS:
            row = cmp.get("interestingDiff", {}).get(rel, {})
            if not row:
                continue
            extra = ""
            if row.get("kind") == "elf":
                extra = f"runpath `{row.get('runpathBase','')}` -> `{row.get('runpathOther','')}`"
            elif row.get("kind") == "pe":
                extra = f"exports {row.get('exportCountBase',0)} -> {row.get('exportCountOther',0)}; keydiff {','.join(row.get('keySymbolsDifferent', [])) or '-'}"
            lines.append(
                f"| `{rel}` | `{row.get('kind','')}` | `{row.get('shaEqual', False)}` | `{row.get('baseSize', 0)}` | `{row.get('otherSize', 0)}` | {extra} |"
            )
        inv = cmp.get("inventoryDiff", {})
        if inv:
            lines.append("")
            lines.append("## Full Inventory Delta (samples)")
            lines.append("")
            lines.append(f"- Changed SHA sample: `{', '.join(inv.get('changedShaSample', [])[:25])}`")
            lines.append(f"- Base-only sample: `{', '.join(inv.get('baseOnlySample', [])[:25])}`")
            lines.append(f"- Other-only sample: `{', '.join(inv.get('otherOnlySample', [])[:25])}`")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    input_path = Path(args.input).expanduser().resolve()
    if not input_path.exists():
        raise FileNotFoundError(input_path)

    base = inspect_package(
        input_path,
        full_inventory=bool(args.full_inventory),
        inventory_prefixes=list(args.inventory_prefix or []),
    )
    report: dict[str, Any] = {"base": base}

    compare_report: dict[str, Any] | None = None
    if args.compare:
        compare_path = Path(args.compare).expanduser().resolve()
        if not compare_path.exists():
            raise FileNotFoundError(compare_path)
        other = inspect_package(
            compare_path,
            full_inventory=bool(args.full_inventory),
            inventory_prefixes=list(args.inventory_prefix or []),
        )
        report["compareTarget"] = other
        compare_report = compare_reports(base, other)
        report["compare"] = compare_report

    strip_export_name_lists(report)

    json_path = Path(args.output_json)
    md_path = Path(args.output_md)
    json_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(report, indent=2, ensure_ascii=True), encoding="utf-8")
    write_markdown(md_path, base, compare_report)
    print(f"[reverse-wcp] wrote {json_path}")
    print(f"[reverse-wcp] wrote {md_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
