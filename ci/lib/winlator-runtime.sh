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

winlator_bundle_glibc_runtime() {
  local runtime_dir="$1"
  local -a seed_sonames=()
  local extra_sonames
  local -a elf_roots=(
    "${WCP_ROOT}/bin"
    "${WCP_ROOT}/lib/wine/aarch64-unix"
  )
  local root f dep host_path real_name loader_name
  local -a queue=()
  declare -A seen=()

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
  fi
}
