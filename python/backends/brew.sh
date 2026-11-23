# shellcheck shell=bash
# Homebrew backend: core python@X.Y formulae, newest patch only. Never via sudo:
# Homebrew refuses to run as root.

backend_available() { command -v brew >/dev/null 2>&1; }
backend_granularity() { echo minor; }

backend_versions() {
  brew search --formula '/^python@[0-9]+\.[0-9]+$/' | sed -n 's|^.*python@\([0-9]*\.[0-9]*\)$|\1|p' | sort -u
}

backend_install() {
  local minor
  minor="$(version_minor "$1")"
  need_minor "$minor" "$UV_HINT"
  brew install "python@$minor"
}

backend_exec() {
  local minor prefix
  minor="$(version_minor "$1")"
  shift
  prefix="$(brew --prefix "python@$minor" || true)"
  if [ -z "$prefix" ] || [ ! -x "$prefix/bin/python$minor" ]; then
    die "python@$minor is not installed: run  just python setup"
  fi
  "$prefix/bin/python$minor" "$@"
}
