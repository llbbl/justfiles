# shellcheck shell=bash
# apt backend (Debian, Ubuntu): NodeSource's node_N.x repo, newest release only.
# Debian's and Ubuntu's own node is end of life and lacks npm, so it's never used.

NODESOURCE=https://deb.nodesource.com
NODESOURCE_KEY=6F71F525282841EEDAF851B42F59B5F99B1BE0B4

backend_available() { command -v apt-get >/dev/null 2>&1; }
backend_granularity() { echo major; }

# shellcheck source=lib/apt.sh
. "$LIB_DIR/apt.sh"
_apt_nodesource_major() { grep -Fq "$NODESOURCE/node_$1.x" <<<"$(apt-cache policy)"; }

_apt_majors() {
  apt-cache madison nodejs | awk -F'|' '{ gsub(/ /, "", $2); sub(/^[0-9]+:/, "", $2); split($2, v, "."); print v[1] }' | sort -u
}

backend_versions() {
  grep -Fq "$NODESOURCE/" <<<"$(apt-cache policy)" ||
    warn "NodeSource isn't added yet, so only the distro's node is listed; just node setup adds it for the pinned major"
  _apt_majors
}

# The repo carries one major, so a new pin rewrites the same nodesource.list.
backend_install() {
  local major id
  major="$(version_major "$1")"
  id="$(os_release_field ID)"
  case "$id" in ubuntu | debian) ;; *) die "the apt backend supports Debian and Ubuntu, not ${id:-this system}" ;; esac
  apt_get update
  if ! _apt_nodesource_major "$major"; then
    log "adding the NodeSource node_$major.x repository"
    apt_add_repo nodesource "$NODESOURCE/gpgkey/nodesource-repo.gpg.key" "$NODESOURCE_KEY" \
      "$NODESOURCE/node_$major.x nodistro main" \
      "apt-get update failed after adding NodeSource node_$major.x (it may not publish that major); removed it"
  fi
  need_minor "$major"
  # The version glob keeps the distro's own node out; downgrades allow moving to an older major.
  apt_get install -y --no-install-recommends --allow-downgrades "nodejs=$major.*"
}

backend_exec() {
  shift
  exec_bin node "$@"
}
