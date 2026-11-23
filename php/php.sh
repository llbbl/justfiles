#!/usr/bin/env bash
# php module entrypoint: php.sh <command> [args]. Needs PROJECT_DIR.
set -euo pipefail

TOOL=php
PIN_FILE=.php-version
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_ORDER_MACOS=(mise brew)
BACKEND_ORDER_LINUX=(brew apt dnf pacman apk)
EOL_URL="https://endoflife.date/api/php.json"
FLOOR_FIELD=support
TOOL_VERSION_ARGS=(-r 'echo PHP_VERSION;')
PATH_TOOL=php
PATH_TOOL_USERS="composer, IDEs"

# shellcheck source=lib/commands.sh
. "$MODULE_DIR/../lib/commands.sh"

# Packages every distro backend installs, prefixed by the backend: the set the
# mise build ships. opcache is built into PHP from 8.5, so it has no package.
php_packages() {
  case "$1" in
    [0-7].* | 8.[0-4]) echo cli common curl mbstring xml zip intl gd opcache ;;
    *) echo cli common curl mbstring xml zip intl gd ;;
  esac
}

# Here-string, not a pipe: `php -m | grep -q` lets grep exit early, php gets
# SIGPIPE and pipefail reports a false failure.
verify_install() {
  local mods
  mods="$(backend_exec "$1" -m)"
  if grep -iqx 'openssl' <<<"$mods"; then
    log "✓ openssl extension present"
  else
    die "openssl extension MISSING: the build did not link openssl"
  fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
