# shellcheck shell=bash
# apt backend (Debian, Ubuntu): pythonX.Y packages, newest patch only. Ubuntu
# adds ppa:deadsnakes for a minor its archive lacks; Debian has only its own.

DEADSNAKES=https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu
# The PPA's signing key, as Launchpad's API reports it.
DEADSNAKES_KEY=F23C5A6CF475977595C89F51BA6932366A755776

backend_available() { command -v apt-get >/dev/null 2>&1; }
backend_granularity() { echo minor; }

_apt_get() { run_privileged env DEBIAN_FRONTEND=noninteractive apt-get "$@"; }
_apt_has_deadsnakes() { grep -Fq "$DEADSNAKES" <<<"$(apt-cache policy)"; }

# deadsnakes publishes alphas under the same package names (3.16.0~a2), so
# a ~ right after the upstream version is dropped. Debian revisions may hold one too
# (3.10.12-1~22.04.10, ~bpo12+1), so those stay.
_apt_minors() {
  local pkgs
  pkgs="$(apt-cache search --names-only '^python3\.[0-9]+$' | cut -d' ' -f1)"
  [ -n "$pkgs" ] || return 0
  # shellcheck disable=SC2086 # one package name per word
  apt-cache madison $pkgs | awk -F'|' '{ gsub(/ /, "") } $2 !~ /^[0-9.]+~/ { sub(/^python/, "", $1); print $1 }' | sort -u
}

backend_versions() {
  if [ "$(os_release_field ID)" = ubuntu ] && ! _apt_has_deadsnakes; then
    warn "ppa:deadsnakes isn't added yet, so only Ubuntu's own python is listed; just python setup adds it for a minor Ubuntu lacks"
  fi
  _apt_minors
}

_apt_add_deadsnakes() {
  local codename key out fpr
  codename="$(os_release_field VERSION_CODENAME)"
  [ -n "$codename" ] || die "no VERSION_CODENAME in ${OS_RELEASE:-/etc/os-release}"
  log "adding ppa:deadsnakes for ubuntu $codename"
  _apt_get install -y --no-install-recommends ca-certificates curl gnupg
  key="$(mktemp)"
  http_get "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x$DEADSNAKES_KEY" >"$key" ||
    { rm -f "$key"; die "could not download the deadsnakes signing key from keyserver.ubuntu.com"; }
  # Captured first: awk's early exit would SIGPIPE gpg and trip pipefail.
  out="$(gpg --show-keys --with-colons "$key" 2>/dev/null || true)"
  fpr="$(awk -F: '$1 == "fpr" { print $10; exit }' <<<"$out")"
  if [ "$fpr" != "$DEADSNAKES_KEY" ]; then
    rm -f "$key"
    die "the downloaded deadsnakes key has fingerprint ${fpr:-(none)}, not $DEADSNAKES_KEY; nothing was added"
  fi
  # apt would trust every key in the file for this repo, so allow exactly one.
  if [ "$(grep -c '^pub:' <<<"$out" || true)" -ne 1 ]; then
    rm -f "$key"
    die "the downloaded deadsnakes key file holds more than one key; nothing was added"
  fi
  run_privileged install -d -m 0755 /etc/apt/keyrings
  run_privileged tee /etc/apt/keyrings/deadsnakes.asc <"$key" >/dev/null
  rm -f "$key"
  printf 'deb [signed-by=/etc/apt/keyrings/deadsnakes.asc] %s %s main\n' "$DEADSNAKES" "$codename" |
    run_privileged tee /etc/apt/sources.list.d/deadsnakes.list >/dev/null
  # Non-LTS releases, and a new LTS before the PPA builds for it, have no Release file.
  if ! _apt_get update; then
    run_privileged rm -f /etc/apt/sources.list.d/deadsnakes.list /etc/apt/keyrings/deadsnakes.asc
    die "apt-get update failed after adding ppa:deadsnakes (it may have no release for ubuntu $codename); removed it. $UV_HINT"
  fi
}

# pythonX.Y-venv carries ensurepip, without which `python -m venv` fails.
backend_install() {
  local minor id
  minor="$(version_minor "$1")"
  id="$(os_release_field ID)"
  case "$id" in ubuntu | debian) ;; *) die "the apt backend supports Debian and Ubuntu, not ${id:-this system}" ;; esac
  _apt_get update
  if [ "$id" = ubuntu ] && ! grep -Fxq -- "$minor" <<<"$(_apt_minors)" && ! _apt_has_deadsnakes; then
    _apt_add_deadsnakes
  fi
  need_minor "$minor" "$UV_HINT"
  _apt_get install -y --no-install-recommends "python$minor" "python$minor-venv"
}

backend_exec() {
  local bin
  bin="python$(version_minor "$1")"
  shift
  exec_bin "$bin" "$@"
}
