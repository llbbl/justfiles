# shellcheck shell=bash
# pacman backend (Arch): nodejs (current) or one nodejs-lts-<codename> package;
# they conflict, so one major at a time, newest release only. npm is separate.

backend_available() { command -v pacman >/dev/null 2>&1; }
backend_granularity() { echo major; }

# "package major" for each installable node. pacman translates -Si field labels.
_pacman_nodes() {
  local pkgs
  pkgs="$(pacman -Ssq '^nodejs(-lts-[a-z]+)?$' || true)"
  [ -n "$pkgs" ] || return 0
  # shellcheck disable=SC2086 # one package name per word
  LC_ALL=C pacman -Si $pkgs | awk '/^Name/ { n = $3 } /^Version/ { split($3, v, "."); print n, v[1] }'
}

backend_versions() { _pacman_nodes | cut -d' ' -f2 | sort -u; }

backend_install() {
  local major pkg
  major="$(version_major "$1")"
  need_minor "$major"
  pkg="$(awk -v m="$major" '$2 == m { print $1; exit }' <<<"$(_pacman_nodes)")"
  # --ask 4 answers yes to removing the conflicting node package; --noconfirm alone answers no.
  run_privileged pacman -S --needed --noconfirm --ask 4 "$pkg" npm
}

backend_exec() {
  shift
  exec_bin node "$@"
}
