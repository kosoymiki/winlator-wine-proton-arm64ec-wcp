#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile
from pathlib import Path
from typing import Dict, List, Tuple

NEEDED_RE = re.compile(r"\(NEEDED\).*Shared library: \[(.+?)\]")
SONAME_RE = re.compile(r"\(SONAME\).*Library soname: \[(.+?)\]")
RPATH_RE = re.compile(r"\(RPATH\).*Library rpath: \[(.+?)\]")
RUNPATH_RE = re.compile(r"\(RUNPATH\).*Library runpath: \[(.+?)\]")
MACHINE_RE = re.compile(r"^\s*Machine:\s*(.+?)\s*$")
CLASS_RE = re.compile(r"^\s*Class:\s*(.+?)\s*$")
TYPE_RE = re.compile(r"^\s*Type:\s*(.+?)\s*$")
PE_IMPORT_RE = re.compile(r"^\s*DLL Name:\s+(.+?)\s*$")
PE_EXPORT_RE = re.compile(r"^\s*\[\s*\d+\]\s+(.+?)\s*$")

STRING_MARKERS = [
    "wine",
    "wineserver",
    "wow64",
    "ntdll",
    "kernel32",
    "box64",
    "fex",
    "x11",
    "vulkan",
    "dxvk",
    "vkd3d",
    "proton",
    "steam",
    "ANDROID_RESOLV_DNS",
    "WRAPPER_",
    "VK_API_VERSION",
    "epoll",
    "memfd",
    "HODLL",
]

CRITICAL_MARKERS = (
    "wine",
    "wineserver",
    "ntdll",
    "kernel32",
    "wow64",
    "x11",
    "vulkan",
    "box64",
    "fex",
    "dxvk",
    "vkd3d",
)


def run(cmd: List[str], timeout: int = 300) -> Tuple[int, str, str]:
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
    return p.returncode, p.stdout, p.stderr


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def is_elf(path: Path) -> bool:
    try:
        with path.open("rb") as f:
            return f.read(4) == b"\x7fELF"
    except OSError:
        return False


def is_mz(path: Path) -> bool:
    try:
        with path.open("rb") as f:
            return f.read(2) == b"MZ"
    except OSError:
        return False


def classify(path_str: str, needed: List[str], markers: List[str]) -> str:
    low = path_str.lower()
    hit = set(m.lower() for m in markers)
    needed_low = set(x.lower() for x in needed)

    if any(x in low for x in ("wineserver", "/bin/wine", "libwine.so", "ntdll", "wow64")):
        return "wine_runtime_core"
    if any(x in low for x in ("x11", "winex11", "libx", "wayland")):
        return "display_windowing"
    if any(x in low for x in ("vulkan", "dxvk", "vkd3d", "d3d", "wined3d", "mesa", "turnip")):
        return "graphics_translation"
    if any(x in low for x in ("box64", "fex")) or "box64" in hit or "fex" in hit:
        return "cpu_translation"
    if any(x in low for x in ("pulse", "alsa", "audio", "openal")):
        return "audio"
    if any(x in needed_low for x in ("libssl.so", "libcrypto.so", "libcurl.so")):
        return "network_crypto"
    return "misc"


def parse_readelf_header(header: str) -> Dict[str, str]:
    out = {"class": "", "machine": "", "type": ""}
    for line in header.splitlines():
        m = CLASS_RE.match(line)
        if m:
            out["class"] = m.group(1)
            continue
        m = MACHINE_RE.match(line)
        if m:
            out["machine"] = m.group(1)
            continue
        m = TYPE_RE.match(line)
        if m:
            out["type"] = m.group(1)
    return out


def parse_dynamic(dynamic: str) -> Dict[str, object]:
    needed: List[str] = []
    soname = ""
    rpath = ""
    runpath = ""
    for line in dynamic.splitlines():
        m = NEEDED_RE.search(line)
        if m:
            needed.append(m.group(1))
            continue
        m = SONAME_RE.search(line)
        if m:
            soname = m.group(1)
            continue
        m = RPATH_RE.search(line)
        if m:
            rpath = m.group(1)
            continue
        m = RUNPATH_RE.search(line)
        if m:
            runpath = m.group(1)
    return {
        "needed": needed,
        "soname": soname,
        "rpath": rpath,
        "runpath": runpath,
    }


def parse_nm_dynamic(nm_out: str) -> Dict[str, object]:
    defined = 0
    undefined = 0
    jni_exports = 0
    vk_exports = 0
    key_symbols: List[str] = []
    head_lines: List[str] = []

    for idx, line in enumerate(nm_out.splitlines()):
        s = line.strip()
        if not s:
            continue
        if idx < 2000:
            head_lines.append(line)

        parts = s.split()
        sym = parts[-1]
        sym_low = sym.lower()
        sym_type = parts[-2] if len(parts) >= 2 else ""
        if sym_type.upper() == "U":
            undefined += 1
        else:
            defined += 1

        if sym.startswith("Java_") or sym == "JNI_OnLoad":
            jni_exports += 1
        if sym.startswith("vk") or "vulkan" in sym_low:
            vk_exports += 1

        if len(key_symbols) < 80 and any(x in sym_low for x in CRITICAL_MARKERS):
            key_symbols.append(sym)

    return {
        "defined": defined,
        "undefined": undefined,
        "jni_exports": jni_exports,
        "vk_exports": vk_exports,
        "key_symbols": key_symbols,
        "nm_head": "\n".join(head_lines) + ("\n" if head_lines else ""),
    }


def parse_objdump_pe(objdump_out: str) -> Dict[str, object]:
    imports: List[str] = []
    exports: List[str] = []
    for line in objdump_out.splitlines():
        m = PE_IMPORT_RE.match(line)
        if m:
            imports.append(m.group(1).strip())
            continue
        m = PE_EXPORT_RE.match(line)
        if m and len(exports) < 500:
            exports.append(m.group(1).strip())
    return {"imports": imports, "exports": exports}


def strings_hits(path: Path, markers: List[str], max_hits: int = 300) -> Tuple[List[str], List[str]]:
    lower_markers = [m.lower() for m in markers]
    hit_set = set()
    lines: List[str] = []
    proc = subprocess.Popen(
        ["strings", "-a", str(path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        errors="replace",
    )
    assert proc.stdout is not None
    try:
        for raw in proc.stdout:
            line = raw.rstrip("\n")
            l = line.lower()
            matched = [markers[i] for i, mk in enumerate(lower_markers) if mk in l]
            if not matched:
                continue
            for m in matched:
                hit_set.add(m)
            if len(lines) < max_hits:
                lines.append(line)
    finally:
        proc.wait(timeout=120)
    return sorted(hit_set), lines


def extract_source(src: Path, workdir: Path) -> Path:
    if src.is_dir():
        return src
    if src.suffix.lower() == ".apk":
        out = workdir / "apk_extract"
        out.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(src, "r") as zf:
            zf.extractall(out)
        return out
    if zipfile.is_zipfile(src):
        out = workdir / "zip_extract"
        out.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(src, "r") as zf:
            zf.extractall(out)
        return out
    out = workdir / "tar_extract"
    out.mkdir(parents=True, exist_ok=True)
    try:
        with tarfile.open(src, "r:*") as tf:
            tf.extractall(out)
        return out
    except tarfile.TarError:
        pass
    if shutil.which("zstd"):
        rc, _, _ = run(["bash", "-lc", f"zstd -dc '{src}' | tar -xf - -C '{out}'"], timeout=1800)
        if rc == 0:
            return out
    raise ValueError(f"Unsupported source type: {src}")


def collect_elfs(root: Path) -> List[Path]:
    files: List[Path] = []
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        if is_elf(p):
            files.append(p)
        elif is_mz(p):
            files.append(p)
    return sorted(files)


def safe_id(rel: str) -> str:
    out = rel.replace("/", "__").replace("\\", "__")
    out = out.replace(":", "_")
    if len(out) > 180:
        h = hashlib.sha256(rel.encode("utf-8")).hexdigest()[:16]
        out = out[:150] + "__" + h
    return out


def ensure_tools() -> List[str]:
    missing = []
    for t in ("readelf", "nm", "strings", "file", "objdump"):
        if shutil.which(t) is None:
            missing.append(t)
    return missing


def analyze(source: Path, label: str, out_dir: Path) -> int:
    missing = ensure_tools()
    if missing:
        print(f"[ide-cycle][error] Missing required tools: {', '.join(missing)}", file=sys.stderr)
        return 2

    out_dir.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix="elf_ide_"))
    try:
        root = extract_source(source, tmp)
        binaries = collect_elfs(root)

        records: List[Dict[str, object]] = []
        cluster_count: Dict[str, int] = {}
        machine_count: Dict[str, int] = {}

        libs_dir = out_dir / "libs"
        libs_dir.mkdir(parents=True, exist_ok=True)

        for idx, elf in enumerate(binaries, start=1):
            rel = str(elf.relative_to(root))
            lid = safe_id(rel)
            ldir = libs_dir / lid
            ldir.mkdir(parents=True, exist_ok=True)

            binary_format = "elf" if is_elf(elf) else "pe"
            rc_h = rc_l = rc_d = rc_s = rc_nm = 1
            out_h = out_l = out_d = out_s = out_nm = ""
            pe_parsed: Dict[str, object] = {"imports": [], "exports": []}

            if binary_format == "elf":
                rc_h, out_h, _ = run(["readelf", "-h", str(elf)])
                rc_l, out_l, _ = run(["readelf", "-l", str(elf)])
                rc_d, out_d, _ = run(["readelf", "-d", str(elf)])
                rc_s, out_s, _ = run(["readelf", "-S", str(elf)])
                rc_nm, out_nm, _ = run(["nm", "-D", str(elf)], timeout=600)
            else:
                rc_h, out_h, _ = run(["objdump", "-x", str(elf)], timeout=600)
                pe_parsed = parse_objdump_pe(out_h if rc_h == 0 else "")
            rc_file, out_file, _ = run(["file", "-b", str(elf)])

            header = parse_readelf_header(out_h if (rc_h == 0 and binary_format == "elf") else "")
            dynamic = parse_dynamic(out_d if (rc_d == 0 and binary_format == "elf") else "")
            if binary_format == "pe":
                dynamic = {
                    "needed": pe_parsed.get("imports", []),
                    "soname": elf.name,
                    "rpath": "",
                    "runpath": "",
                }
            nm_meta = parse_nm_dynamic(out_nm if (rc_nm == 0 and binary_format == "elf") else "")
            marker_set, marker_lines = strings_hits(elf, STRING_MARKERS, max_hits=300)

            cluster = classify(rel, dynamic.get("needed", []), marker_set)
            cluster_count[cluster] = cluster_count.get(cluster, 0) + 1
            machine = header.get("machine", "") or "unknown"
            machine_count[machine] = machine_count.get(machine, 0) + 1

            rec = {
                "id": lid,
                "relative_path": rel,
                "size_bytes": elf.stat().st_size,
                "sha256": sha256_file(elf),
                "binary_format": binary_format,
                "file_desc": (out_file.strip() if rc_file == 0 else ""),
                "class": header.get("class", ""),
                "machine": machine,
                "type": header.get("type", ""),
                "soname": dynamic.get("soname", ""),
                "rpath": dynamic.get("rpath", ""),
                "runpath": dynamic.get("runpath", ""),
                "needed": dynamic.get("needed", []),
                "defined_symbols": nm_meta.get("defined", 0),
                "undefined_symbols": nm_meta.get("undefined", 0),
                "jni_exports": nm_meta.get("jni_exports", 0),
                "vk_exports": nm_meta.get("vk_exports", 0),
                "key_symbols": nm_meta.get("key_symbols", []),
                "pe_exports_sample": pe_parsed.get("exports", [])[:120],
                "string_markers": marker_set,
                "cluster": cluster,
                "critical": any(x in rel.lower() for x in CRITICAL_MARKERS) or cluster in {
                    "wine_runtime_core",
                    "graphics_translation",
                    "cpu_translation",
                    "display_windowing",
                },
            }
            records.append(rec)

            (ldir / "manifest.json").write_text(
                json.dumps(rec, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            if binary_format == "elf":
                (ldir / "readelf_header.txt").write_text(out_h, encoding="utf-8", errors="replace")
                (ldir / "readelf_program_headers.txt").write_text(out_l, encoding="utf-8", errors="replace")
                (ldir / "readelf_dynamic.txt").write_text(out_d, encoding="utf-8", errors="replace")
            else:
                (ldir / "objdump_headers.txt").write_text(out_h, encoding="utf-8", errors="replace")
            (ldir / "strings_hits.txt").write_text(
                "\n".join(marker_lines) + ("\n" if marker_lines else ""),
                encoding="utf-8",
                errors="replace",
            )

            if rec["critical"]:
                if binary_format == "elf":
                    (ldir / "nm_dynamic_head.txt").write_text(
                        nm_meta.get("nm_head", ""), encoding="utf-8", errors="replace"
                    )
                    (ldir / "readelf_sections.txt").write_text(out_s, encoding="utf-8", errors="replace")
                elif pe_parsed.get("exports"):
                    (ldir / "pe_exports_sample.txt").write_text(
                        "\n".join(pe_parsed.get("exports", [])[:500]) + "\n",
                        encoding="utf-8",
                        errors="replace",
                    )

            if idx % 25 == 0:
                print(f"[ide-cycle] {label}: analyzed {idx}/{len(binaries)} binary files")

        summary = {
            "label": label,
            "source": str(source),
            "source_root": str(root),
            "binary_count": len(records),
            "elf_count": sum(1 for r in records if r.get("binary_format") == "elf"),
            "pe_count": sum(1 for r in records if r.get("binary_format") == "pe"),
            "critical_count": sum(1 for r in records if r.get("critical")),
            "cluster_distribution": cluster_count,
            "machine_distribution": machine_count,
            "libraries": records,
        }

        (out_dir / "SUMMARY.json").write_text(
            json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )

        with (out_dir / "LIBRARY_MATRIX.tsv").open("w", encoding="utf-8") as f:
            f.write(
                "\t".join(
                    [
                        "id",
                        "relative_path",
                        "binary_format",
                        "cluster",
                        "critical",
                        "size_bytes",
                        "sha256",
                        "class",
                        "machine",
                        "type",
                        "soname",
                        "needed_count",
                        "needed",
                        "defined_symbols",
                        "undefined_symbols",
                        "jni_exports",
                        "vk_exports",
                        "string_markers",
                    ]
                )
                + "\n"
            )
            for r in records:
                f.write(
                    "\t".join(
                        [
                            str(r["id"]),
                            str(r["relative_path"]),
                            str(r["binary_format"]),
                            str(r["cluster"]),
                            str(r["critical"]),
                            str(r["size_bytes"]),
                            str(r["sha256"]),
                            str(r["class"]),
                            str(r["machine"]),
                            str(r["type"]),
                            str(r["soname"]),
                            str(len(r["needed"])),
                            "|".join(r["needed"]),
                            str(r["defined_symbols"]),
                            str(r["undefined_symbols"]),
                            str(r["jni_exports"]),
                            str(r["vk_exports"]),
                            "|".join(r["string_markers"]),
                        ]
                    )
                    + "\n"
                )

        md = out_dir / "IDE_REFLECTIVE_REPORT.md"
        with md.open("w", encoding="utf-8") as f:
            f.write("# IDE-level ELF Reflective Report\n\n")
            f.write(f"- Label: `{label}`\n")
            f.write(f"- Source: `{source}`\n")
            f.write(f"- Binary files (ELF+PE): **{summary['binary_count']}**\n")
            f.write(f"- ELF files: **{summary['elf_count']}**\n")
            f.write(f"- PE files: **{summary['pe_count']}**\n")
            f.write(f"- Critical libs: **{summary['critical_count']}**\n")
            f.write(f"- Machine distribution: `{summary['machine_distribution']}`\n")
            f.write(f"- Cluster distribution: `{summary['cluster_distribution']}`\n\n")
            f.write("## Top critical libraries\n\n")
            critical = [r for r in records if r["critical"]]
            critical.sort(key=lambda x: (x["cluster"], x["relative_path"]))
            for r in critical[:120]:
                f.write(
                    f"- `{r['relative_path']}` [{r['cluster']}] needed={len(r['needed'])} "
                    f"defined={r['defined_symbols']} undefined={r['undefined_symbols']} "
                    f"jni={r['jni_exports']} vk={r['vk_exports']}\n"
                )

        print(f"[ide-cycle] {label}: analyzed {len(records)} binary files -> {out_dir}")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="IDE-level reflective ELF cycle for APK/TAR/DIR sources")
    parser.add_argument("--source", required=True, help="Path to source (apk/tar/wcp.xz/dir)")
    parser.add_argument("--label", required=True, help="Short label")
    parser.add_argument("--out-dir", required=True, help="Output directory")
    args = parser.parse_args()

    source = Path(args.source)
    if not source.exists():
        print(f"[ide-cycle][error] Source not found: {source}", file=sys.stderr)
        return 1

    return analyze(source, args.label, Path(args.out_dir))


if __name__ == "__main__":
    raise SystemExit(main())
