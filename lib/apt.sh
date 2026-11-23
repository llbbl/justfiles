# shellcheck shell=bash
# apt helpers shared by the apt backends.

apt_get() { run_privileged env DEBIAN_FRONTEND=noninteractive apt-get "$@"; }

# apt_add_repo NAME KEY_URL FINGERPRINT SOURCE UPDATE_FAILED: adds `deb SOURCE`
# as sources.list.d/NAME.list, signed by the single key at KEY_URL, which must
# have FINGERPRINT. If apt-get update then fails, removes it again and dies with UPDATE_FAILED.
apt_add_repo() {
  local name="$1" url="$2" want="$3" source="$4" failed="$5" host key out fpr
  host="${url#*://}"
  host="${host%%/*}"
  apt_get install -y --no-install-recommends ca-certificates curl gnupg
  key="$(mktemp)"
  http_get "$url" >"$key" || { rm -f "$key"; die "could not download the $name signing key from $host"; }
  # Captured first: awk's early exit would SIGPIPE gpg and trip pipefail.
  out="$(gpg --show-keys --with-colons "$key" 2>/dev/null || true)"
  fpr="$(awk -F: '$1 == "fpr" { print $10; exit }' <<<"$out")"
  if [ "$fpr" != "$want" ]; then
    rm -f "$key"
    die "the downloaded $name key has fingerprint ${fpr:-(none)}, not $want; nothing was added"
  fi
  # apt would trust every key in the file for this repo, so allow exactly one.
  if [ "$(grep -c '^pub:' <<<"$out" || true)" -ne 1 ]; then
    rm -f "$key"
    die "the downloaded $name key file holds more than one key; nothing was added"
  fi
  run_privileged install -d -m 0755 /etc/apt/keyrings
  # install, not tee: apt reads keys as _apt, so the mode can't depend on root's umask.
  run_privileged install -m 0644 "$key" "/etc/apt/keyrings/$name.asc"
  rm -f "$key"
  printf 'deb [signed-by=/etc/apt/keyrings/%s.asc] %s\n' "$name" "$source" |
    run_privileged tee "/etc/apt/sources.list.d/$name.list" >/dev/null
  if ! apt_get update; then
    run_privileged rm -f "/etc/apt/sources.list.d/$name.list" "/etc/apt/keyrings/$name.asc"
    die "$failed"
  fi
}
