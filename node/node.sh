#!/usr/bin/env bash
# node module entrypoint: node.sh <command> [args]. Needs PROJECT_DIR.
set -euo pipefail

TOOL=node
PIN_FILE=.nvmrc
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_ORDER_MACOS=(mise nvm fnm brew)
BACKEND_ORDER_LINUX=(mise nvm fnm brew apt dnf pacman apk)
EOL_URL="https://endoflife.date/api/nodejs.json"
FLOOR_FIELD=eol
FLOOR_LTS=1
TOOL_VERSION_ARGS=(-p 'process.versions.node')
PATH_TOOL=node
PATH_TOOL_USERS="npm, pnpm, IDEs"
RELEASE_LINE=major
# mise, nvm and fnm all resolve a bare major to its newest release.
LINE_PINS=1

# shellcheck source=lib/commands.sh
. "$MODULE_DIR/../lib/commands.sh"

validate_pin() {
  [[ $1 =~ $LINE_OR_PATCH_RE ]] ||
    die "$PIN_FILE pins '$1': only a major (22) or an exact version (22.11.0) is supported, not aliases like lts/* or node"
}

# Debian, Arch and Alpine package npm separately; Fedora's side-by-side majors name it npm-N.
verify_install() {
  local js="const p = require('path'), d = p.dirname(process.execPath), m = process.versions.node.split('.')[0];
process.exit(['npm', 'npm-' + m].some((f) => require('fs').existsSync(p.join(d, f))) ? 0 : 1);"
  if backend_exec "$1" -e "$js"; then
    log "✓ npm present"
  else
    die "node $1 has no npm next to it (see docs/node.md)"
  fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
