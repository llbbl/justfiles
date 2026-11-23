# shellcheck shell=bash
# fnm backend: exact pins; a bare major means its newest release.

backend_available() { command -v fnm >/dev/null 2>&1; }
backend_granularity() { echo patch; }

# Lines look like `v22.11.0 (Jod)`.
backend_versions() { fnm list-remote | awk '{ sub(/^v/, "", $1); print $1 }' | stable_versions; }

backend_install() { fnm install "$1"; }

# Resolves the binary once, so a missing version isn't mistaken for node failing.
backend_exec() {
  local pin="$1" bin
  shift
  bin="$(fnm exec --using="$pin" node -p process.execPath 2>/dev/null)" ||
    die "node $pin is not installed: run  just node setup"
  "$bin" "$@"
}
