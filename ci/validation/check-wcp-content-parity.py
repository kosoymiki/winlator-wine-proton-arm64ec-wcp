#!/usr/bin/env python3
import argparse
import hashlib
import json
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path
from typing import Dict, List, Set

CRITICAL_PATHS = [
    "bin/wine",
    "bin/wineserver",
    "lib/wine/aarch64-unix/ntdll.so",
    "lib/wine/aarch64-unix/winex11.so",
    "lib/wine/aarch64-unix/winealsa.so",
    "lib/wine/i386-unix/ntdll.so",
    "lib/wine/i386-unix/winex11.so",
]

SOURCE_REQUIRED_PATHS = [
    "bin/wine",
    "bin/wineserver",
    "lib/wine/aarch64-unix/ntdll.so",
    "lib/wine/aarch64-unix/winex11.so",
]


def looks_like_payload_root(path: Path) -> bool:
    return (path / "bin").is_dir() and (path / "lib").is_dir()


def run(cmd: List[str], timeout: int = 1200) -> int:
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout).returncode


def extract_source(src: Path, out_dir: Path) -> Path:
    if src.is_dir():
        return src
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        with tarfile.open(src, "r:*") as tf:
            tf.extractall(out_dir)
        return out_dir
    except tarfile.TarError:
        pass
    if shutil.which("zstd"):
        rc = run(["bash", "-lc", f"zstd -dc '{src}' | tar -xf - -C '{out_dir}'"])
        if rc == 0:
            return out_dir
    raise RuntimeError(f"Unsupported source archive: {src}")


def resolve_payload_root(path: Path) -> Path:
    if looks_like_payload_root(path):
        return path
    try:
        dirs = sorted([child for child in path.iterdir() if child.is_dir()])
    except OSError:
        return path
    if len(dirs) == 1 and looks_like_payload_root(dirs[0]):
        return dirs[0]
    return path


def is_binary(path: Path) -> bool:
    try:
        with path.open("rb") as f:
            magic4 = f.read(4)
            if magic4 == b"\x7fELF":
                return True
            if magic4[:2] == b"MZ":
                return True
            return False
    except OSError:
        return False


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def scan(root: Path) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for p in sorted(root.rglob("*")):
        if not p.is_file():
            continue
        if not is_binary(p):
            continue
        rel = str(p.relative_to(root))
        out[rel] = sha256_file(p)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Check parity between source WCP and installed contents")
    parser.add_argument("--source", required=True, help="WCP archive path or extracted dir")
    parser.add_argument("--installed", required=True, help="Installed contents directory")
    parser.add_argument("--out", required=True, help="Output markdown report")
    args = parser.parse_args()

    source = Path(args.source)
    installed = Path(args.installed)
    out = Path(args.out)

    if not source.exists():
        raise SystemExit(f"[parity][error] source missing: {source}")
    if not installed.exists():
        raise SystemExit(f"[parity][error] installed missing: {installed}")

    tmp = Path(tempfile.mkdtemp(prefix="wcp_parity_"))
    try:
        src_root = resolve_payload_root(extract_source(source, tmp / "src"))
        dst_root = resolve_payload_root(installed)
        src_map = scan(src_root)
        dst_map = scan(dst_root)

        src_keys: Set[str] = set(src_map.keys())
        dst_keys: Set[str] = set(dst_map.keys())

        missing = sorted(src_keys - dst_keys)
        extra = sorted(dst_keys - src_keys)
        common = sorted(src_keys & dst_keys)
        drift = [k for k in common if src_map[k] != dst_map[k]]

        source_critical_missing = [p for p in SOURCE_REQUIRED_PATHS if p not in src_keys]
        critical_missing = [p for p in CRITICAL_PATHS if p in src_keys and p in missing]

        out.parent.mkdir(parents=True, exist_ok=True)
        with out.open("w", encoding="utf-8") as f:
            f.write("# WCP vs Installed Content Parity\n\n")
            f.write(f"- Source: `{source}`\n")
            f.write(f"- Installed: `{installed}`\n")
            f.write(f"- Source scan root: `{src_root}`\n")
            f.write(f"- Installed scan root: `{dst_root}`\n")
            f.write(f"- Source binary count: **{len(src_keys)}**\n")
            f.write(f"- Installed binary count: **{len(dst_keys)}**\n")
            f.write(f"- Source critical missing: **{len(source_critical_missing)}**\n")
            f.write(f"- Missing in installed: **{len(missing)}**\n")
            f.write(f"- Extra in installed: **{len(extra)}**\n")
            f.write(f"- SHA drift in common paths: **{len(drift)}**\n")
            f.write(f"- Critical missing: **{len(critical_missing)}**\n\n")

            f.write("## Critical paths missing in source payload\n\n")
            for p in source_critical_missing:
                f.write(f"- `{p}`\n")

            f.write("## Critical missing paths\n\n")
            for p in critical_missing:
                f.write(f"- `{p}`\n")

            f.write("\n## Missing in installed (first 120)\n\n")
            for p in missing[:120]:
                f.write(f"- `{p}`\n")

            f.write("\n## Extra in installed (first 120)\n\n")
            for p in extra[:120]:
                f.write(f"- `{p}`\n")

            f.write("\n## SHA drift in common paths (first 120)\n\n")
            for p in drift[:120]:
                f.write(f"- `{p}`\n")

        json_out = out.with_suffix(".json")
        json_out.write_text(
            json.dumps(
                {
                    "source": str(source),
                    "installed": str(installed),
                    "source_scan_root": str(src_root),
                    "installed_scan_root": str(dst_root),
                    "source_binary_count": len(src_keys),
                    "installed_binary_count": len(dst_keys),
                    "source_critical_missing_count": len(source_critical_missing),
                    "missing_count": len(missing),
                    "extra_count": len(extra),
                    "drift_count": len(drift),
                    "critical_missing_count": len(critical_missing),
                    "source_critical_missing": source_critical_missing,
                    "critical_missing": critical_missing,
                    "missing_sample": missing[:120],
                    "extra_sample": extra[:120],
                    "drift_sample": drift[:120],
                },
                indent=2,
                ensure_ascii=False,
            )
            + "\n",
            encoding="utf-8",
        )

        if source_critical_missing:
            print(f"[parity][fail] source payload missing critical paths: {len(source_critical_missing)}")
            return 1
        if critical_missing:
            print(f"[parity][fail] critical missing paths: {len(critical_missing)}")
            return 1
        print(f"[parity] report written: {out}")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
