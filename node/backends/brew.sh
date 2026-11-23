# shellcheck shell=bash
# Homebrew backend: node@N formulae (core aliases the current node that way),
# newest release only. Never via sudo: Homebrew refuses to run as root.

backend_available() { command -v brew >/dev/null 2>&1; }
backend_granularity() { echo major; }

backend_versions() {
  brew search --formula '/^node@[0-9]+$/' | sed -n 's|^.*node@\([0-9]*\)$|\1|p' | sort -u
}

backend_install() {
  local major
  major="$(version_major "$1")"
  need_minor "$major"
  brew install "node@$major"
}

backend_exec() {
  local formula prefix
  formula="node@$(version_major "$1")"
  shift
  prefix="$(brew --prefix "$formula" || true)"
  if [ -z "$prefix" ] || [ ! -x "$prefix/bin/node" ]; then
    die "$formula is not installed: run  just node setup"
  fi
  "$prefix/bin/node" "$@"
}
