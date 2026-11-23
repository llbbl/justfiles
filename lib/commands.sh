# shellcheck shell=bash
# The commands every module shares. A module entrypoint sets the contract in
# docs/development.md, sources this file, then calls main "$@".

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$LIB_DIR/common.sh"
# shellcheck source=lib/pin.sh
. "$LIB_DIR/pin.sh"
# shellcheck source=lib/backend.sh
. "$LIB_DIR/backend.sh"

STABLE_RE='^[0-9]+\.[0-9]+\.[0-9]+$'
MINOR_OR_PATCH_RE='^[0-9]+\.[0-9]+(\.[0-9]+)?$'

# The project's pin, checked against mise; every command reads it here except bump's repair path.
module_pin() {
  local pin
  # `|| return`: callers run this in $(...), where errexit does not apply.
  pin="$(pin_get "${TOOL:?}" "$PIN_FILE")" || return
  if declare -F validate_pin >/dev/null; then validate_pin "$pin"; fi
  printf '%s\n' "$pin"
}

use_backend() {
  local var
  var="$(printf '%s' "$TOOL" | LC_ALL=C tr '[:lower:]' '[:upper:]')_BACKEND"
  if [ "$(detect_os)" = macos ]; then
    backend_select "$MODULE_DIR" "$var" "${BACKEND_ORDER_MACOS[@]}"
  else
    backend_select "$MODULE_DIR" "$var" "${BACKEND_ORDER_LINUX[@]}"
  fi
  GRANULARITY="$(backend_granularity)"
}

list_versions() {
  backend_versions || die "could not list $TOOL versions via $BACKEND"
}

# need_minor MINOR [HINT]: dies, naming what the backend has, unless it can install MINOR.
need_minor() {
  local have
  have="$(list_versions)"
  grep -Fxq -- "$1" <<<"$have" && return 0
  have="$(version_sort <<<"$have" | tr '\n' ' ')"
  die "$TOOL $1 is not available via $BACKEND (have: ${have% })${2:+; $2}"
}

# Runs binary BIN from PATH, as the distro packages name it (php8.5, php85).
exec_bin() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is not installed: run  just $TOOL setup"
  "$@"
}

# The release line VERSION belongs to: 8.5 for php 8.5.7, 22 for node 22.11.0.
line_of() { printf '%s\n' "$1" | cut -d. -f"1-$LINE_FIELDS"; }

# The part of a pin a minor- or major-granularity backend actually honors.
effective_pin() {
  case "$GRANULARITY" in
    minor) version_minor "$1" ;;
    major) version_major "$1" ;;
    *) echo "$1" ;;
  esac
}

# What a coarse backend can't pin, for warnings.
unpinnable() { if [ "$GRANULARITY" = major ]; then echo "minors or patches"; else echo patches; fi; }

# True when PIN stands for its whole release line: always on a coarse backend,
# and for a bare line pin (X.Y, or X for node) when the module sets LINE_PINS=1.
tracks_line() {
  [ "$GRANULARITY" != patch ] && return 0
  [ "${LINE_PINS:-0}" = 1 ] && [[ $1 =~ $LINE_RE ]]
}

warn_patch_pin() {
  if [ "$(effective_pin "$1")" != "$1" ] && [ "$1" != "$2" ]; then
    warn "$BACKEND can't pin $(unpinnable); installed $2 for pin $1"
  fi
}

# latest_in_line VERSIONS PIN: newest of VERSIONS in PIN's release line.
latest_in_line() {
  local line
  line="$(line_of "$2")"
  { grep -E "^${line//./\\.}\." <<<"$1" || true; } | version_sort | tail -n 1
}

cmd_backend() {
  use_backend
  log "$BACKEND ($BACKEND_REASON)"
}

cmd_check() {
  local pin installed onpath
  pin="$(module_pin)"
  log "pin ($PIN_FILE):  $pin"
  if mise_pin "$TOOL"; then log "$MISE_PIN_FILE:      $MISE_PIN ✓"; fi
  use_backend
  log "backend:            $BACKEND"
  installed="$(backend_exec "$pin" "${TOOL_VERSION_ARGS[@]}")"
  if version_matches "$installed" "$(effective_pin "$pin")"; then
    warn_patch_pin "$pin" "$installed"
    log "installed:          $installed ✓"
  else
    die "installed $TOOL $installed does not match pin $pin: run  just $TOOL setup"
  fi
  # The plain command may be a mise shim, which would build a missing version; mise
  # has separate auto-install switches for exec, shims and not-found, so turn off all.
  onpath="$(MISE_AUTO_INSTALL=false MISE_EXEC_AUTO_INSTALL=false MISE_NOT_FOUND_AUTO_INSTALL=false \
    "$PATH_TOOL" "${TOOL_VERSION_ARGS[@]}" 2>/dev/null || true)"
  version_matches "$onpath" "$(effective_pin "$pin")" ||
    warn "$PATH_TOOL on PATH is ${onpath:-not found}, not $pin: tools that run plain $PATH_TOOL ($PATH_TOOL_USERS) won't use the pinned one; see docs/$TOOL.md"
}

cmd_setup() {
  local pin installed
  pin="$(module_pin)"
  use_backend
  log "── installing $TOOL $pin with $BACKEND ──"
  backend_install "$pin"
  log "── verifying build ──"
  backend_exec "$pin" --version
  installed="$(backend_exec "$pin" "${TOOL_VERSION_ARGS[@]}")"
  # A package manager can report success and leave another version in place.
  version_matches "$installed" "$(effective_pin "$pin")" || die "setup left $TOOL $installed installed, not $pin"
  warn_patch_pin "$pin" "$installed"
  verify_install "$pin"
}

cmd_version() {
  local pin
  pin="$(module_pin)"
  use_backend
  backend_exec "$pin" --version
}

cmd_latest() {
  local pin line versions newest all
  pin="$(module_pin)"
  use_backend
  line="$(line_of "$pin")"
  versions="$(list_versions)"
  all="$(version_sort <<<"$versions" | tail -n 1)"
  if tracks_line "$pin"; then
    [ -n "$all" ] || die "no $TOOL versions found via $BACKEND"
    all="$(line_of "$all")"
    printf 'pinned (%s):  %s\n' "$PIN_FILE" "$pin"
    printf 'newest available via %s: %s\n' "$BACKEND" "$all"
    if [ "$line" = "$all" ]; then
      printf '\n✓ pin is the newest %s %s has\n' "$RELEASE_LINE" "$BACKEND"
    else
      printf '\n→ newer %s: %s, run: just %s bump %s\n' "$RELEASE_LINE" "$all" "$TOOL" "$all"
    fi
    return 0
  fi
  newest="$(latest_in_line "$versions" "$pin")"
  [ -n "$newest" ] || die "no stable $line.x versions found via $BACKEND"
  printf 'pinned (%s):  %s\n' "$PIN_FILE" "$pin"
  printf 'latest stable %s.x:     %s\n' "$line" "$newest"
  printf 'latest stable overall:  %s\n' "$all"
  if [ "$pin" = "$newest" ]; then
    printf '\n✓ pin is the latest %s.x stable\n' "$line"
  else
    printf '\n→ newer %s.x stable: %s, run: just %s bump\n' "$line" "$newest" "$TOOL"
  fi
}

# bump [VERSION]: pin VERSION, or the newest release in the current line.
# An explicit VERSION repairs a pin mismatch by writing both files; without one
# there is no way to know which file is right, so the mismatch still stops it.
cmd_bump() {
  local target="${1:-}" pin="" versions="" re="$STABLE_RE" form="X.Y.Z" want avail
  use_backend
  if [ -n "$target" ]; then
    pin="$(pin_read "$PIN_FILE" || true)"
  elif pin_read "$PIN_FILE" >/dev/null; then
    pin="$(module_pin)"
  fi
  if [ -z "$target" ]; then
    [ -n "$pin" ] || die "no $PIN_FILE yet: run  just $TOOL bump <version>"
    if [ "$GRANULARITY" != patch ]; then
      log "✓ $BACKEND tracks the newest $(line_of "$pin").x itself; nothing to bump"
      return 0
    fi
    # Patch backends don't all upgrade an installed X.Y on setup (uv keeps it).
    if tracks_line "$pin"; then
      local n=.N
      [ "$LINE_FIELDS" = 2 ] || n=.N.N
      log "✓ an $LINE_FORM pin accepts any installed $pin.x; nothing to bump (just $TOOL bump $pin$n to pin a patch)"
      return 0
    fi
    versions="$(list_versions)"
    target="$(latest_in_line "$versions" "$pin")"
    [ -n "$target" ] || die "no stable $(line_of "$pin").x versions found via $BACKEND"
  fi
  target="${target#v}"
  if [ "$GRANULARITY" != patch ] || [ "${LINE_PINS:-0}" = 1 ]; then re="$LINE_OR_PATCH_RE" form="$LINE_FORM or X.Y.Z"; fi
  # [[ =~ ]], not grep: grep checks each line of a multi-line value separately.
  [[ $target =~ $re ]] ||
    die "refusing to pin '$target': not a stable $form version"
  [ -n "$versions" ] || versions="$(list_versions)"
  want="$(effective_pin "$target")"
  avail="$versions"
  # A line pin is available if any of its releases is; coarse backends list lines already.
  [[ $want =~ $STABLE_RE ]] || avail="$(cut -d. -f"1-$LINE_FIELDS" <<<"$versions")"
  if ! grep -Fxq -- "$want" <<<"$avail"; then
    [ "$GRANULARITY" != patch ] &&
      die "version $want is not available via $BACKEND; if setup hasn't added its repo yet:  echo $target > $PIN_FILE && just $TOOL setup"
    die "version $want is not available via $BACKEND"
  fi
  [ "$want" = "$target" ] || warn "$BACKEND can't pin $(unpinnable); setup installs the newest $want.x"
  if [ "$target" = "$pin" ] && { ! mise_pin "$TOOL" || [ "$MISE_PIN" = "$target" ]; }; then
    log "✓ already pinned to $pin"
    return 0
  fi
  pin_write "$TOOL" "$PIN_FILE" "$target"
  [ "$pin" = "$target" ] || log "$PIN_FILE: $TOOL ${pin:-(none)} → $target"
  log "next: just $TOOL setup"
}

# Oldest endoflife.date cycle in the pinned major (or, with FLOOR_LTS=1, any LTS
# cycle) whose FLOOR_FIELD date is still ahead: support = in active support, eol = not yet end of life.
cmd_floor() {
  local pin major row cycle patch kind none label ends scope filter
  case "$FLOOR_FIELD" in
    support) kind=active-support none="an actively supported" label="active support until" ;;
    eol) kind=supported none="a supported" label="supported until" ;;
    *) die "unknown FLOOR_FIELD: $FLOOR_FIELD" ;;
  esac
  require_cmd jq "brew install jq / apt install jq"
  pin="$(module_pin)"
  major="$(version_major "$pin")"
  # shellcheck disable=SC2016 # $major is a jq variable
  scope="$major.x" filter='select(.cycle | startswith($major + "."))'
  # Node's cycles are bare majors, and its odd ones never get LTS (lts is false).
  if [ "${FLOOR_LTS:-0}" = 1 ]; then scope=LTS filter='select(.lts | type == "string")'; fi
  row="$(http_get "$EOL_URL" | jq -r --arg today "$(date +%F)" --arg major "$major" --arg f "$FLOOR_FIELD" '
    map(select((.[$f] | type == "string") and (.[$f] > $today)))
    | map('"$filter"')
    | sort_by(.cycle | split(".") | map(tonumber))
    | (.[0] // empty) | "\(.cycle)\t\(.[$f])\t\(.latest)"')"
  [ -n "$row" ] || die "could not find $none $scope branch"
  IFS=$'\t' read -r cycle ends patch <<<"$row"
  # Fixed width keeps the values aligned whichever wording FLOOR_FIELD picks.
  printf '%-26s   %s\n' "current pin:" "$pin"
  printf '%-26s   %s   (%s %s)\n' "oldest $kind $scope:" "$cycle" "$label" "$ends"
  printf '%-26s   %s\n' "latest stable patch:" "$patch"
  printf '\napply (%s floor): just %s bump %s\n' "$kind" "$TOOL" "$patch"
}

main() {
  # Fail on a missing module setting here, not deep in whichever path first reads it.
  : "${TOOL:?}" "${PIN_FILE:?}" "${MODULE_DIR:?}" "${EOL_URL:?}" "${FLOOR_FIELD:?}" "${PATH_TOOL:?}" "${PATH_TOOL_USERS:?}"
  : "${BACKEND_ORDER_MACOS[0]:?}" "${BACKEND_ORDER_LINUX[0]:?}" "${TOOL_VERSION_ARGS[0]:?}"
  declare -F verify_install >/dev/null || die "$TOOL.sh does not define verify_install"
  case "${RELEASE_LINE:=minor}" in
    minor) LINE_FIELDS=2 LINE_FORM=X.Y LINE_RE='^[0-9]+\.[0-9]+$' LINE_OR_PATCH_RE="$MINOR_OR_PATCH_RE" ;;
    major) LINE_FIELDS=1 LINE_FORM=X LINE_RE='^[0-9]+$' LINE_OR_PATCH_RE='^[0-9]+(\.[0-9]+\.[0-9]+)?$' ;;
    *) die "unknown RELEASE_LINE: $RELEASE_LINE" ;;
  esac
  [ -n "${PROJECT_DIR:-}" ] || die "PROJECT_DIR is not set (run via just $TOOL ...)"
  cd "$PROJECT_DIR" || exit 1
  local cmd="${1:-}"
  [ $# -gt 0 ] && shift
  case "$cmd" in
    backend | check | setup | version | latest | bump | floor) "cmd_$cmd" "$@" ;;
    *) die "usage: $TOOL.sh {setup|check|version|latest|bump [VERSION]|floor|backend}" ;;
  esac
}
