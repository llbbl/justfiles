# shellcheck shell=bash
# apt helpers shared by the apt backends.

apt_get() { run_privileged env DEBIAN_FRONTEND=noninteractive apt-get "$@"; }

# apt_add_repo NAME KEY_URL FINGERPRINT SOURCE RELEASE_URL [HINT]: adds `deb SOURCE`
# as sources.list.d/NAME.list, signed by the single key at KEY_URL, which must
# have FINGERPRINT. Nothing changes unless RELEASE_URL (the suite's Release file)
# exists. If apt-get update then fails, puts back the list and key it replaced,
# or removes them on a first add, and dies; HINT is appended to either failure.
apt_add_repo() {
  local name="$1" url="$2" want="$3" source="$4" release="$5" hint="${6:+. $6}" host key out fpr saved f
  local list="/etc/apt/sources.list.d/$name.list" asc="/etc/apt/keyrings/$name.asc"
  local restored=() gone=()
  host="${url#*://}"
  host="${host%%/*}"
  apt_get install -y --no-install-recommends ca-certificates curl gnupg
  # After that install: stock Debian and Ubuntu images have neither curl nor wget.
  http_get "$release" >/dev/null ||
    die "could not fetch $release: $name may not publish it, or the network is down; nothing was changed$hint"
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
  # No sudo needed: apt-cache and _apt read these, so a working pair is world-readable.
  # ponytail: a missing or unreadable file isn't saved, and a failed update removes it, as before.
  saved="$(mktemp -d)"
  for f in "$list" "$asc"; do cp "$f" "$saved/" 2>/dev/null || :; done
  run_privileged install -d -m 0755 /etc/apt/keyrings
  # install, not tee: apt reads keys as _apt, so the mode can't depend on root's umask.
  run_privileged install -m 0644 "$key" "$asc"
  rm -f "$key"
  printf 'deb [signed-by=%s] %s\n' "$asc" "$source" | run_privileged tee "$list" >/dev/null
  if ! apt_get update; then
    for f in "$list" "$asc"; do
      if [ -e "$saved/${f##*/}" ]; then
        run_privileged install -m 0644 "$saved/${f##*/}" "$f"
        restored+=("$f")
      else
        gone+=("$f")
      fi
    done
    rm -rf "$saved"
    [ ${#gone[@]} -eq 0 ] || { run_privileged rm -f "${gone[@]}"; warn "removed ${gone[*]}"; }
    [ ${#restored[@]} -eq 0 ] || warn "restored the previous ${restored[*]}"
    die "apt-get update failed after adding deb $source$hint"
  fi
  rm -rf "$saved"
}
