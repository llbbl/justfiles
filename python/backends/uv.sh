# shellcheck shell=bash
# uv backend: uv's managed CPython builds, macOS and Linux, no root. Exact patch
# pins; an X.Y pin installs and runs that minor's newest patch.

backend_available() { command -v uv >/dev/null 2>&1; }
backend_granularity() { echo patch; }

# Lines look like `cpython-3.13.1-linux-x86_64-gnu`; the pattern drops
# +freethreaded builds, prereleases, PyPy and GraalPy.
backend_versions() {
  uv python list --all-versions --only-downloads | sed -n 's/^cpython-\([0-9]*\.[0-9]*\.[0-9]*\)-.*/\1/p'
}

backend_install() { uv python install "$1"; }

# only-managed: uv's own installs, never a system python of the same version.
backend_exec() {
  local pin="$1" bin
  shift
  bin="$(uv python find --python-preference only-managed "$pin")" || die "python $pin is not installed: run  just python setup"
  "$bin" "$@"
}
