# shellcheck shell=bash
# pacman backend (Arch): the one python Arch ships, newest patch only.

backend_available() { command -v pacman >/dev/null 2>&1; }
backend_granularity() { echo minor; }

# pacman translates -Si field labels.
backend_versions() {
  LC_ALL=C pacman -Si python | awk '/^Version/ { split($3, v, "."); print v[1] "." v[2] }'
}

backend_install() {
  need_minor "$(version_minor "$1")" "$UV_HINT"
  run_privileged pacman -S --needed --noconfirm python
}

backend_exec() {
  local bin
  bin="python$(version_minor "$1")"
  shift
  exec_bin "$bin" "$@"
}
