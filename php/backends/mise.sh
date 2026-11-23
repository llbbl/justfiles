# shellcheck shell=bash
# mise backend: builds PHP from source, exact patch pins.

backend_available() { command -v mise >/dev/null 2>&1; }
backend_granularity() { echo patch; }
backend_versions() { mise ls-remote php | stable_versions; }

# mise's php plugin hardcodes the EOL openssl@1.1 (no TLS). Overriding
# PHP_CONFIGURE_OPTIONS drops the plugin's lib flags too, so openssl@3 and
# Homebrew libiconv are re-supplied (macOS's stock libiconv fails configure).
backend_install() {
  local pin="$1" ssl iconv lib pc=""
  [ "$(detect_os)" = macos ] ||
    die "the mise backend builds PHP from source and only knows macOS build deps so far"
  require_cmd brew "https://brew.sh"
  brew install openssl@3 gd icu4c libzip oniguruma libxml2 libiconv
  ssl="$(brew --prefix openssl@3)"
  iconv="$(brew --prefix libiconv)"
  for lib in openssl@3 icu4c libzip gd oniguruma libxml2; do
    pc="${pc}$(brew --prefix "$lib")/lib/pkgconfig:"
  done
  PHP_CONFIGURE_OPTIONS="--with-openssl=${ssl} --with-iconv=${iconv}" \
    PKG_CONFIG_PATH="${pc}${PKG_CONFIG_PATH:-}" \
    mise install "php@$pin"
}

# Runs the installed binary directly: `mise exec` would auto-install, turning
# `version` or `check` into a full PHP build.
backend_exec() {
  local pin="$1" dir
  shift
  dir="$(mise where "php@$pin")" || die "php $pin is not installed: run  just php setup"
  "$dir/bin/php" "$@"
}
