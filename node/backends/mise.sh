# shellcheck shell=bash
# mise backend: official Node.js builds on macOS and Linux. Exact pins; a bare
# major installs and runs that major's newest release.

backend_available() { command -v mise >/dev/null 2>&1; }
backend_granularity() { echo patch; }
backend_versions() { mise ls-remote node | stable_versions; }
backend_install() { mise install "node@$1"; }

# Runs the installed binary directly: `mise exec` would auto-install.
backend_exec() {
  local pin="$1" dir
  shift
  dir="$(mise where "node@$pin")" || die "node $pin is not installed: run  just node setup"
  "$dir/bin/node" "$@"
}
