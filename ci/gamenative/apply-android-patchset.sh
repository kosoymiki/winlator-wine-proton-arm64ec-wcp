#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WCP_GN_PATCHSET_ENABLE:=1}"
: "${WCP_GN_PATCHSET_REF:=28c3a06ba773f6d29b9f3ed23b9297f94af4771c}"
: "${WCP_GN_PATCHSET_STRICT:=1}"
: "${WCP_GN_PATCHSET_VERIFY_AUTOFIX:=1}"
: "${WCP_GN_PATCHSET_MANIFEST:=${ROOT_DIR}/ci/gamenative/patchsets/28c3a06/manifest.tsv}"
: "${WCP_GN_PATCHSET_PATCH_ROOT:=${ROOT_DIR}/ci/gamenative/patchsets/28c3a06/android/patches}"
: "${WCP_GN_PATCHSET_ANDROID_SYSVSHM_ROOT:=${ROOT_DIR}/ci/gamenative/patchsets/28c3a06/android/android_sysvshm}"
: "${WCP_GN_PATCHSET_REPORT:=}"

TARGET=""
SOURCE_DIR=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") --target <wine|protonge> --source-dir <path>

Env:
  WCP_GN_PATCHSET_ENABLE        default: 1
  WCP_GN_PATCHSET_REF           default: 28c3a06ba773f6d29b9f3ed23b9297f94af4771c
  WCP_GN_PATCHSET_STRICT        default: 1
  WCP_GN_PATCHSET_VERIFY_AUTOFIX default: 1 (apply clean verify-missing patches)
  WCP_GN_PATCHSET_MANIFEST      default: ci/gamenative/patchsets/28c3a06/manifest.tsv
  WCP_GN_PATCHSET_PATCH_ROOT    default: ci/gamenative/patchsets/28c3a06/android/patches
  WCP_GN_PATCHSET_ANDROID_SYSVSHM_ROOT default: ci/gamenative/patchsets/28c3a06/android/android_sysvshm
  WCP_GN_PATCHSET_REPORT        optional TSV report path
USAGE
}

log() { printf '[gamenative][patchset] %s\n' "$*"; }
fail() { printf '[gamenative][patchset][error] %s\n' "$*" >&2; exit 1; }

require_bool() {
  local name="$1" value="$2"
  case "${value}" in
    0|1) ;;
    *) fail "${name} must be 0 or 1 (got: ${value})" ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --source-dir)
      SOURCE_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "${TARGET}" ]] || fail "--target is required"
[[ -n "${SOURCE_DIR}" ]] || fail "--source-dir is required"
[[ -d "${SOURCE_DIR}" ]] || fail "source dir not found: ${SOURCE_DIR}"
git -C "${SOURCE_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fail "source dir is not a git tree: ${SOURCE_DIR}"
[[ -f "${WCP_GN_PATCHSET_MANIFEST}" ]] || fail "manifest not found: ${WCP_GN_PATCHSET_MANIFEST}"
[[ -d "${WCP_GN_PATCHSET_PATCH_ROOT}" ]] || fail "patch root not found: ${WCP_GN_PATCHSET_PATCH_ROOT}"

case "${TARGET}" in
  wine|protonge) ;;
  *) fail "target must be wine or protonge (got: ${TARGET})" ;;
esac

require_bool WCP_GN_PATCHSET_ENABLE "${WCP_GN_PATCHSET_ENABLE}"
require_bool WCP_GN_PATCHSET_STRICT "${WCP_GN_PATCHSET_STRICT}"
require_bool WCP_GN_PATCHSET_VERIFY_AUTOFIX "${WCP_GN_PATCHSET_VERIFY_AUTOFIX}"

if [[ "${WCP_GN_PATCHSET_ENABLE}" != "1" ]]; then
  log "Patchset integration disabled (WCP_GN_PATCHSET_ENABLE=0)"
  exit 0
fi

if [[ -z "${WCP_GN_PATCHSET_REPORT}" ]]; then
  WCP_GN_PATCHSET_REPORT="${SOURCE_DIR}/../gamenative-patchset-${TARGET}.tsv"
fi
mkdir -p "$(dirname -- "${WCP_GN_PATCHSET_REPORT}")"

echo -e "target\tpatch\taction\tresult\tdetail" > "${WCP_GN_PATCHSET_REPORT}"

report() {
  local patch="$1" action="$2" result="$3" detail="$4"
  printf '%s\t%s\t%s\t%s\t%s\n' "${TARGET}" "${patch}" "${action}" "${result}" "${detail}" >> "${WCP_GN_PATCHSET_REPORT}"
}

file_has_fixed() {
  local file="$1" needle="$2"
  [[ -f "${file}" ]] || return 1
  grep -Fq "${needle}" "${file}"
}

file_has_regex() {
  local file="$1" pattern="$2"
  [[ -f "${file}" ]] || return 1
  grep -Eq "${pattern}" "${file}"
}

verify_patch_contract_markers() {
  local patch="$1"
  case "${patch}" in
    dlls_ntdll_loader_c.patch)
      file_has_fixed "${SOURCE_DIR}/dlls/ntdll/loader.c" 'libarm64ecfex.dll' \
        && file_has_fixed "${SOURCE_DIR}/dlls/ntdll/loader.c" 'pWow64SuspendLocalThread'
      ;;
    dlls_ntdll_ntdll_spec.patch|test-bylaws/dlls_ntdll_ntdll_spec.patch)
      file_has_fixed "${SOURCE_DIR}/dlls/ntdll/ntdll.spec" 'RtlWow64SuspendThread'
      ;;
    dlls_winex11_drv_window_c.patch)
      file_has_fixed "${SOURCE_DIR}/dlls/winex11.drv/window.c" 'class_hints->res_name = process_name;'
      ;;
    dlls_wow64_syscall_c.patch)
      file_has_fixed "${SOURCE_DIR}/dlls/wow64/syscall.c" 'L"HODLL"'
      ;;
    programs_wineboot_wineboot_c.patch)
      file_has_fixed "${SOURCE_DIR}/programs/wineboot/wineboot.c" 'initialize_xstate_features(struct _KUSER_SHARED_DATA *data)'
      ;;
    test-bylaws/dlls_ntdll_loader_c.patch)
      file_has_fixed "${SOURCE_DIR}/dlls/ntdll/loader.c" 'SkipLoaderInit'
      ;;
    test-bylaws/dlls_ntdll_signal_arm64_c.patch)
      file_has_fixed "${SOURCE_DIR}/dlls/ntdll/signal_arm64.c" 'RtlWow64SuspendThread'
      ;;
    test-bylaws/dlls_ntdll_signal_arm64ec_c.patch)
      file_has_fixed "${SOURCE_DIR}/dlls/ntdll/signal_arm64ec.c" 'ARM64EC_NT_XCONTEXT'
      ;;
    test-bylaws/dlls_ntdll_signal_x86_64_c.patch)
      file_has_fixed "${SOURCE_DIR}/dlls/ntdll/signal_x86_64.c" 'RtlWow64SuspendThread'
      ;;
    test-bylaws/dlls_ntdll_unix_thread_c.patch)
      file_has_fixed "${SOURCE_DIR}/dlls/ntdll/unix/thread.c" 'THREAD_CREATE_FLAGS_SKIP_LOADER_INIT'
      ;;
    test-bylaws/dlls_ntdll_unix_virtual_c.patch)
      file_has_fixed "${SOURCE_DIR}/dlls/ntdll/unix/virtual.c" 'MemoryFexStatsShm'
      ;;
    test-bylaws/dlls_wow64_process_c.patch)
      file_has_fixed "${SOURCE_DIR}/dlls/wow64/process.c" 'RtlWow64SuspendThread' \
        && file_has_fixed "${SOURCE_DIR}/dlls/wow64/process.c" 'Wow64SuspendLocalThread'
      ;;
    test-bylaws/dlls_wow64_syscall_c.patch)
      file_has_fixed "${SOURCE_DIR}/dlls/wow64/syscall.c" 'Wow64SuspendLocalThread'
      ;;
    programs_winemenubuilder_winemenubuilder_c.patch)
      file_has_fixed "${SOURCE_DIR}/programs/winemenubuilder/winemenubuilder.c" 'WINECONFIGDIR' \
        && file_has_regex "${SOURCE_DIR}/programs/winemenubuilder/winemenubuilder.c" 'icons\\\\hicolor' \
        && file_has_regex "${SOURCE_DIR}/programs/winemenubuilder/winemenubuilder.c" 'fprintf\(file, "wine '
      ;;
    test-bylaws/include_winternl_h.patch)
      file_has_fixed "${SOURCE_DIR}/include/winternl.h" 'THREAD_CREATE_FLAGS_BYPASS_PROCESS_FREEZE' \
        && file_has_fixed "${SOURCE_DIR}/include/winternl.h" 'ProcessFexHardwareTso' \
        && file_has_fixed "${SOURCE_DIR}/include/winternl.h" 'MemoryFexStatsShm'
      ;;
    test-bylaws/server_thread_c.patch)
      file_has_fixed "${SOURCE_DIR}/server/thread.c" 'bypass_proc_suspend'
      ;;
    test-bylaws/server_thread_h.patch)
      file_has_fixed "${SOURCE_DIR}/server/thread.h" 'bypass_proc_suspend'
      ;;
    test-bylaws/tools_makedep_c.patch)
      file_has_regex "${SOURCE_DIR}/tools/makedep.c" 'aarch64-windows|%s-windows'
      ;;
    *)
      return 1
      ;;
  esac
}

git_apply_check() {
  local patch_file="$1"
  git -C "${SOURCE_DIR}" apply --check "${patch_file}" >/dev/null 2>&1
}

git_reverse_check() {
  local patch_file="$1"
  git -C "${SOURCE_DIR}" apply --check --reverse "${patch_file}" >/dev/null 2>&1
}

git_apply_3way() {
  local patch_file="$1"
  git -C "${SOURCE_DIR}" apply --3way "${patch_file}" >/dev/null 2>&1
}

target_is_required() {
  local required_raw="$1"
  local token norm
  local -a _required_tokens
  required_raw="${required_raw// /}"
  [[ -n "${required_raw}" ]] || return 1
  IFS=',' read -r -a _required_tokens <<<"${required_raw}"
  for token in "${_required_tokens[@]}"; do
    norm="${token,,}"
    case "${norm}" in
      both|all) return 0 ;;
      wine|protonge)
        [[ "${norm}" == "${TARGET}" ]] && return 0
        ;;
    esac
  done
  return 1
}

run_apply_action() {
  local patch="$1" patch_file="$2" required_for_target="$3"

  if git_reverse_check "${patch_file}"; then
    report "${patch}" "apply" "already" "reverse-check-ok"
    return 0
  fi

  if git_apply_check "${patch_file}"; then
    git -C "${SOURCE_DIR}" apply "${patch_file}" || fail "git apply failed for ${patch}"
    report "${patch}" "apply" "applied" "applied-clean"
    return 0
  fi

  if git_apply_3way "${patch_file}"; then
    report "${patch}" "apply" "applied" "applied-3way"
    return 0
  fi

  if verify_patch_contract_markers "${patch}"; then
    report "${patch}" "apply" "already" "contract-markers"
    return 0
  fi

  report "${patch}" "apply" "conflict" "cannot-apply"
  if [[ "${WCP_GN_PATCHSET_STRICT}" == "1" || "${required_for_target}" == "1" ]]; then
    fail "patch ${patch} is marked apply but cannot be applied for target=${TARGET}"
  fi
  return 0
}

run_verify_action() {
  local patch="$1" patch_file="$2" required_for_target="$3"

  if git_reverse_check "${patch_file}"; then
    report "${patch}" "verify" "verified" "reverse-check-ok"
    return 0
  fi

  if git_apply_check "${patch_file}"; then
    if [[ "${WCP_GN_PATCHSET_VERIFY_AUTOFIX}" == "1" ]]; then
      if git -C "${SOURCE_DIR}" apply "${patch_file}" >/dev/null 2>&1; then
        report "${patch}" "verify" "autofixed" "applied-clean"
        return 0
      fi
      if git_apply_3way "${patch_file}"; then
        report "${patch}" "verify" "autofixed" "applied-3way"
        return 0
      fi
      report "${patch}" "verify" "missing" "apply-check-ok-but-apply-failed"
    else
      report "${patch}" "verify" "missing" "would-apply-clean"
    fi
    if [[ "${required_for_target}" == "1" && "${WCP_GN_PATCHSET_STRICT}" == "1" ]]; then
      fail "required verify patch ${patch} is missing for target=${TARGET}"
    fi
    return 0
  fi

  if [[ "${WCP_GN_PATCHSET_VERIFY_AUTOFIX}" == "1" ]]; then
    if git_apply_3way "${patch_file}"; then
      report "${patch}" "verify" "autofixed" "applied-3way"
      return 0
    fi
  fi

  if verify_patch_contract_markers "${patch}"; then
    report "${patch}" "verify" "verified" "contract-markers"
    return 0
  fi

  report "${patch}" "verify" "diverged" "apply-reverse-failed-no-contract-marker"
  if [[ "${required_for_target}" == "1" && "${WCP_GN_PATCHSET_STRICT}" == "1" ]]; then
    fail "required verify patch ${patch} diverged for target=${TARGET}"
  fi
  return 0
}

backport_wineboot_xstate() {
  local file
  file="${SOURCE_DIR}/programs/wineboot/wineboot.c"
  [[ -f "${file}" ]] || fail "missing ${file}"

  if grep -Fq 'xstate->AllFeatureSize = 0x340;' "${file}" \
    && grep -Fq 'initialize_xstate_features(struct _KUSER_SHARED_DATA *data)' "${file}"; then
    return 0
  fi

  python3 - "${file}" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = "#elif defined(__aarch64__)"
if marker not in text:
    raise SystemExit("aarch64 block marker not found")

head, tail = text.split(marker, 1)
if "#else" not in tail:
    raise SystemExit("missing #else delimiter in wineboot.c")

aarch64_block, rest = tail.split("#else", 1)
if "initialize_xstate_features(struct _KUSER_SHARED_DATA *data)" in aarch64_block:
    raise SystemExit(0)

inject = """

static void initialize_xstate_features(struct _KUSER_SHARED_DATA *data)
{
    XSTATE_CONFIGURATION *xstate = &data->XState;

    xstate->EnabledFeatures = (1 << XSTATE_LEGACY_FLOATING_POINT) | (1 << XSTATE_LEGACY_SSE) | (1 << XSTATE_AVX);
    xstate->EnabledVolatileFeatures = xstate->EnabledFeatures;
    xstate->AllFeatureSize = 0x340;

    xstate->OptimizedSave = 0;
    xstate->CompactionEnabled = 0;

    xstate->Features[0].Size = xstate->AllFeatures[0] = offsetof(XSAVE_FORMAT, XmmRegisters);
    xstate->Features[1].Size = xstate->AllFeatures[1] = sizeof(M128A) * 16;
    xstate->Features[1].Offset = xstate->Features[0].Size;
    xstate->Features[2].Offset = 0x240;
    xstate->Features[2].Size = 0x100;
    xstate->Size = 0x340;
}
"""

path.write_text(head + marker + aarch64_block + inject + "\n#else" + rest, encoding="utf-8")
PY
}

backport_include_winternl_fex() {
  local file
  file="${SOURCE_DIR}/include/winternl.h"
  [[ -f "${file}" ]] || fail "missing ${file}"

  python3 - "${file}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
updated = text

if "SkipLoaderInit" not in updated:
    teb_line = re.compile(
        r'^\s*USHORT\s+SameTebFlags;\s*/\*\s*fca/17ee\s*\*/\s*$',
        flags=re.M,
    )
    replacement = (
        "    union {\n"
        "        USHORT SameTebFlags;                                        /* fca/17ee */\n"
        "        struct {\n"
        "            USHORT SafeThunkCall : 1;\n"
        "            USHORT InDebugPrint : 1;\n"
        "            USHORT HasFiberData : 1;\n"
        "            USHORT SkipThreadAttach : 1;\n"
        "            USHORT WerInShipAssertCode : 1;\n"
        "            USHORT RanProcessInit : 1;\n"
        "            USHORT ClonedThread : 1;\n"
        "            USHORT SuppressDebugMsg : 1;\n"
        "            USHORT DisableUserStackWalk : 1;\n"
        "            USHORT RtlExceptionAttached : 1;\n"
        "            USHORT InitialThread : 1;\n"
        "            USHORT SessionAware : 1;\n"
        "            USHORT LoadOwner : 1;\n"
        "            USHORT LoaderWorker : 1;\n"
        "            USHORT SkipLoaderInit : 1;\n"
        "            USHORT SkipFileAPIBrokering : 1;\n"
        "        } DUMMYSTRUCTNAME;\n"
        "    } DUMMYUNIONNAME1;"
    )
    updated, count = teb_line.subn(replacement, updated, count=1)
    if count != 1:
        raise SystemExit("SameTebFlags field marker not found for TEB bitfield backport")

def patch_enum(block_name: str, closing_name: str, inject_after: str, inject_tail: str):
    global updated
    pattern = rf'(typedef enum _{block_name} \{{.*?)(\n\}}\s*{closing_name};)'
    m = re.search(pattern, updated, flags=re.S)
    if not m:
        raise SystemExit(f"{block_name} enum block not found")
    head = m.group(1)
    if inject_after in head:
        return
    if "ProcessWineUnixDebuggerPid = 1100," in head and block_name == "PROCESSINFOCLASS":
        head = re.sub(
            r'(ProcessWineUnixDebuggerPid\s*=\s*1100,\s*\n\s*#endif)',
            r'\1\n    ProcessFexHardwareTso = 2000,\n    ProcessFexUnalignAtomic,',
            head,
            count=1,
        )
    elif "MemoryWineUnixWow64Funcs," in head and block_name == "MEMORY_INFORMATION_CLASS":
        head = re.sub(
            r'(MemoryWineUnixWow64Funcs,\s*\n\s*#endif)',
            r'\1\n    MemoryFexStatsShm = 2000,',
            head,
            count=1,
        )
    else:
        head = head.rstrip() + "\n" + inject_tail
    updated = updated[:m.start(1)] + head + updated[m.start(2):]

patch_enum(
    block_name="PROCESSINFOCLASS",
    closing_name="PROCESSINFOCLASS",
    inject_after="ProcessFexHardwareTso",
    inject_tail="    ProcessFexHardwareTso = 2000,\n    ProcessFexUnalignAtomic,",
)

if "FEX_UNALIGN_ATOMIC_EMULATE" not in updated:
    marker = "#define MEM_EXECUTE_OPTION_DISABLE"
    if marker not in updated:
        raise SystemExit("MEM_EXECUTE_OPTION_DISABLE marker not found")
    updated = updated.replace(
        marker,
        "/* These match the prctl flag values */\n"
        "#define FEX_UNALIGN_ATOMIC_EMULATE            (1ULL << 0)\n"
        "#define FEX_UNALIGN_ATOMIC_BACKPATCH          (1ULL << 1)\n"
        "#define FEX_UNALIGN_ATOMIC_STRICT_SPLIT_LOCKS (1ULL << 2)\n\n"
        + marker,
        1,
    )

patch_enum(
    block_name="MEMORY_INFORMATION_CLASS",
    closing_name="MEMORY_INFORMATION_CLASS",
    inject_after="MemoryFexStatsShm",
    inject_tail="    MemoryFexStatsShm = 2000,",
)

if "MEMORY_FEX_STATS_SHM_INFORMATION" not in updated:
    marker = "} MEMORY_REGION_INFORMATION, *PMEMORY_REGION_INFORMATION;\n"
    if marker not in updated:
        raise SystemExit("MEMORY_REGION_INFORMATION marker not found")
    updated = updated.replace(
        marker,
        marker
        + "\n"
        + "typedef struct _MEMORY_FEX_STATS_SHM_INFORMATION\n"
        + "{\n"
        + "    void *shm_base;\n"
        + "    SIZE_T map_size;\n"
        + "} MEMORY_FEX_STATS_SHM_INFORMATION, *PMEMORY_FEX_STATS_SHM_INFORMATION;\n",
        1,
    )

if "THREAD_CREATE_FLAGS_SKIP_LOADER_INIT" not in updated:
    updated = re.sub(
        r'^\s*#define THREAD_CREATE_FLAGS_HAS_SECURITY_DESCRIPTOR\s+0x00000010\s*$',
        '#define THREAD_CREATE_FLAGS_LOADER_WORKER           0x00000010',
        updated,
        count=1,
        flags=re.M,
    )
    updated = re.sub(
        r'^\s*#define THREAD_CREATE_FLAGS_ACCESS_CHECK_IN_TARGET\s+0x00000020\s*$',
        '#define THREAD_CREATE_FLAGS_SKIP_LOADER_INIT        0x00000020\n'
        '#define THREAD_CREATE_FLAGS_BYPASS_PROCESS_FREEZE   0x00000040',
        updated,
        count=1,
        flags=re.M,
    )
    if "THREAD_CREATE_FLAGS_SKIP_LOADER_INIT" not in updated:
        raise SystemExit("thread flag backport marker not found in winternl.h")

if "RtlWow64SuspendThread(HANDLE,ULONG*)" not in updated:
    marker = "NTSYSAPI NTSTATUS  WINAPI RtlWow64IsWowGuestMachineSupported(USHORT,BOOLEAN*);\n"
    if marker not in updated:
        raise SystemExit("RtlWow64IsWowGuestMachineSupported marker not found")
    updated = updated.replace(
        marker,
        marker + "NTSYSAPI NTSTATUS  WINAPI RtlWow64SuspendThread(HANDLE,ULONG*);\n",
        1,
    )

path.write_text(updated, encoding="utf-8")
PY
}

backport_protonge_hodll() {
  local file
  file="${SOURCE_DIR}/dlls/wow64/syscall.c"
  [[ -f "${file}" ]] || fail "missing ${file}"

  if grep -Fq 'wow64GetEnvironmentVariableW' "${file}" && grep -Fq 'L"HODLL"' "${file}"; then
    return 0
  fi

  python3 - "${file}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
updated = text

if "wow64GetEnvironmentVariableW" not in updated:
    helper = """

/**********************************************************************
 *           wow64GetEnvironmentVariableW
 */
static DWORD wow64GetEnvironmentVariableW( LPCWSTR name, LPWSTR val, DWORD size )
{
    UNICODE_STRING us_name, us_value;
    NTSTATUS status;
    DWORD len;

    RtlInitUnicodeString( &us_name, name );
    us_value.Length = 0;
    us_value.MaximumLength = (size ? size - 1 : 0) * sizeof(WCHAR);
    us_value.Buffer = val;

    status = RtlQueryEnvironmentVariable_U( NULL, &us_name, &us_value );
    len = us_value.Length / sizeof(WCHAR);
    if (status == STATUS_BUFFER_TOO_SMALL) return len + 1;
    if (status) return 0;
    if (!size) return len + 1;
    val[len] = 0;
    return len;
}
"""
    marker = "return module;\n}\n"
    pos = updated.find(marker)
    if pos < 0:
      raise SystemExit("load_64bit_module() marker not found")
    pos += len(marker)
    updated = updated[:pos] + helper + updated[pos:]

if 'L"HODLL"' not in updated:
    pattern = (
        r'(\s*HANDLE key;\n\s*ULONG size;\n)\n'
        r'(\s*switch \(current_machine\))'
    )
    replace = (
        r'\1\n'
        r'    WCHAR *cpu_dll = (WCHAR*)buffer;\n'
        r'    UINT res;\n'
        r'    if ((res = wow64GetEnvironmentVariableW( L"HODLL", cpu_dll, ARRAY_SIZE(buffer))) &&\n'
        r'        res < ARRAY_SIZE(buffer))\n'
        r'        return cpu_dll;\n\n'
        r'\2'
    )
    updated, count = re.subn(pattern, replace, updated, count=1)
    if count != 1:
        raise SystemExit("HODLL override insertion point not found")

path.write_text(updated, encoding="utf-8")
PY
}

backport_protonge_winex11() {
  local file
  file="${SOURCE_DIR}/dlls/winex11.drv/window.c"
  [[ -f "${file}" ]] || fail "missing ${file}"

  if grep -Fq 'class_hints->res_name = process_name;' "${file}" && grep -Fq '#ifdef __ANDROID__' "${file}"; then
    return 0
  fi

  python3 - "${file}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
updated = text

old_block = re.compile(
    r'\s*static char steam_proton\[\] = "steam_proton";\n'
    r'\s*const char \*app_id = getenv\("SteamAppId"\);\n'
    r'\s*char proton_app_class\[128\];\n\n'
    r'\s*if\(app_id && \*app_id\)\{\n'
    r'\s*snprintf\(proton_app_class, sizeof\(proton_app_class\), "steam_app_%s", app_id\);\n'
    r'\s*class_hints->res_name = proton_app_class;\n'
    r'\s*class_hints->res_class = proton_app_class;\n'
    r'\s*\}else\{\n'
    r'\s*class_hints->res_name = steam_proton;\n'
    r'\s*class_hints->res_class = steam_proton;\n'
    r'\s*\}\n'
)
new_block = (
    '        #ifdef __ANDROID__\n'
    '        class_hints->res_name = process_name;\n'
    '        class_hints->res_class = process_name;\n'
    '        #else\n'
    '        static char steam_proton[] = "steam_proton";\n'
    '        const char *app_id = getenv("SteamAppId");\n'
    '        char proton_app_class[128];\n\n'
    '        if(app_id && *app_id){\n'
    '            snprintf(proton_app_class, sizeof(proton_app_class), "steam_app_%s", app_id);\n'
    '            class_hints->res_name = proton_app_class;\n'
    '            class_hints->res_class = proton_app_class;\n'
    '        }else{\n'
    '            class_hints->res_name = steam_proton;\n'
    '            class_hints->res_class = steam_proton;\n'
    '        }\n'
    '        #endif\n'
)
updated, class_count = old_block.subn(new_block, updated, count=1)
if class_count != 1:
    raise SystemExit("class hints replacement failed")

pid_block = re.compile(
    r'(\s*/\* set the WM_CLIENT_MACHINE and WM_LOCALE_NAME properties \*/\n'
    r'\s*XSetWMProperties\(display, window, NULL, NULL, NULL, 0, NULL, NULL, NULL\);\n)'
    r'(\s*/\* set the pid\. together, these properties are needed so the window manager can kill us if we freeze \*/\n'
    r'\s*i = getpid\(\);\n'
    r'\s*XChangeProperty\(display, window, x11drv_atom\(_NET_WM_PID\),\n'
    r'\s*XA_CARDINAL, 32, PropModeReplace, \(unsigned char \*\)&i, 1\);\n)'
)
updated, pid_count = pid_block.subn(r'\1#ifndef __ANDROID__\n\2#endif\n', updated, count=1)
if pid_count != 1:
    raise SystemExit("pid guard insertion failed")

if 'NtUserGetWindowThread( hwnd, &pid );' not in updated:
    marker = "    XFlush( data->display );\n"
    insert = (
        "    XFlush( data->display );\n"
        "\n"
        "#ifdef __ANDROID__\n"
        "    DWORD pid = 0;\n"
        "\n"
        "    NtUserGetWindowThread( hwnd, &pid );\n"
        "    XChangeProperty( data->display, window, x11drv_atom(_NET_WM_PID),\n"
        "                     XA_CARDINAL, 32, PropModeReplace, (unsigned char *)&pid, 1 );\n"
        "#endif\n"
    )
    if marker not in updated:
        raise SystemExit("set_net_active_window marker not found")
    updated = updated.replace(marker, insert, 1)

path.write_text(updated, encoding="utf-8")
PY
}

backport_protonge_unix_server() {
  local file
  file="${SOURCE_DIR}/dlls/ntdll/unix/server.c"
  [[ -f "${file}" ]] || fail "missing ${file}"

  if grep -Fq 'symlink( "/storage/emulated/0/", "dosdevices/d:" );' "${file}" \
    && grep -Fq 'symlink( "/data/data/app.gamenative/files/imagefs/", "dosdevices/z:" );' "${file}"; then
    return 0
  fi

  python3 - "${file}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

pattern = re.compile(
    r'if \(!mkdir\( "dosdevices", 0777 \)\)\n'
    r'\s*\{\n'
    r'\s*mkdir\( "drive_c", 0777 \);\n'
    r'\s*symlink\( "\.\./drive_c", "dosdevices/c:" \);\n'
    r'\s*symlink\( "/", "dosdevices/z:" \);\n'
    r'\s*\}',
    re.M,
)

replace = (
    'if (!mkdir( "dosdevices", 0777 ))\n'
    '    {\n'
    '#ifdef __ANDROID__\n'
    '        mkdir( "drive_d", 0777 );\n'
    '        symlink( "../drive_c", "dosdevices/c:" );\n'
    '        symlink( "/storage/emulated/0/", "dosdevices/d:" );\n'
    '        symlink( "/data/data/app.gamenative/files/imagefs/", "dosdevices/z:" );\n'
    '#else\n'
    '        mkdir( "drive_c", 0777 );\n'
    '        symlink( "../drive_c", "dosdevices/c:" );\n'
    '        symlink( "/", "dosdevices/z:" );\n'
    '#endif\n'
    '    }'
)

updated, count = pattern.subn(replace, text, count=1)
if count != 1:
    raise SystemExit("unix/server.c dosdevices block replacement failed")

path.write_text(updated, encoding="utf-8")
PY
}

run_backport_action() {
  local patch="$1" action="$2"

  case "${action}" in
    backport_wineboot_xstate)
      backport_wineboot_xstate
      ;;
    backport_protonge_hodll)
      backport_protonge_hodll
      ;;
    backport_protonge_winex11)
      backport_protonge_winex11
      ;;
    backport_protonge_unix_server)
      backport_protonge_unix_server
      ;;
    backport_include_winternl_fex)
      backport_include_winternl_fex
      ;;
    *)
      fail "Unsupported backport action: ${action}"
      ;;
  esac

  report "${patch}" "${action}" "applied" "targeted-backport"
}

ensure_android_sysvshm_header() {
  local src_shm_h dst_shm_h
  src_shm_h="${WCP_GN_PATCHSET_ANDROID_SYSVSHM_ROOT}/sys/shm.h"
  [[ -f "${src_shm_h}" ]] || return 0

  dst_shm_h="${SOURCE_DIR}/android/android_sysvshm/sys/shm.h"
  if [[ -f "${dst_shm_h}" ]]; then
    return 0
  fi

  mkdir -p "$(dirname -- "${dst_shm_h}")"
  cp -f "${src_shm_h}" "${dst_shm_h}"
  log "Injected android sysvshm shim header: ${dst_shm_h}"
}

log "Applying GameNative patchset ${WCP_GN_PATCHSET_REF} to target=${TARGET}"
log "manifest=${WCP_GN_PATCHSET_MANIFEST}"
log "source=${SOURCE_DIR}"
ensure_android_sysvshm_header

line_no=0
while IFS=$'\t' read -r patch wine_action protonge_action required note; do
  required_for_target=0
  line_no=$((line_no + 1))
  if [[ ${line_no} -eq 1 ]]; then
    continue
  fi
  [[ -n "${patch}" ]] || continue
  [[ "${patch}" =~ ^# ]] && continue

  case "${TARGET}" in
    wine) action="${wine_action}" ;;
    protonge) action="${protonge_action}" ;;
  esac

  patch_file="${WCP_GN_PATCHSET_PATCH_ROOT}/${patch}"
  [[ -f "${patch_file}" ]] || fail "patch file missing: ${patch_file}"
  if target_is_required "${required}"; then
    required_for_target=1
  fi

  case "${action}" in
    skip)
      if [[ "${required_for_target}" == "1" ]]; then
        report "${patch}" "skip" "invalid" "required-for-${TARGET}-but-skipped"
        fail "manifest mismatch: ${patch} required for ${TARGET} but action is skip"
      fi
      report "${patch}" "skip" "skipped" "not-applicable-for-${TARGET}"
      ;;
    apply)
      run_apply_action "${patch}" "${patch_file}" "${required_for_target}"
      ;;
    verify)
      run_verify_action "${patch}" "${patch_file}" "${required_for_target}"
      ;;
    backport_*)
      run_backport_action "${patch}" "${action}"
      ;;
    *)
      fail "Unknown action '${action}' for patch ${patch}"
      ;;
  esac
done < "${WCP_GN_PATCHSET_MANIFEST}"

log "Patchset report: ${WCP_GN_PATCHSET_REPORT}"
