# shellcheck shell=bash
# pacman backend (Arch): two minors only, php (newest) and php-legacy. Both
# bundle curl, intl, mbstring, xml, zip and opcache; gd is a separate package.

backend_available() { command -v pacman >/dev/null 2>&1; }
backend_granularity() { echo minor; }

# stdin "name version" lines → "name minor".
_pacman_minor() { awk '{ split($2, v, "."); print $1, v[1] "." v[2] }'; }
# pacman translates -Si field labels.
_pacman_sync() { LC_ALL=C pacman -Si php php-legacy | awk '/^Name/ { n = $3 } /^Version/ { print n, $3 }' | _pacman_minor; }
_pacman_pkg() { awk -v m="$1" '$2 == m { print $1; exit }'; }

backend_versions() { _pacman_sync | cut -d' ' -f2; }

backend_install() {
  local minor pkg ini mods ext lines="" names=""
  minor="$(version_minor "$1")"
  need_minor "$minor" "Homebrew can install other minors"
  pkg="$(_pacman_sync | _pacman_pkg "$minor")"
  run_privileged pacman -S --needed --noconfirm "$pkg" "$pkg-gd"
  # Arch ships gd and intl disabled in php.ini; enable only what php.ini doesn't,
  # since loading a module twice warns on every php run.
  ini="/etc/$pkg/conf.d/justfiles.ini"
  [ ! -f "$ini" ] || return 0
  mods="$("$pkg" -m)"
  for ext in gd intl; do
    grep -iqx "$ext" <<<"$mods" && continue
    lines="${lines}extension=$ext"$'\n'
    names="$names $ext"
  done
  [ -n "$lines" ] || return 0
  log "enabling$names in $ini"
  printf '%s' "$lines" | run_privileged tee "$ini" >/dev/null
}

# The package name is also the binary name.
backend_exec() {
  local minor pkg
  minor="$(version_minor "$1")"
  shift
  pkg="$({ pacman -Q php php-legacy 2>/dev/null || true; } | _pacman_minor | _pacman_pkg "$minor")"
  [ -n "$pkg" ] || die "php $minor is not installed: run  just php setup"
  exec_bin "$pkg" "$@"
}
