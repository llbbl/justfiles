# shellcheck shell=bash
# dnf backend (Fedora only): Remi's phpNN-php-* packages, newest patch only.
# RHEL-family systems need EPEL and a different remi-release, so they're refused.

backend_available() { command -v dnf >/dev/null 2>&1; }
backend_granularity() { echo minor; }

_dnf_has_remi() { rpm -q remi-release >/dev/null 2>&1; }

backend_versions() {
  _dnf_has_remi || warn "Remi's repository isn't added yet, so no versions are listed; just php setup adds it"
  dnf -q repoquery --qf '%{name}\n' 'php[0-9][0-9]-php-cli' | sed -n 's/^php\([0-9]\)\([0-9]*\)-php-cli$/\1.\2/p' | sort -u
}

backend_install() {
  local id minor nn p pkgs=()
  id="$(os_release_field ID)"
  [ "$id" = fedora ] || die "the dnf backend supports Fedora only, not ${id:-this system} (yet)"
  minor="$(version_minor "$1")"
  nn="${minor//./}"
  if ! _dnf_has_remi; then
    log "adding Remi's repository"
    run_privileged dnf install -y "https://rpms.remirepo.net/fedora/remi-release-$(os_release_field VERSION_ID).rpm"
  fi
  need_minor "$minor"
  for p in $(php_packages "$minor"); do pkgs+=("php$nn-php-$p"); done
  run_privileged dnf install -y "${pkgs[@]}"
}

# Remi links /usr/bin/phpNN to the collection's php.
backend_exec() {
  local bin
  bin="php$(version_minor "$1" | tr -d .)"
  shift
  exec_bin "$bin" "$@"
}
