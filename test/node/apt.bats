setup() {
  load ../helpers
  common_setup
  export NODE_BACKEND=apt OS_RELEASE="$FIXTURES/os-release-debian" STUB_GPG_FPR=6F71F525282841EEDAF851B42F59B5F99B1BE0B4
  echo 22 >"$PROJECT_DIR/.nvmrc"
  fake_node "$STUB_BIN/node" 22.4.1
}

nodesource_added() {
  mkdir -p "$STUB_ROOT/etc/apt/sources.list.d"
  echo "deb https://deb.nodesource.com/node_$1.x nodistro main" >"$STUB_ROOT/etc/apt/sources.list.d/nodesource.list"
}

@test "setup: adds NodeSource for the pinned major, then installs nodejs from it" {
  run node_sh setup
  [ "$status" -eq 0 ]
  expected="$(cat <<'LOG'
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key
gpg --show-keys --with-colons <key>
install -d -m 0755 /etc/apt/keyrings
install -m 0644 <key> /etc/apt/keyrings/nodesource.asc
install< fake nodesource key
tee /etc/apt/sources.list.d/nodesource.list
tee< deb [signed-by=/etc/apt/keyrings/nodesource.asc] https://deb.nodesource.com/node_22.x nodistro main
apt-get update
apt-get install -y --no-install-recommends --allow-downgrades nodejs=22.*
LOG
)"
  [ "$(grep -v '^apt-cache' "$STUB_LOG" | sed -e 's|^gpg --show-keys --with-colons .*|gpg --show-keys --with-colons <key>|' -e 's|^install -m 0644 .* /etc|install -m 0644 <key> /etc|')" = "$expected" ] || false
  [[ "$output" == *"✓ npm present"* ]]
}

@test "setup: NodeSource already serving the major isn't added again" {
  nodesource_added 22
  run node_sh setup
  [ "$status" -eq 0 ]
  run ! grep -q '^tee ' "$STUB_LOG"
  assert_log "apt-get install -y --no-install-recommends --allow-downgrades nodejs=22.*"
}

@test "setup: a new major points nodesource.list at it" {
  nodesource_added 20
  run node_sh setup
  [ "$status" -eq 0 ]
  grep -q ' https://deb.nodesource.com/node_22.x nodistro main$' "$STUB_ROOT/etc/apt/sources.list.d/nodesource.list"
}

@test "setup: a key with the wrong fingerprint is refused and nothing is added" {
  STUB_GPG_FPR=0123456789ABCDEF0123456789ABCDEF01234567 run node_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"the downloaded nodesource key has fingerprint 0123456789ABCDEF0123456789ABCDEF01234567, not 6F71F525282841EEDAF851B42F59B5F99B1BE0B4; nothing was added"* ]] || false
  [ ! -e "$STUB_ROOT/etc/apt/sources.list.d/nodesource.list" ]
}

@test "setup: a major NodeSource doesn't publish is removed again" {
  STUB_APT_UPDATE_FAIL=nodesource run node_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"apt-get update failed after adding NodeSource node_22.x (it may not publish that major); removed it"* ]] || false
  [ ! -e "$STUB_ROOT/etc/apt/sources.list.d/nodesource.list" ] || false
  assert_log "rm -f /etc/apt/sources.list.d/nodesource.list /etc/apt/keyrings/nodesource.asc"
}

@test "setup: refuses distributions other than Debian and Ubuntu" {
  OS_RELEASE="$FIXTURES/os-release-fedora" run node_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"the apt backend supports Debian and Ubuntu, not fedora"* ]]
}

@test "latest: before setup, warns that NodeSource isn't added" {
  run node_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"NodeSource isn't added yet"* ]] || false
  [[ "$output" == *"newest available via apt: 20"* ]]
}

@test "check: runs node and compares majors" {
  nodesource_added 22
  run node_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          22.4.1 ✓"* ]]
}
