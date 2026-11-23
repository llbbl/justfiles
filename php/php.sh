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
STABLE_RE='^[0-9]+\.[0-9]+\.[0-9]+$'
MINOR_OR_PATCH_RE='^[0-9]+\.[0-9]+(\.[0-9]+)?$'
EOL_URL="https://endoflife.date/api/php.json"

use_backend() {
  local os
  os="$(detect_os)"
  if [ "$os" = macos ]; then
    backend_select "$PHP_MODULE_DIR" PHP_BACKEND mise brew
  else
    backend_select "$PHP_MODULE_DIR" PHP_BACKEND brew apt dnf pacman apk
  fi
  GRANULARITY="$(backend_granularity)"
}

list_versions() {
  backend_versions || die "could not list php versions via $BACKEND"
}

# Packages every distro backend installs, prefixed by the backend: the set the
# mise build ships. opcache is built into PHP from 8.5, so it has no package.
php_packages() {
  case "$1" in
    [0-7].* | 8.[0-4]) echo cli common curl mbstring xml zip intl gd opcache ;;
    *) echo cli common curl mbstring xml zip intl gd ;;
  esac
}

# need_minor MINOR [HINT]: dies, naming what the backend has, unless it can install MINOR.
need_minor() {
  local have
  have="$(list_versions)"
  grep -Fxq -- "$1" <<<"$have" && return 0
  have="$(version_sort <<<"$have" | tr '\n' ' ')"
  die "php $1 is not available via $BACKEND (have: ${have% })${2:+; $2}"
}

# Runs php binary BIN from PATH, as the distro packages name it (php8.5, php85).
exec_bin() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is not installed: run  just php setup"
  "$@"
}

# The pin a minor-granularity backend actually honors.
effective_pin() {
  if [ "$GRANULARITY" = minor ]; then version_minor "$1"; else echo "$1"; fi
}

warn_patch_pin() {
  if [ "$(effective_pin "$1")" != "$1" ] && [ "$1" != "$2" ]; then
    warn "$BACKEND can't pin patches; installed $2 for pin $1"
  fi
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
  local pin installed onpath
  pin="$(pin_get php "$PIN_FILE")"
  log "pin ($PIN_FILE):  $pin"
  if mise_pin php; then log "$MISE_PIN_FILE:      $MISE_PIN ✓"; fi
  use_backend
  log "backend:            $BACKEND"
  installed="$(backend_exec "$pin" -r 'echo PHP_VERSION;')"
  if version_matches "$installed" "$(effective_pin "$pin")"; then
    warn_patch_pin "$pin" "$installed"
    log "installed:          $installed ✓"
  else
    die "installed php $installed does not match pin $pin: run  just php setup"
  fi
  # Plain `php` may be a mise shim, which would build a missing version.
  onpath="$(MISE_NOT_FOUND_AUTO_INSTALL=false php -r 'echo PHP_VERSION;' 2>/dev/null || true)"
  version_matches "$onpath" "$(effective_pin "$pin")" ||
    warn "php on PATH is ${onpath:-not found}, not $pin: tools that run plain php (composer, IDEs) won't use the pinned one; see docs/php.md"
}

cmd_setup() {
  local pin mods installed
  pin="$(pin_get php "$PIN_FILE")"
  use_backend
  log "── installing php $pin with $BACKEND ──"
  backend_install "$pin"
  log "── verifying build ──"
  backend_exec "$pin" -v
  installed="$(backend_exec "$pin" -r 'echo PHP_VERSION;')"
  warn_patch_pin "$pin" "$installed"
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
  all="$(version_sort <<<"$versions" | tail -n 1)"
  if [ "$GRANULARITY" = minor ]; then
    [ -n "$all" ] || die "no php versions found via $BACKEND"
    printf 'pinned (%s):  %s\n' "$PIN_FILE" "$pin"
    printf 'newest available via %s: %s\n' "$BACKEND" "$all"
    if [ "$minor" = "$all" ]; then
      printf '\n✓ pin is the newest minor %s has\n' "$BACKEND"
    else
      printf '\n→ newer minor: %s, run: just php bump %s\n' "$all" "$all"
    fi
    return 0
  fi
  line="$(latest_in_minor "$versions" "$pin")"
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
# Minor backends take X.Y or X.Y.Z, so one pin can serve a mixed mise/apt team.
cmd_bump() {
  local target="${1:-}" pin="" versions="" re="$STABLE_RE" form="X.Y.Z" want
  use_backend
  if [ -n "$target" ]; then
    pin="$(pin_read "$PIN_FILE" || true)"
  elif pin_read "$PIN_FILE" >/dev/null; then
    pin="$(pin_get php "$PIN_FILE")"
  fi
  if [ -z "$target" ]; then
    [ -n "$pin" ] || die "no $PIN_FILE yet: run  just php bump <version>"
    if [ "$GRANULARITY" = minor ]; then
      log "✓ $BACKEND tracks the newest $(version_minor "$pin").x itself; nothing to bump"
      return 0
    fi
    versions="$(list_versions)"
    target="$(latest_in_minor "$versions" "$pin")"
    [ -n "$target" ] || die "no stable $(version_minor "$pin").x versions found via $BACKEND"
  fi
  target="${target#v}"
  if [ "$GRANULARITY" = minor ]; then re="$MINOR_OR_PATCH_RE" form="X.Y or X.Y.Z"; fi
  # [[ =~ ]], not grep: grep checks each line of a multi-line value separately.
  [[ $target =~ $re ]] ||
    die "refusing to pin '$target': not a stable $form version"
  [ -n "$versions" ] || versions="$(list_versions)"
  want="$(effective_pin "$target")"
  if ! grep -Fxq -- "$want" <<<"$versions"; then
    [ "$GRANULARITY" = minor ] &&
      die "version $want is not available via $BACKEND; if setup hasn't added its repo yet:  echo $target > $PIN_FILE && just php setup"
    die "version $want is not available via $BACKEND"
  fi
  [ "$want" = "$target" ] || warn "$BACKEND can't pin patches; setup installs the newest $want.x"
  if [ "$target" = "$pin" ] && { ! mise_pin php || [ "$MISE_PIN" = "$target" ]; }; then
    log "✓ already pinned to $pin"
    return 0
  fi
  pin_write php "$PIN_FILE" "$target"
  [ "$pin" = "$target" ] || log "$PIN_FILE: php ${pin:-(none)} → $target"
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
