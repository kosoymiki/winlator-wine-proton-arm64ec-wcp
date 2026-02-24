#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for packaging Wine/Proton runtimes for Winlator bionic.
# Expects caller to define: log(), fail(), WCP_TARGET_RUNTIME, WCP_ROOT.

winlator_is_glibc_launcher() {
  local bin_path="$1"
  [[ -f "${bin_path}" ]] || return 1
  readelf -l "${bin_path}" 2>/dev/null | grep -q 'Requesting program interpreter: /lib/ld-linux-aarch64.so.1'
}

winlator_resolve_host_lib() {
  local soname="$1" dir
  for dir in \
    /lib/aarch64-linux-gnu \
    /usr/lib/aarch64-linux-gnu \
    /lib \
    /usr/lib; do
    if [[ -e "${dir}/${soname}" ]]; then
      readlink -f "${dir}/${soname}"
      return 0
    fi
  done
  return 1
}

winlator_collect_needed_sonames() {
  local elf_path="$1"
  readelf -d "${elf_path}" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\].*/\1/p'
}

winlator_copy_glibc_runtime_tree() {
  local src_dir="$1" runtime_dir="$2"
  local loader_target

  [[ -d "${src_dir}" ]] || fail "Pinned glibc runtime dir not found: ${src_dir}"
  mkdir -p "${runtime_dir}"

  # Copy contents as a runtime tree snapshot (files + symlinks), preserving layout.
  cp -a "${src_dir}/." "${runtime_dir}/"

  [[ -e "${runtime_dir}/ld-linux-aarch64.so.1" ]] || fail "Pinned glibc runtime is missing ld-linux-aarch64.so.1"
  loader_target="$(readlink -f "${runtime_dir}/ld-linux-aarch64.so.1" 2>/dev/null || true)"
  [[ -n "${loader_target}" && -e "${loader_target}" ]] || fail "Pinned glibc runtime loader symlink is broken: ${runtime_dir}/ld-linux-aarch64.so.1"
}

winlator_extract_glibc_runtime_archive() {
  local archive="$1" out_dir="$2"
  local runtime_subdir="${3:-}"
  local tmp_extract

  [[ -f "${archive}" ]] || fail "Pinned glibc runtime archive not found: ${archive}"
  command -v tar >/dev/null 2>&1 || fail "tar is required to unpack pinned glibc runtime archive"

  tmp_extract="$(mktemp -d)"
  tar -xf "${archive}" -C "${tmp_extract}"

  if [[ -n "${runtime_subdir}" ]]; then
    [[ -d "${tmp_extract}/${runtime_subdir}" ]] || fail "Pinned glibc archive missing runtime subdir: ${runtime_subdir}"
    winlator_copy_glibc_runtime_tree "${tmp_extract}/${runtime_subdir}" "${out_dir}"
  elif [[ -d "${tmp_extract}/wcp-glibc-runtime" ]]; then
    winlator_copy_glibc_runtime_tree "${tmp_extract}/wcp-glibc-runtime" "${out_dir}"
  else
    # Fallback: archive root already contains ld-linux + libs.
    winlator_copy_glibc_runtime_tree "${tmp_extract}" "${out_dir}"
  fi

  rm -rf "${tmp_extract}"
}

winlator_apply_glibc_runtime_patchset() {
  local runtime_dir="$1"
  local overlay_dir="${WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR:-}"
  local patch_script="${WCP_GLIBC_RUNTIME_PATCH_SCRIPT:-}"
  local patchset_id="${WCP_GLIBC_PATCHSET_ID:-}"

  [[ -d "${runtime_dir}" ]] || fail "glibc runtime dir not found for patchset apply: ${runtime_dir}"

  if [[ -n "${overlay_dir}" ]]; then
    [[ -d "${overlay_dir}" ]] || fail "WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR not found: ${overlay_dir}"
    cp -a "${overlay_dir}/." "${runtime_dir}/"
    log "Applied glibc runtime overlay patchset (${patchset_id:-overlay-only}) from ${overlay_dir}"
  fi

  if [[ -n "${patch_script}" ]]; then
    [[ -x "${patch_script}" ]] || fail "WCP_GLIBC_RUNTIME_PATCH_SCRIPT is not executable: ${patch_script}"
    "${patch_script}" "${runtime_dir}"
    log "Applied glibc runtime patch script (${patchset_id:-script-only}) via ${patch_script}"
  fi

  [[ -e "${runtime_dir}/ld-linux-aarch64.so.1" ]] || fail "glibc runtime patchset removed loader symlink"
  local loader_target
  loader_target="$(readlink -f "${runtime_dir}/ld-linux-aarch64.so.1" 2>/dev/null || true)"
  [[ -n "${loader_target}" && -e "${loader_target}" ]] || fail "glibc runtime patchset left broken loader symlink"
}

winlator_bundle_glibc_runtime_from_pinned_source() {
  local runtime_dir="$1"
  local source_dir="${WCP_GLIBC_RUNTIME_DIR:-}"
  local source_archive="${WCP_GLIBC_RUNTIME_ARCHIVE:-}"
  local archive_subdir="${WCP_GLIBC_RUNTIME_SUBDIR:-}"
  local build_script="${ROOT_DIR:-}/ci/runtime-bundle/build-glibc-runtime-from-source.sh"
  local cache_root="${WCP_GLIBC_BUILD_CACHE_DIR:-${CACHE_DIR:-/tmp}/wcp-glibc-runtime-cache}"
  local cached_runtime_dir="${cache_root}/runtime-${WCP_GLIBC_VERSION:-unknown}-${WCP_GLIBC_TARGET_VERSION:-target}"
  local -a build_args=()

  case "${WCP_GLIBC_SOURCE_MODE:-host}" in
    pinned-source|pinned|prebuilt) ;;
    *) fail "winlator_bundle_glibc_runtime_from_pinned_source called with unsupported WCP_GLIBC_SOURCE_MODE=${WCP_GLIBC_SOURCE_MODE:-}" ;;
  esac

  if [[ -n "${source_dir}" ]]; then
    winlator_copy_glibc_runtime_tree "${source_dir}" "${runtime_dir}"
    return 0
  fi

  if [[ -n "${source_archive}" ]]; then
    winlator_extract_glibc_runtime_archive "${source_archive}" "${runtime_dir}" "${archive_subdir}"
    return 0
  fi

  if [[ -x "${build_script}" && -n "${WCP_GLIBC_SOURCE_URL:-}" ]]; then
    mkdir -p "${cache_root}"
    if [[ ! -f "${cached_runtime_dir}/ld-linux-aarch64.so.1" ]]; then
      build_args=(
        --out-dir "${cached_runtime_dir}"
        --src-url "${WCP_GLIBC_SOURCE_URL}"
        --version "${WCP_GLIBC_VERSION:-${WCP_GLIBC_TARGET_VERSION:-unknown}}"
        --cache-dir "${cache_root}"
        --enable-kernel "${WCP_GLIBC_ENABLE_KERNEL:-4.14}"
        --jobs "${WCP_GLIBC_BUILD_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
      )
      if [[ -n "${WCP_GLIBC_SOURCE_SHA256:-}" ]]; then
        build_args+=(--src-sha256 "${WCP_GLIBC_SOURCE_SHA256}")
      fi
      "${build_script}" "${build_args[@]}"
    fi
    winlator_copy_glibc_runtime_tree "${cached_runtime_dir}" "${runtime_dir}"
    return 0
  fi

  fail "Pinned glibc mode requires WCP_GLIBC_RUNTIME_DIR or WCP_GLIBC_RUNTIME_ARCHIVE"
}

winlator_bundle_glibc_runtime() {
  local runtime_dir="$1"
  local -a seed_sonames=()
  local extra_sonames
  local -a elf_roots=()
  local root f dep host_path real_name loader_name
  local -a queue=()
  declare -A seen=()
  local glibc_mode="${WCP_GLIBC_SOURCE_MODE:-host}"

  if [[ "${glibc_mode}" != "host" ]]; then
    winlator_bundle_glibc_runtime_from_pinned_source "${runtime_dir}"
    winlator_apply_glibc_runtime_patchset "${runtime_dir}"
    log "Winlator glibc runtime bundled from pinned source mode (${glibc_mode})"
    return 0
  fi

  elf_roots=(
    "${WCP_ROOT}/bin"
    "${WCP_ROOT}/lib/wine/aarch64-unix"
  )

  mkdir -p "${runtime_dir}"

  # Seed list from all packaged ELF binaries/modules plus core glibc sonames.
  for root in "${elf_roots[@]}"; do
    [[ -d "${root}" ]] || continue
    while IFS= read -r -d '' f; do
      if file -b "${f}" | grep -q '^ELF '; then
        while IFS= read -r dep; do
          [[ -n "${dep}" ]] && seed_sonames+=("${dep}")
        done < <(winlator_collect_needed_sonames "${f}")
      fi
    done < <(find "${root}" -type f -print0)
  done

  seed_sonames+=(
    "libc.so.6"
    "libdl.so.2"
    "libm.so.6"
    "libpthread.so.0"
    "librt.so.1"
    "libgcc_s.so.1"
    "libstdc++.so.6"
    "libz.so.1"
  )

  # Runtime-only symbols frequently requested via dlopen() on glibc builds.
  : "${WCP_BIONIC_EXTRA_GLIBC_LIBS:=libnss_files.so.2 libnss_dns.so.2 libresolv.so.2 libutil.so.1 libnsl.so.1 libSDL2-2.0.so.0 libSDL2-2.0.so}"
  extra_sonames="$(printf '%s' "${WCP_BIONIC_EXTRA_GLIBC_LIBS}" | tr ',' ' ')"
  for dep in ${extra_sonames}; do
    seed_sonames+=("${dep}")
  done

  # Copy ELF interpreter used by glibc Wine launchers.
  host_path="$(winlator_resolve_host_lib ld-linux-aarch64.so.1 || true)"
  if [[ -z "${host_path}" ]]; then
    fail "Unable to resolve host ld-linux-aarch64.so.1 required for glibc launcher wrapping"
  fi
  loader_name="$(basename "${host_path}")"
  cp -a "${host_path}" "${runtime_dir}/${loader_name}"
  if [[ "${loader_name}" != "ld-linux-aarch64.so.1" ]]; then
    ln -sfn "${loader_name}" "${runtime_dir}/ld-linux-aarch64.so.1"
  fi

  # Breadth-first copy of transitive shared-library dependencies.
  queue=("${seed_sonames[@]}")
  while ((${#queue[@]})); do
    dep="${queue[0]}"
    queue=("${queue[@]:1}")
    [[ -n "${dep}" ]] || continue
    [[ -n "${seen["${dep}"]:-}" ]] && continue
    seen["${dep}"]=1

    # Package-provided Wine unix modules are resolved via wrapper library path.
    if [[ -e "${WCP_ROOT}/lib/wine/aarch64-unix/${dep}" || -e "${WCP_ROOT}/lib/${dep}" ]]; then
      continue
    fi

    host_path="$(winlator_resolve_host_lib "${dep}" || true)"
    if [[ -z "${host_path}" ]]; then
      log "winlator runtime: unresolved host soname ${dep}, keeping external resolution"
      continue
    fi

    real_name="$(basename "${host_path}")"
    cp -an "${host_path}" "${runtime_dir}/${real_name}" || true
    if [[ "${real_name}" != "${dep}" ]]; then
      ln -sfn "${real_name}" "${runtime_dir}/${dep}"
    fi

    while IFS= read -r dep; do
      [[ -n "${dep}" ]] && queue+=("${dep}")
    done < <(winlator_collect_needed_sonames "${host_path}")
  done

  winlator_apply_glibc_runtime_patchset "${runtime_dir}"
}

winlator_write_glibc_wrapper() {
  local launcher_path="$1" real_name="$2" export_wineserver="$3"

  cat > "${launcher_path}" <<EOF_WRAPPER
#!/system/bin/sh
set -eu

self="\$0"
# Some Android launch paths arrive with nested quotes (e.g. ""/path/bin/wine").
while :; do
  case "\${self}" in
    \\"*) self="\${self#\\"}"; continue ;;
    \\'*) self="\${self#\\'}"; continue ;;
    \\\\\\"*) self="\${self#\\\\\\"}"; continue ;;
    *) ;;
  esac
  break
done
while :; do
  case "\${self}" in
    *\\\\\\") self="\${self%\\\\\\"}"; continue ;;
    *\\") self="\${self%\\"}"; continue ;;
    *\\') self="\${self%\\'}"; continue ;;
    *) ;;
  esac
  break
done
bindir="\$(CDPATH= cd -- "\$(dirname -- "\${self}")" 2>/dev/null && pwd)" || {
  echo "Cannot resolve launcher directory from argv0: \$0" >&2
  exit 127
}
root="\$(CDPATH= cd -- "\${bindir}/.." && pwd)"
runtime="\${root}/lib/wine/wcp-glibc-runtime"
loader="\${runtime}/ld-linux-aarch64.so.1"
real="\${bindir}/${real_name}"
libpath="\${runtime}:\${runtime}/deps:\${root}/lib:\${root}/lib64:\${root}/lib/aarch64-linux-gnu:\${root}/lib/wine:\${root}/lib/wine/aarch64-unix:\${root}/lib/wine/x86_64-unix:\${root}/usr/lib:\${root}/usr/lib64:\${root}/usr/lib/aarch64-linux-gnu"
winedllpath="\${root}/lib/wine/aarch64-windows:\${root}/lib/wine/i386-windows:\${root}/lib/wine/x86_64-windows:\${root}/lib/wine/aarch64-unix:\${root}/lib/wine/x86_64-unix"
export PATH="\${bindir}:\${root}/bin:\${PATH}"
export WINEDLLPATH="\${winedllpath}\${WINEDLLPATH:+:\${WINEDLLPATH}}"
export LD_LIBRARY_PATH="\${libpath}\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
# Winlator injects Android sysvshm as a bionic LD_PRELOAD. This breaks glibc-wrapped Wine/Hangover
# launchers (missing libdl.so/ld-android.so or early traps), so glibc wrappers must clear it.
unset LD_PRELOAD
# Android app seccomp often blocks glibc rseq and causes SIGSYS (signal 31) very early.
case ":\${GLIBC_TUNABLES:-}:" in
  *:glibc.pthread.rseq=*:) ;;
  *) export GLIBC_TUNABLES="\${GLIBC_TUNABLES:+\${GLIBC_TUNABLES}:}glibc.pthread.rseq=0" ;;
esac

[ -x "\${loader}" ] || { echo "Missing runtime loader: \${loader}" >&2; exit 127; }
[ -x "\${real}" ] || { echo "Missing launcher payload: \${real}" >&2; exit 127; }
EOF_WRAPPER

  if [[ "${export_wineserver}" == "1" ]]; then
    cat >> "${launcher_path}" <<'EOF_WRAPPER'
export WINESERVER="${bindir}/wineserver"
EOF_WRAPPER
  fi

  cat >> "${launcher_path}" <<'EOF_WRAPPER'
exec "${loader}" --library-path "${LD_LIBRARY_PATH}" "${real}" "$@"
EOF_WRAPPER

  chmod +x "${launcher_path}"
}

winlator_wrap_glibc_launchers() {
  local wine_bin wineserver_bin runtime_dir
  local wine_real wineserver_real

  [[ "${WCP_TARGET_RUNTIME}" == "winlator-bionic" ]] || return

  wine_bin="${WCP_ROOT}/bin/wine"
  wineserver_bin="${WCP_ROOT}/bin/wineserver"
  [[ -f "${wine_bin}" ]] || return
  [[ -f "${wineserver_bin}" ]] || return

  if ! winlator_is_glibc_launcher "${wine_bin}"; then
    return
  fi

  runtime_dir="${WCP_ROOT}/lib/wine/wcp-glibc-runtime"
  winlator_bundle_glibc_runtime "${runtime_dir}"

  wine_real="wine.glibc-real"
  wineserver_real="wineserver.glibc-real"
  mv -f "${wine_bin}" "${WCP_ROOT}/bin/${wine_real}"
  mv -f "${wineserver_bin}" "${WCP_ROOT}/bin/${wineserver_real}"

  winlator_write_glibc_wrapper "${wine_bin}" "${wine_real}" "1"
  winlator_write_glibc_wrapper "${wineserver_bin}" "${wineserver_real}" "0"
  log "Winlator bionic wrapper enabled for glibc Wine launchers"
}

winlator_validate_launchers() {
  local wine_bin wineserver_bin

  [[ "${WCP_TARGET_RUNTIME}" == "winlator-bionic" ]] || return

  wine_bin="${WCP_ROOT}/bin/wine"
  wineserver_bin="${WCP_ROOT}/bin/wineserver"
  [[ -e "${wine_bin}" ]] || fail "Missing bin/wine"
  [[ -e "${wineserver_bin}" ]] || fail "Missing bin/wineserver"

  if winlator_is_glibc_launcher "${wine_bin}"; then
    fail "bin/wine is a raw glibc launcher for /lib/ld-linux-aarch64.so.1; Winlator bionic cannot execute it directly"
  fi

  if [[ -f "${WCP_ROOT}/bin/wine.glibc-real" ]]; then
    local shebang
    shebang="$(head -n1 "${wine_bin}" || true)"
    [[ "${shebang}" == "#!/system/bin/sh" ]] || fail "bin/wine wrapper must use #!/system/bin/sh for Android execution"
    [[ -x "${WCP_ROOT}/lib/wine/wcp-glibc-runtime/ld-linux-aarch64.so.1" ]] || fail "Missing wrapped runtime loader: lib/wine/wcp-glibc-runtime/ld-linux-aarch64.so.1"
    grep -Fq 'unset LD_PRELOAD' "${wine_bin}" || fail "bin/wine glibc wrapper must clear LD_PRELOAD for Android bionic preload compatibility"
    grep -Fq 'glibc.pthread.rseq=0' "${wine_bin}" || fail "bin/wine glibc wrapper must disable glibc rseq on Android"
    grep -Fq 'unset LD_PRELOAD' "${wineserver_bin}" || fail "bin/wineserver glibc wrapper must clear LD_PRELOAD for Android bionic preload compatibility"
    grep -Fq 'glibc.pthread.rseq=0' "${wineserver_bin}" || fail "bin/wineserver glibc wrapper must disable glibc rseq on Android"
  fi
}
