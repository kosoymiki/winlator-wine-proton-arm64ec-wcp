#!/usr/bin/env python3
"""Extract method/class/call-edge runtime focus data from an Android APK.

The output layout intentionally mirrors existing reverse-analysis bundles used by
the Winlator CMOD research lane:

- methods_all.txt
- methods_unique.txt
- classes_unique.txt
- methods_by_package.tsv
- focus/methods_focus.txt
- focus/classes_focus.txt
- focus/call_edges_focus.tsv
- focus/call_edges_runtime_graphics.tsv
- focus/top_callers_focus.tsv
- focus/top_callees_focus.tsv
- focus/focus_summary.txt
"""

from __future__ import annotations

import argparse
import collections
import re
import subprocess
import zipfile
from datetime import datetime, timezone
from pathlib import Path


DEFAULT_DEXDUMP = "/home/mikhail/.local/android-sdk/build-tools/35.0.0/dexdump"
DEFAULT_FOCUS_PREFIXES = (
    # Legacy WinEmu package roots (GameHub-style bundles).
    "Lcom/winemu/",
    "Lcom/xj/winemu/",
    # Current GameNative/Winlator package roots.
    "Lcom/winlator/",
    "Lapp/gamenative/",
)
DEFAULT_RUNTIME_KEYWORDS = (
    "trans_layer",
    "box64",
    "fex",
    "wowbox64",
    "winuibridge",
    "winuemservice",
    "programcontroller",
    "environmentcontroller",
    "containercontroller",
    "registry",
    "dependencymanager",
    "vulkan",
    "gpu",
    "directrendering",
    "driver",
    "adrenotools",
    "manifest",
    "envlayer",
    "componentsinstall",
    "gameconfigdownload",
    "launcher",
    "openxr",
    "upscale",
    "scaleforce",
    "swfg",
)

CLASS_RE = re.compile(r"Class descriptor\s+:\s+'([^']+)'")
SECTION_RE = re.compile(r"^\s*(Direct methods|Virtual methods|Static fields|Instance fields)\s*-")
ENTRY_RE = re.compile(r"^\s*#\d+\s+:\s+\(in ")
NAME_RE = re.compile(r"^\s*name\s+:\s+'([^']+)'")
TYPE_RE = re.compile(r"^\s*type\s+:\s+'([^']+)'")
CODE_HDR_RE = re.compile(r"\|\[[0-9a-fA-F]+\]\s+(.+)$")
INVOKE_RE = re.compile(r"invoke-[^\s]+\s+\{[^}]*\},\s+([^\s]+)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", required=True, help="Path to APK file")
    parser.add_argument(
        "--out-dir",
        default="",
        help="Output directory (default: /home/mikhail/<apk-stem>_reverse_<timestamp>)",
    )
    parser.add_argument("--dexdump", default=DEFAULT_DEXDUMP, help="Path to dexdump executable")
    parser.add_argument(
        "--focus-prefix",
        action="append",
        default=list(DEFAULT_FOCUS_PREFIXES),
        help="Method/class descriptor prefix included in focus (repeatable)",
    )
    parser.add_argument(
        "--runtime-keyword",
        action="append",
        default=list(DEFAULT_RUNTIME_KEYWORDS),
        help="Keyword used for runtime-graphics edge filtering (repeatable)",
    )
    return parser.parse_args()


def normalize_header_method(raw: str) -> str | None:
    # Example:
    # "androidx.core.app.RemoteActionCompatParcelizer.read:(...)"
    marker = ":("
    idx = raw.find(marker)
    if idx < 0:
        return None
    left = raw[:idx]
    method_type = raw[idx + 1 :]
    if "." not in left:
        return None
    class_dot, method_name = left.rsplit(".", 1)
    class_desc = f"L{class_dot.replace('.', '/')};"
    return f"{class_desc}->{method_name}{method_type}"


def normalize_invoke_target(raw: str) -> str | None:
    # Example: Ljava/lang/Object;.<init>:()V -> Ljava/lang/Object;-><init>()V
    if "." not in raw or ":" not in raw:
        return None
    class_part, right = raw.split(".", 1)
    method_name, method_type = right.split(":", 1)
    if not class_part.startswith("L") or not class_part.endswith(";"):
        return None
    return f"{class_part}->{method_name}{method_type}"


def method_class(sig: str) -> str:
    return sig.split("->", 1)[0] if "->" in sig else sig


def package_key(class_desc: str, depth: int = 3) -> str:
    body = class_desc.strip("L;")
    parts = body.split("/")
    if not parts:
        return "(none)"
    return "/".join(parts[:depth])


def is_focus(sig: str, prefixes: list[str]) -> bool:
    clazz = method_class(sig)
    return any(clazz.startswith(prefix) for prefix in prefixes)


def extract_dex_files(apk: Path, out_dir: Path) -> list[Path]:
    dex_dir = out_dir / "dex"
    dex_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(apk, "r") as zf:
        dex_names = sorted(n for n in zf.namelist() if n.startswith("classes") and n.endswith(".dex"))
        if not dex_names:
            raise RuntimeError("APK has no classes*.dex entries")
        for name in dex_names:
            zf.extract(name, dex_dir)
    return [dex_dir / name for name in dex_names]


def parse_dex(
    dexdump: str,
    dex_file: Path,
    methods_all: list[tuple[str, str, str, str]],
    methods_set: set[str],
    classes_set: set[str],
    edge_counter: collections.Counter[tuple[str, str]],
) -> None:
    cmd = [dexdump, "-d", str(dex_file)]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace")

    current_class = ""
    section = ""
    pending_method_name: str | None = None
    current_caller: str | None = None

    assert proc.stdout is not None
    for line in proc.stdout:
        m = CLASS_RE.search(line)
        if m:
            current_class = m.group(1)
            classes_set.add(current_class)
            section = ""
            pending_method_name = None
            continue

        m = SECTION_RE.search(line)
        if m:
            sec = m.group(1)
            if sec.startswith("Direct"):
                section = "direct"
            elif sec.startswith("Virtual"):
                section = "virtual"
            elif sec.startswith("Static"):
                section = "static"
            else:
                section = "instance"
            pending_method_name = None
            continue

        if section in {"direct", "virtual"} and ENTRY_RE.search(line):
            pending_method_name = None
            continue

        if section in {"direct", "virtual"}:
            m = NAME_RE.search(line)
            if m:
                pending_method_name = m.group(1)
                continue
            m = TYPE_RE.search(line)
            if m and pending_method_name and current_class:
                method_type = m.group(1)
                full_sig = f"{current_class}->{pending_method_name}{method_type}"
                methods_all.append((dex_file.name, current_class, pending_method_name, full_sig))
                methods_set.add(full_sig)
                pending_method_name = None
                continue

        m = CODE_HDR_RE.search(line)
        if m:
            current_caller = normalize_header_method(m.group(1).strip())
            if current_caller:
                methods_set.add(current_caller)
                classes_set.add(method_class(current_caller))
            continue

        if current_caller and "invoke-" in line:
            m = INVOKE_RE.search(line)
            if not m:
                continue
            callee = normalize_invoke_target(m.group(1))
            if not callee:
                continue
            methods_set.add(callee)
            classes_set.add(method_class(callee))
            edge_counter[(current_caller, callee)] += 1

    stderr = proc.stderr.read() if proc.stderr is not None else ""
    rc = proc.wait()
    if rc != 0:
        raise RuntimeError(f"dexdump failed for {dex_file}: {stderr.strip() or f'exit {rc}'}")


def write_text_lines(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    apk = Path(args.apk)
    if not apk.is_file():
        raise FileNotFoundError(apk)

    dexdump = Path(args.dexdump)
    if not dexdump.is_file():
        raise FileNotFoundError(dexdump)

    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    if args.out_dir:
        out_dir = Path(args.out_dir)
    else:
        out_dir = Path("/home/mikhail") / f"{apk.stem}_reverse_{ts}"
    out_dir.mkdir(parents=True, exist_ok=True)

    focus_prefixes = [p.strip() for p in args.focus_prefix if p and p.strip()]
    runtime_keywords = [k.strip().lower() for k in args.runtime_keyword if k and k.strip()]
    runtime_re = re.compile("|".join(re.escape(k) for k in runtime_keywords), re.IGNORECASE)

    dex_files = extract_dex_files(apk, out_dir)

    methods_all: list[tuple[str, str, str, str]] = []
    methods_set: set[str] = set()
    classes_set: set[str] = set()
    edge_counter: collections.Counter[tuple[str, str]] = collections.Counter()

    for dex_file in dex_files:
        parse_dex(str(dexdump), dex_file, methods_all, methods_set, classes_set, edge_counter)

    methods_all.sort(key=lambda x: x[3])
    methods_unique = sorted(methods_set)
    classes_unique = sorted(classes_set)

    methods_all_lines = [f"{dex}\t{clazz}\t{name}\t{sig}" for dex, clazz, name, sig in methods_all]
    write_text_lines(out_dir / "methods_all.txt", methods_all_lines)
    write_text_lines(out_dir / "methods_unique.txt", methods_unique)
    write_text_lines(out_dir / "classes_unique.txt", classes_unique)

    pkg_counter = collections.Counter(package_key(method_class(sig)) for sig in methods_unique)
    pkg_lines = ["package\tcount"] + [f"{pkg}\t{count}" for pkg, count in pkg_counter.most_common()]
    write_text_lines(out_dir / "methods_by_package.tsv", pkg_lines)

    focus_methods = sorted(sig for sig in methods_unique if is_focus(sig, focus_prefixes))
    focus_classes = sorted({method_class(sig) for sig in focus_methods})

    edge_rows: list[tuple[str, str, int, str]] = []
    runtime_rows: list[tuple[str, str, int, str]] = []
    focus_count_by_type = collections.Counter()
    runtime_count_by_type = collections.Counter()

    for (caller, callee), count in edge_counter.items():
        caller_focus = is_focus(caller, focus_prefixes)
        callee_focus = is_focus(callee, focus_prefixes)
        if not (caller_focus or callee_focus):
            continue
        if caller_focus and callee_focus:
            edge_type = "internal"
        elif caller_focus:
            edge_type = "outbound"
        else:
            edge_type = "inbound"
        edge_rows.append((caller, callee, count, edge_type))
        focus_count_by_type[edge_type] += count

        joined = f"{caller} {callee}"
        if runtime_re.search(joined):
            runtime_rows.append((caller, callee, count, edge_type))
            runtime_count_by_type[edge_type] += count

    edge_rows.sort(key=lambda x: (-x[2], x[0], x[1]))
    runtime_rows.sort(key=lambda x: (-x[2], x[0], x[1]))

    focus_dir = out_dir / "focus"
    write_text_lines(focus_dir / "methods_focus.txt", focus_methods)
    write_text_lines(focus_dir / "classes_focus.txt", focus_classes)

    edge_lines = ["caller\tcallee\tcount\ttype"] + [f"{c}\t{d}\t{n}\t{t}" for c, d, n, t in edge_rows]
    write_text_lines(focus_dir / "call_edges_focus.tsv", edge_lines)

    runtime_lines = ["caller\tcallee\tcount\ttype"] + [f"{c}\t{d}\t{n}\t{t}" for c, d, n, t in runtime_rows]
    write_text_lines(focus_dir / "call_edges_runtime_graphics.tsv", runtime_lines)

    caller_counter = collections.Counter()
    callee_counter = collections.Counter()
    for caller, callee, count, _ in edge_rows:
        caller_counter[caller] += count
        callee_counter[callee] += count
    top_callers = ["caller\tcount"] + [f"{s}\t{n}" for s, n in caller_counter.most_common(400)]
    top_callees = ["callee\tcount"] + [f"{s}\t{n}" for s, n in callee_counter.most_common(400)]
    write_text_lines(focus_dir / "top_callers_focus.tsv", top_callers)
    write_text_lines(focus_dir / "top_callees_focus.tsv", top_callees)

    summary_lines = [
        f"Generated: {datetime.now(timezone.utc).isoformat(timespec='seconds')}",
        f"APK: {apk}",
        f"Dex files: {len(dex_files)}",
        f"Target prefixes: {', '.join(focus_prefixes)}",
        f"All classes: {len(classes_unique)}",
        f"All methods: {len(methods_unique)}",
        f"Focus classes: {len(focus_classes)}",
        f"Focus methods: {len(focus_methods)}",
        f"Focus call edges (unique): {len(edge_rows)}",
        f"Focus outbound/inbound/internal events (total): {sum(focus_count_by_type.values())}",
        f"Runtime+graphics call edges (unique): {len(runtime_rows)}",
        f"Runtime+graphics outbound/inbound/internal events (total): {sum(runtime_count_by_type.values())}",
    ]
    write_text_lines(focus_dir / "focus_summary.txt", summary_lines)

    print(f"[apk-focus] wrote {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
