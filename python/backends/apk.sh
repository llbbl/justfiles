# shellcheck shell=bash
# apk backend (Alpine): the one python3 each release ships, newest patch only;
# sqlite3 and venv are in the main package. --no-cache fetches the index.

backend_available() { command -v apk >/dev/null 2>&1; }
backend_granularity() { echo minor; }

backend_versions() {
  apk --no-cache search -x python3 | sed -n 's/^python3-\([0-9]*\.[0-9]*\)\..*/\1/p'
}

backend_install() {
  need_minor "$(version_minor "$1")" "$UV_HINT"
  run_privileged apk --no-cache add python3
}

backend_exec() {
  local bin
  bin="python$(version_minor "$1")"
  shift
  exec_bin "$bin" "$@"
}
