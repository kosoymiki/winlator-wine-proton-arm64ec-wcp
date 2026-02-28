#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

NEEDED_RE = re.compile(r"\(NEEDED\).*Shared library: \[(.+?)\]")
EXPORT_SPLIT_RE = re.compile(r"\s+")

STRING_MARKERS = [
    "WINEMU_",
    "HODLL",
    "ANDROID_RESOLV_DNS",
    "WINEDEBUG",
    "wine",
    "wineserver",
    "box64",
    "fex",
    "dxvk",
    "vkd3d",
    "vkEnumerateInstanceVersion",
    "X11",
    "epoll",
    "memfd",
    "Steam",
]

@dataclass
class LibRecord:
    abi: str
    name: str
    size_bytes: int
    sha256: str
    needed: List[str]
    export_count: int
    jni_export_count: int
    key_exports: List[str]
    string_markers: List[str]
    tier: str
    cluster: str


def run(cmd: List[str], timeout: int = 180) -> str:
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
    if p.returncode != 0:
        return ""
    return p.stdout


def classify(name: str) -> Tuple[str, str]:
    low = name.lower()
    tier = "tier2"
    cluster = "misc"

    if any(x in low for x in ("winemu", "xserver", "vfs", "gpuinfo", "streaming-core")):
        tier = "tier1"

    if "gpu" in low or "vulkan" in low:
        cluster = "gpu_probe"
    elif any(x in low for x in ("winemu", "xserver")):
        cluster = "runtime_orchestration"
    elif "vfs" in low:
        cluster = "virtual_fs"
    elif any(x in low for x in ("stream", "ijk", "peerconnection", "nvstream")):
        cluster = "streaming_media"
    elif any(x in low for x in ("box64", "fex", "wine")):
        cluster = "translator_runtime"
    elif any(x in low for x in ("gamesir", "usb", "ota", "input", "controller", "hid")):
        cluster = "input_peripheral"
    elif any(x in low for x in ("zstd", "lz", "zip", "tar", "ffmpeg", "swscale", "avutil")):
        cluster = "compression_media"

    return tier, cluster


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_needed(path: Path) -> List[str]:
    out = run(["readelf", "-d", str(path)])
    needed: List[str] = []
    for line in out.splitlines():
        m = NEEDED_RE.search(line)
        if m:
            needed.append(m.group(1))
    return needed


def parse_exports(path: Path) -> Tuple[int, int, List[str]]:
    out = run(["nm", "-D", "--defined-only", str(path)], timeout=300)
    if not out:
        return 0, 0, []

    export_count = 0
    jni_count = 0
    key_exports: List[str] = []

    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = EXPORT_SPLIT_RE.split(line)
        sym = parts[-1]
        export_count += 1

        if sym.startswith("Java_") or sym == "JNI_OnLoad":
            jni_count += 1

        if (
            sym == "JNI_OnLoad"
            or sym.startswith("Java_")
            or "wine" in sym.lower()
            or "box64" in sym.lower()
            or "fex" in sym.lower()
            or sym.startswith("vk")
            or "x11" in sym.lower()
            or "steam" in sym.lower()
            or "epoll" in sym.lower()
            or "memfd" in sym.lower()
        ):
            if len(key_exports) < 16:
                key_exports.append(sym)

    return export_count, jni_count, key_exports


def parse_string_markers(path: Path) -> List[str]:
    out = run(["strings", "-a", str(path)], timeout=300)
    if not out:
        return []
    found: List[str] = []
    lower = out.lower()
    for marker in STRING_MARKERS:
        if marker.lower() in lower:
            found.append(marker)
    return found


def load_libs(extract_root: Path) -> List[Path]:
    libs = sorted(extract_root.glob("lib/*/*.so"))
    return [p for p in libs if p.is_file()]


def analyze_apk(apk_path: Path) -> Tuple[List[LibRecord], Dict[str, object]]:
    tmp_dir = Path(tempfile.mkdtemp(prefix="apk_reverse_"))
    try:
        with zipfile.ZipFile(apk_path, "r") as zf:
            zf.extractall(tmp_dir)

        libs = load_libs(tmp_dir)
        records: List[LibRecord] = []
        abi_counter: Dict[str, int] = {}

        for so_path in libs:
            abi = so_path.parts[-2]
            name = so_path.name
            abi_counter[abi] = abi_counter.get(abi, 0) + 1

            needed = parse_needed(so_path)
            export_count, jni_count, key_exports = parse_exports(so_path)
            string_markers = parse_string_markers(so_path)
            tier, cluster = classify(name)

            records.append(
                LibRecord(
                    abi=abi,
                    name=name,
                    size_bytes=so_path.stat().st_size,
                    sha256=sha256_file(so_path),
                    needed=needed,
                    export_count=export_count,
                    jni_export_count=jni_count,
                    key_exports=key_exports,
                    string_markers=string_markers,
                    tier=tier,
                    cluster=cluster,
                )
            )

        summary = {
            "apk": str(apk_path),
            "lib_count": len(records),
            "abi_distribution": abi_counter,
            "tier1_count": sum(1 for r in records if r.tier == "tier1"),
            "cluster_distribution": {
                c: sum(1 for r in records if r.cluster == c)
                for c in sorted({r.cluster for r in records})
            },
        }
        return records, summary
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


def write_outputs(records: List[LibRecord], summary: Dict[str, object], out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)

    tsv_path = out_dir / "LIBRARY_MATRIX.tsv"
    with tsv_path.open("w", encoding="utf-8") as f:
        f.write(
            "\t".join(
                [
                    "abi",
                    "library",
                    "tier",
                    "cluster",
                    "size_bytes",
                    "sha256",
                    "needed_count",
                    "needed",
                    "export_count",
                    "jni_export_count",
                    "key_exports",
                    "string_markers",
                ]
            )
            + "\n"
        )
        for r in sorted(records, key=lambda x: (x.abi, x.name)):
            f.write(
                "\t".join(
                    [
                        r.abi,
                        r.name,
                        r.tier,
                        r.cluster,
                        str(r.size_bytes),
                        r.sha256,
                        str(len(r.needed)),
                        "|".join(r.needed),
                        str(r.export_count),
                        str(r.jni_export_count),
                        "|".join(r.key_exports),
                        "|".join(r.string_markers),
                    ]
                )
                + "\n"
            )

    summary_path = out_dir / "SUMMARY.json"
    summary_data = dict(summary)
    summary_data["libraries"] = [
        {
            "abi": r.abi,
            "name": r.name,
            "tier": r.tier,
            "cluster": r.cluster,
            "size_bytes": r.size_bytes,
            "sha256": r.sha256,
            "needed": r.needed,
            "export_count": r.export_count,
            "jni_export_count": r.jni_export_count,
            "key_exports": r.key_exports,
            "string_markers": r.string_markers,
        }
        for r in sorted(records, key=lambda x: (x.abi, x.name))
    ]
    summary_path.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    md_path = out_dir / "REVERSE_SUMMARY.md"
    with md_path.open("w", encoding="utf-8") as f:
        f.write("# Native Reverse Summary\n\n")
        f.write(f"- APK: `{summary['apk']}`\n")
        f.write(f"- Native libraries: **{summary['lib_count']}**\n")
        f.write(f"- Tier1 libraries: **{summary['tier1_count']}**\n")
        f.write(f"- ABI distribution: `{summary['abi_distribution']}`\n")
        f.write(f"- Cluster distribution: `{summary['cluster_distribution']}`\n\n")

        f.write("## Tier1 candidates\n\n")
        for r in sorted((x for x in records if x.tier == "tier1"), key=lambda x: x.name):
            f.write(
                f"- `{r.name}` ({r.cluster}) - needed={len(r.needed)}, exports={r.export_count}, jni={r.jni_export_count}\n"
            )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run native reverse cycle for APK")
    parser.add_argument("--apk", required=True, help="Path to APK")
    parser.add_argument("--out-dir", required=True, help="Output directory")
    args = parser.parse_args()

    apk = Path(args.apk)
    if not apk.is_file():
        print(f"[reverse][error] APK not found: {apk}", file=sys.stderr)
        return 1

    out_dir = Path(args.out_dir)
    records, summary = analyze_apk(apk)
    write_outputs(records, summary, out_dir)
    print(f"[reverse] analyzed {len(records)} libraries -> {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
