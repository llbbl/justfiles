#!/usr/bin/env bash
# python module entrypoint: python.sh <command> [args]. Needs PROJECT_DIR.
set -euo pipefail

TOOL=python
PIN_FILE=.python-version
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# mise ships precompiled CPython on Linux too, unlike its source-built PHP.
BACKEND_ORDER_MACOS=(mise uv brew)
BACKEND_ORDER_LINUX=(mise uv brew apt dnf pacman apk)
EOL_URL="https://endoflife.date/api/python.json"
FLOOR_FIELD=eol
TOOL_VERSION_ARGS=(-c 'import platform; print(platform.python_version())')
PATH_TOOL=python3
PATH_TOOL_USERS="pip, venvs, IDEs"
# uv writes X.Y to .python-version by default, and mise and uv resolve it to the newest patch.
LINE_PINS=1

# shellcheck source=lib/commands.sh
. "$MODULE_DIR/../lib/commands.sh"

# shellcheck disable=SC2034 # read by the backends, which this sources at runtime
UV_HINT="uv installs any minor without sudo: https://docs.astral.sh/uv/"

validate_pin() {
  [[ $1 =~ $MINOR_OR_PATCH_RE ]] ||
    die "$PIN_FILE pins '$1': only CPython X.Y or X.Y.Z is supported (not PyPy, free-threaded builds like 3.13t, or prereleases)"
}

# ensurepip is what `python -m venv` needs; Debian and Ubuntu split it into pythonX.Y-venv.
verify_install() {
  if backend_exec "$1" -c 'import ssl, sqlite3, venv, ensurepip'; then
    log "✓ ssl, sqlite3, venv and ensurepip present"
  else
    die "python $1 is missing ssl, sqlite3, venv or ensurepip (see the error above)"
  fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
