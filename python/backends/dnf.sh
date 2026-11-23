# shellcheck shell=bash
# dnf backend (Fedora): the side-by-side python3.Y packages plus the system
# python3, newest patch only. Each provides /usr/bin/python3.Y.

backend_available() { command -v dnf >/dev/null 2>&1; }
backend_granularity() { echo minor; }

_dnf_system_minor() {
  dnf -q repoquery --qf '%{version}\n' python3 | awk '!/~/' | version_sort | tail -n 1 | cut -d. -f1-2
}

# Prereleases (3.16.0~a2) share the python3.Y names, so versions with a ~ are dropped.
backend_versions() {
  {
    dnf -q repoquery --qf '%{name} %{version}\n' 'python3.[0-9]*' |
      awk '$1 ~ /^python3\.[0-9]+$/ && $2 !~ /~/ { sub(/^python/, "", $1); print $1 }'
    _dnf_system_minor
  } | sort -u
}

backend_install() {
  local minor pkg
  minor="$(version_minor "$1")"
  need_minor "$minor" "$UV_HINT"
  pkg="python$minor"
  [ "$minor" != "$(_dnf_system_minor)" ] || pkg=python3
  run_privileged dnf install -y "$pkg"
}

backend_exec() {
  local bin
  bin="python$(version_minor "$1")"
  shift
  exec_bin "$bin" "$@"
}
