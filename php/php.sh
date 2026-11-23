#!/usr/bin/env bash
# php module entrypoint: php.sh <command> [args]. Needs PROJECT_DIR.
set -euo pipefail

PHP_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$PHP_MODULE_DIR/../lib/common.sh"
# shellcheck source=lib/pin.sh
. "$PHP_MODULE_DIR/../lib/pin.sh"
# shellcheck source=lib/backend.sh
. "$PHP_MODULE_DIR/../lib/backend.sh"

PIN_FILE=.php-version
BACKEND_ORDER=(mise)
STABLE_RE='^[0-9]+\.[0-9]+\.[0-9]+$'
EOL_URL="https://endoflife.date/api/php.json"

use_backend() {
  backend_select "$PHP_MODULE_DIR" PHP_BACKEND "${BACKEND_ORDER[@]}"
}

list_versions() {
  backend_versions || die "could not list php versions via $BACKEND"
}

# latest_in_minor VERSIONS PIN: newest of VERSIONS in PIN's minor line.
latest_in_minor() {
  local minor
  minor="$(version_minor "$2")"
  { grep -E "^${minor//./\\.}\." <<<"$1" || true; } | version_sort | tail -n 1
}

cmd_backend() {
  use_backend
  log "$BACKEND ($BACKEND_REASON)"
}

cmd_check() {
  local pin installed
  pin="$(pin_get php "$PIN_FILE")"
  log "pin ($PIN_FILE):  $pin"
  if mise_pin php; then log "$MISE_PIN_FILE:      $MISE_PIN ✓"; fi
  use_backend
  log "backend:            $BACKEND"
  installed="$(backend_exec "$pin" -r 'echo PHP_VERSION;')"
  if version_matches "$installed" "$pin"; then
    log "installed:          $installed ✓"
  else
    die "installed php $installed does not match pin $pin: run  just php setup"
  fi
}

cmd_setup() {
  local pin mods
  pin="$(pin_get php "$PIN_FILE")"
  use_backend
  log "── installing php $pin with $BACKEND ──"
  backend_install "$pin"
  log "── verifying build ──"
  backend_exec "$pin" -v
  # Here-string, not a pipe: `php -m | grep -q` lets grep exit early, php gets
  # SIGPIPE and pipefail reports a false failure.
  mods="$(backend_exec "$pin" -m)"
  if grep -iqx 'openssl' <<<"$mods"; then
    log "✓ openssl extension present"
  else
    die "openssl extension MISSING: the build did not link openssl"
  fi
}

cmd_version() {
  local pin
  pin="$(pin_get php "$PIN_FILE")"
  use_backend
  backend_exec "$pin" --version
}

cmd_latest() {
  local pin minor versions line all
  pin="$(pin_get php "$PIN_FILE")"
  use_backend
  minor="$(version_minor "$pin")"
  versions="$(list_versions)"
  line="$(latest_in_minor "$versions" "$pin")"
  all="$(version_sort <<<"$versions" | tail -n 1)"
  [ -n "$line" ] || die "no stable $minor.x versions found via $BACKEND"
  printf 'pinned (%s):  %s\n' "$PIN_FILE" "$pin"
  printf 'latest stable %s.x:     %s\n' "$minor" "$line"
  printf 'latest stable overall:  %s\n' "$all"
  if [ "$pin" = "$line" ]; then
    printf '\n✓ pin is the latest %s.x stable\n' "$minor"
  else
    printf '\n→ newer %s.x stable: %s, run: just php bump\n' "$minor" "$line"
  fi
}

# bump [VERSION]: pin VERSION, or the newest patch in the current minor line.
# An explicit VERSION repairs a pin mismatch by writing both files; without one
# there is no way to know which file is right, so the mismatch still stops it.
cmd_bump() {
  local target="${1:-}" pin="" versions=""
  use_backend
  if [ -n "$target" ]; then
    pin="$(pin_read "$PIN_FILE" || true)"
  elif pin_read "$PIN_FILE" >/dev/null; then
    pin="$(pin_get php "$PIN_FILE")"
  fi
  if [ -z "$target" ]; then
    [ -n "$pin" ] || die "no $PIN_FILE yet: run  just php bump <version>"
    versions="$(list_versions)"
    target="$(latest_in_minor "$versions" "$pin")"
    [ -n "$target" ] || die "no stable $(version_minor "$pin").x versions found via $BACKEND"
  fi
  target="${target#v}"
  # [[ =~ ]], not grep: grep checks each line of a multi-line value separately.
  [[ $target =~ $STABLE_RE ]] ||
    die "refusing to pin '$target': not a stable X.Y.Z version"
  [ -n "$versions" ] || versions="$(list_versions)"
  grep -Fxq -- "$target" <<<"$versions" ||
    die "version $target is not available via $BACKEND"
  if [ "$target" = "$pin" ] && { ! mise_pin php || [ "$MISE_PIN" = "$target" ]; }; then
    log "✓ already pinned to $pin"
    return 0
  fi
  pin_write php "$PIN_FILE" "$target"
  log "$PIN_FILE: php ${pin:-(none)} → $target"
  log "next: just php setup"
}

# Oldest branch still in php.net *active* support within the pinned major.
cmd_floor() {
  local pin major row minor sup patch
  require_cmd jq "brew install jq / apt install jq"
  pin="$(pin_get php "$PIN_FILE")"
  major="$(version_major "$pin")"
  row="$(http_get "$EOL_URL" | jq -r --arg today "$(date +%F)" --arg major "$major" '
    map(select((.support | type == "string") and (.support > $today)))
    | map(select(.cycle | startswith($major + ".")))
    | sort_by(.cycle | split(".") | map(tonumber))
    | (.[0] // empty) | "\(.cycle)\t\(.support)\t\(.latest)"')"
  [ -n "$row" ] || die "could not find an actively supported $major.x branch"
  IFS=$'\t' read -r minor sup patch <<<"$row"
  printf 'current pin:                 %s\n' "$pin"
  printf 'oldest active-support %s.x:   %s   (active support until %s)\n' "$major" "$minor" "$sup"
  printf 'latest stable patch:         %s\n' "$patch"
  printf '\napply (active-support floor): just php bump %s\n' "$patch"
}

main() {
  [ -n "${PROJECT_DIR:-}" ] || die "PROJECT_DIR is not set (run via just php ...)"
  cd "$PROJECT_DIR"
  local cmd="${1:-}"
  [ $# -gt 0 ] && shift
  case "$cmd" in
    backend | check | setup | version | latest | bump | floor) "cmd_$cmd" "$@" ;;
    *) die "usage: php.sh {setup|check|version|latest|bump [VERSION]|floor|backend}" ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
