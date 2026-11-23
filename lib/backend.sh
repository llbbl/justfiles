# shellcheck shell=bash
# Backend selection. A backend is <module>/backends/<name>.sh defining:
#   backend_available, backend_granularity (patch|minor|major),
#   backend_versions, backend_install PIN, backend_exec PIN ARGS...

BACKEND_FNS="backend_available backend_granularity backend_versions backend_install backend_exec"

_backend_load() {
  local file="$1/backends/$2.sh" fn f have=""
  # Drop the previous candidate's functions so they can't satisfy this one's contract.
  # shellcheck disable=SC2086 # intentional word split
  unset -f $BACKEND_FNS
  if [ ! -f "$file" ]; then
    for f in "$1"/backends/*.sh; do f="${f##*/}"; have="$have ${f%.sh}"; done
    die "unknown backend: $2 (have:$have)"
  fi
  # shellcheck source=/dev/null
  . "$file"
  for fn in $BACKEND_FNS; do
    declare -F "$fn" >/dev/null || die "backend $2 does not define $fn"
  done
}

# backend_select MODULE_DIR ENV_VAR ORDER...
# Loads the backend named by $ENV_VAR, else the first available in ORDER.
# Sets BACKEND and BACKEND_REASON.
# shellcheck disable=SC2034 # BACKEND and BACKEND_REASON are read by the caller
backend_select() {
  local dir="$1" var="$2" name
  shift 2
  name="${!var:-}"
  if [ -n "$name" ]; then
    _backend_load "$dir" "$name"
    backend_available || die "$var=$name, but $name is not installed"
    BACKEND="$name"
    BACKEND_REASON="set by $var"
    return 0
  fi
  for name in "$@"; do
    _backend_load "$dir" "$name"
    if backend_available; then
      BACKEND="$name"
      BACKEND_REASON="first available of: $*"
      return 0
    fi
  done
  die "no supported backend found (tried: $*)"
}
