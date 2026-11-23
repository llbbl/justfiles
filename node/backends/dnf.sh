# shellcheck shell=bash
# dnf backend (Fedora): the default nodejs plus side-by-side nodejsN packages,
# newest release only. Each provides /usr/bin/node-N, with npm in <package>-npm.

backend_available() { command -v dnf >/dev/null 2>&1; }
backend_granularity() { echo major; }

# "package major" for each installable node.
_dnf_nodes() {
  dnf -q repoquery --qf '%{name} %{version}\n' nodejs 'nodejs[0-9]*' |
    awk '$1 ~ /^nodejs[0-9]*$/ && $2 !~ /~/ { split($2, v, "."); print $1, v[1] }' | sort -u
}

backend_versions() { _dnf_nodes | cut -d' ' -f2 | sort -u; }

backend_install() {
  local major pkg
  major="$(version_major "$1")"
  need_minor "$major"
  pkg="$(awk -v m="$major" '$2 == m { print $1; exit }' <<<"$(_dnf_nodes)")"
  run_privileged dnf install -y "$pkg" "$pkg-npm"
}

backend_exec() {
  local bin
  bin="node-$(version_major "$1")"
  shift
  exec_bin "$bin" "$@"
}
