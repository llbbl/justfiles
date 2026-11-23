# shellcheck shell=bash
# nvm backend: nvm is a shell function, so each call sources nvm.sh in a
# subshell. Exact pins; a bare major means its newest release.

# The curl installer puts nvm.sh in NVM_DIR; Homebrew keeps it in its own prefix.
_nvm_sh() {
  local f
  for f in "${NVM_DIR:-$HOME/.nvm}/nvm.sh" "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/nvm/nvm.sh" /usr/local/opt/nvm/nvm.sh; do
    if [ -s "$f" ]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

# nvm.sh isn't written for errexit, nounset or pipefail. --no-use skips activating a default version.
_nvm() {
  local sh
  sh="$(_nvm_sh)" || die "nvm.sh not found: set NVM_DIR"
  (
    set +euo pipefail
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    mkdir -p "$NVM_DIR"
    # shellcheck disable=SC1090
    . "$sh" --no-use
    nvm "$@"
  )
}

backend_available() { _nvm_sh >/dev/null; }
backend_granularity() { echo patch; }

backend_versions() {
  _nvm ls-remote --no-colors | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/) { print substr($i, 2); break } }'
}

backend_install() { _nvm install "$1"; }

backend_exec() {
  local pin="$1" bin
  shift
  bin="$(_nvm which "$pin" 2>/dev/null | tail -n 1 || true)"
  [ -x "$bin" ] || die "node $pin is not installed: run  just node setup"
  "$bin" "$@"
}
