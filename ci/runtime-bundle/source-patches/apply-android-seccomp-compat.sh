#!/usr/bin/env bash
set -euo pipefail

# Termux-inspired glibc source patchset for Android app seccomp environments.
# Focus: keep startup alive under blocked rseq/set_robust_list syscalls.

src_dir="${1:-}"
report_dir="${2:-}"

[[ -n "${src_dir}" ]] || { echo "[glibc-source-patch][error] missing SRC_DIR arg" >&2; exit 2; }
[[ -d "${src_dir}" ]] || { echo "[glibc-source-patch][error] SRC_DIR not found: ${src_dir}" >&2; exit 2; }
mkdir -p "${report_dir:-${src_dir}}"

python3 - "${src_dir}" "${report_dir:-${src_dir}}" <<'PY'
import json
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
report = Path(sys.argv[2])

changes = []


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, data: str) -> None:
    path.write_text(data, encoding="utf-8")


def replace_regex(path: Path, pattern: str, repl: str, flags=0, min_count=1):
    text = read_text(path)
    updated, count = re.subn(pattern, repl, text, flags=flags)
    if count < min_count:
        raise RuntimeError(f"{path}: expected >= {min_count} replacements for pattern {pattern!r}, got {count}")
    if updated != text:
        write_text(path, updated)
        changes.append({"file": str(path.relative_to(src)), "op": "regex", "count": count})


def replace_literal(path: Path, old: str, new: str):
    text = read_text(path)
    if old not in text:
        raise RuntimeError(f"{path}: literal fragment not found")
    updated = text.replace(old, new)
    if updated != text:
        write_text(path, updated)
        changes.append({"file": str(path.relative_to(src)), "op": "literal", "count": text.count(old)})


def replace_function_body(path: Path, signature: str, body: str):
    text = read_text(path)
    idx = text.find(signature)
    if idx < 0:
        raise RuntimeError(f"{path}: function signature not found: {signature}")
    brace = text.find("{", idx)
    if brace < 0:
        raise RuntimeError(f"{path}: opening brace not found for {signature}")

    depth = 0
    end = -1
    for i in range(brace, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i
                break
    if end < 0:
        raise RuntimeError(f"{path}: closing brace not found for {signature}")

    replacement = signature + "\n{\n" + body.rstrip() + "\n}\n"
    updated = text[:idx] + replacement + text[end + 1 :]
    if updated != text:
        write_text(path, updated)
        changes.append({"file": str(path.relative_to(src)), "op": "function-body", "count": 1})


# 1) rseq: force userspace fallback path to avoid seccomp SIGSYS on Android.
replace_function_body(
    src / "sysdeps/unix/sysv/linux/rseq-internal.h",
    "static inline bool\nrseq_register_current_thread (struct pthread *self, bool do_rseq)",
    "  (void) self;\n  (void) do_rseq;\n  RSEQ_SETMEM (cpu_id, RSEQ_CPU_ID_REGISTRATION_FAILED);\n  return false;",
)

# 2) robust-list: remove direct syscall path in thread start/fork and keep availability disabled.
replace_regex(
    src / "nptl/pthread_create.c",
    r"(?ms)^\s*INTERNAL_SYSCALL_CALL \(set_robust_list,\s*&pd->robust_head,\s*sizeof \(struct robust_list_head\)\);\n",
    "      /* Android seccomp compat: set_robust_list intentionally skipped. */\n",
    min_count=1,
)
replace_regex(
    src / "sysdeps/nptl/_Fork.c",
    r"(?ms)^\s*INTERNAL_SYSCALL_CALL \(set_robust_list,\s*&self->robust_head,\s*sizeof \(struct robust_list_head\)\);\n",
    "      /* Android seccomp compat: set_robust_list intentionally skipped. */\n",
    min_count=1,
)
replace_literal(
    src / "sysdeps/nptl/dl-tls_init_tp.c",
    "__nptl_set_robust_list_avail = true;",
    "__nptl_set_robust_list_avail = false;",
)

# 3) Keep an auditable marker in source tree.
marker = src / ".wcp-android-seccomp-compat-applied"
marker.write_text("android-seccomp-rseq-robust-v1\n", encoding="utf-8")
changes.append({"file": str(marker.relative_to(src)), "op": "marker", "count": 1})

report.mkdir(parents=True, exist_ok=True)
(report / "source-patch-summary.json").write_text(
    json.dumps(
        {
            "patchset": "android-seccomp-rseq-robust-v1",
            "changes": changes,
        },
        indent=2,
        ensure_ascii=True,
    )
    + "\n",
    encoding="utf-8",
)
print(f"[glibc-source-patch] applied android-seccomp-rseq-robust-v1 ({len(changes)} edits)")
PY

echo "[glibc-source-patch] done: android-seccomp-rseq-robust-v1"
