# shellcheck shell=bash
# mise backend: precompiled CPython (python-build-standalone) on macOS and glibc
# Linux; on musl mise compiles from source.
# Exact patch pins; an X.Y pin installs and runs that minor's newest patch.

backend_available() { command -v mise >/dev/null 2>&1; }
backend_granularity() { echo patch; }
backend_versions() { mise ls-remote python | stable_versions; }
backend_install() { mise install "python@$1"; }

# Runs the installed binary directly: `mise exec` would auto-install. `mise where`
# resolves an X.Y pin to the newest installed patch, not the newest released one.
backend_exec() {
  local pin="$1" dir
  shift
  dir="$(mise where "python@$pin")" || die "python $pin is not installed: run  just python setup"
  "$dir/bin/python3" "$@"
}
