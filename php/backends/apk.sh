# shellcheck shell=bash
# apk backend (Alpine): the phpNN packages this Alpine release ships, newest
# patch only. --no-cache fetches the index, which slim images don't keep.

backend_available() { command -v apk >/dev/null 2>&1; }
backend_granularity() { echo minor; }

backend_versions() {
  apk --no-cache search -x 'php*' | sed -n 's/^php[0-9]*-\([0-9]*\.[0-9]*\)\..*/\1/p'
}

# openssl is a separate package on Alpine, built in everywhere else.
backend_install() {
  local minor nn p pkgs=()
  minor="$(version_minor "$1")"
  nn="${minor//./}"
  need_minor "$minor" "other Alpine releases ship other minors"
  for p in $(php_packages "$minor") openssl; do
    if [ "$p" = cli ]; then pkgs+=("php$nn"); else pkgs+=("php$nn-$p"); fi
  done
  run_privileged apk --no-cache add "${pkgs[@]}"
}

backend_exec() {
  local bin
  bin="php$(version_minor "$1" | tr -d .)"
  shift
  exec_bin "$bin" "$@"
}
