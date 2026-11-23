# shellcheck shell=bash
# apt backend (Debian, Ubuntu): phpX.Y packages from packages.sury.org, newest
# patch only. Ubuntu too: ppa:ondrej/php is frozen and points at sury.

SURY=https://packages.sury.org

backend_available() { command -v apt-get >/dev/null 2>&1; }
backend_granularity() { echo minor; }

_apt_get() { run_privileged env DEBIAN_FRONTEND=noninteractive apt-get "$@"; }
_apt_has_sury() { grep -Fq "$SURY/php" <<<"$(apt-cache policy)"; }

backend_versions() {
  _apt_has_sury || warn "packages.sury.org isn't added yet, so only the distro's php is listed; just php setup adds it"
  apt-cache search --names-only '^php[0-9]+\.[0-9]+-cli$' | sed -n 's/^php\([0-9]*\.[0-9]*\)-cli .*/\1/p'
}

# The steps from packages.sury.org/php/README.txt, with os-release in place of lsb_release.
_apt_add_sury() {
  local id codename deb
  id="$(os_release_field ID)"
  codename="$(os_release_field VERSION_CODENAME)"
  case "$id" in ubuntu | debian) ;; *) die "the apt backend supports Debian and Ubuntu, not ${id:-this system}" ;; esac
  [ -n "$codename" ] || die "no VERSION_CODENAME in ${OS_RELEASE:-/etc/os-release}"
  log "adding the packages.sury.org php repository for $id $codename"
  _apt_get install -y --no-install-recommends ca-certificates curl
  deb="$(mktemp)"
  http_get "$SURY/debsuryorg-archive-keyring.deb" >"$deb" || { rm -f "$deb"; die "could not download the sury keyring"; }
  run_privileged dpkg -i "$deb"
  rm -f "$deb"
  printf 'deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] %s/php/ %s main\n' "$SURY" "$codename" |
    run_privileged tee /etc/apt/sources.list.d/php.list >/dev/null
  _apt_get update
}

backend_install() {
  local minor p pkgs=()
  minor="$(version_minor "$1")"
  _apt_get update
  _apt_has_sury || _apt_add_sury
  need_minor "$minor"
  for p in $(php_packages "$minor"); do pkgs+=("php$minor-$p"); done
  _apt_get install -y --no-install-recommends "${pkgs[@]}"
}

backend_exec() {
  local bin
  bin="php$(version_minor "$1")"
  shift
  exec_bin "$bin" "$@"
}
