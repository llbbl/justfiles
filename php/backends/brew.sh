# shellcheck shell=bash
# Homebrew backend: core php@X.Y formulae (core aliases the current php that
# way too), with older minors from the shivammathur/php tap. Never via sudo:
# Homebrew refuses to run as root.

BREW_TAP=shivammathur/php

backend_available() { command -v brew >/dev/null 2>&1; }
backend_granularity() { echo minor; }

backend_versions() {
  brew search --formula '/^php@[0-9]+\.[0-9]+$/' | sed -n 's|^.*php@\([0-9]*\.[0-9]*\)$|\1|p' | sort -u
}

backend_install() {
  local formula info
  formula="php@$(version_minor "$1")"
  # Disabled core formulae still answer `brew info`, so check the flag too. grep,
  # not jq: brew's JSON is pretty-printed and jq isn't otherwise needed here.
  info="$(brew info --json=v2 "$formula" 2>/dev/null || true)"
  if [ -z "$info" ] || grep -Eq '"disabled": ?true' <<<"$info"; then
    if ! grep -Fxq "$BREW_TAP" <<<"$(brew tap)"; then
      log "adding Homebrew tap $BREW_TAP for $formula"
      brew tap "$BREW_TAP"
    fi
    formula="$BREW_TAP/$formula"
  fi
  brew install "$formula"
}

backend_exec() {
  local formula prefix
  formula="php@$(version_minor "$1")"
  shift
  prefix="$(brew --prefix "$formula" || true)"
  if [ -z "$prefix" ] || [ ! -x "$prefix/bin/php" ]; then
    die "$formula is not installed: run  just php setup"
  fi
  "$prefix/bin/php" "$@"
}
