setup() {
  load ../helpers
  common_setup
  export PYTHON_BACKEND=apt OS_RELEASE="$FIXTURES/os-release-ubuntu"
  echo 3.13 >"$PROJECT_DIR/.python-version"
  fake_python "$STUB_BIN/python3.13" 3.13.18
}

deadsnakes_added() {
  mkdir -p "$STUB_ROOT/etc/apt/sources.list.d"
  echo "deb https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu noble main" >"$STUB_ROOT/etc/apt/sources.list.d/deadsnakes.list"
}

@test "setup: Ubuntu adds ppa:deadsnakes for a minor it lacks, then installs it with venv" {
  run python_sh setup
  [ "$status" -eq 0 ]
  expected="$(cat <<'LOG'
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg
curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF23C5A6CF475977595C89F51BA6932366A755776
gpg --show-keys --with-colons <key>
install -d -m 0755 /etc/apt/keyrings
tee /etc/apt/keyrings/deadsnakes.asc
tee< fake deadsnakes key
tee /etc/apt/sources.list.d/deadsnakes.list
tee< deb [signed-by=/etc/apt/keyrings/deadsnakes.asc] https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu noble main
apt-get update
apt-get install -y --no-install-recommends python3.13 python3.13-venv
LOG
)"
  [ "$(grep -v '^apt-cache' "$STUB_LOG" | sed 's|^gpg --show-keys --with-colons .*|gpg --show-keys --with-colons <key>|')" = "$expected" ] || false
  [[ "$output" == *"✓ ssl, sqlite3, venv and ensurepip present"* ]]
}

@test "setup: a key with the wrong fingerprint is refused and nothing is added" {
  STUB_GPG_FPR=0123456789ABCDEF0123456789ABCDEF01234567 run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"the downloaded deadsnakes key has fingerprint 0123456789ABCDEF0123456789ABCDEF01234567, not F23C5A6CF475977595C89F51BA6932366A755776; nothing was added"* ]] || false
  [ ! -e "$STUB_ROOT/etc/apt/keyrings/deadsnakes.asc" ] || false
  [ ! -e "$STUB_ROOT/etc/apt/sources.list.d/deadsnakes.list" ] || false
  run ! grep -q 'python3.13' "$STUB_LOG"
}

@test "setup: a failed key download says so and adds nothing" {
  STUB_CURL_FAIL=1 run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not download the deadsnakes signing key from keyserver.ubuntu.com"* ]] || false
  run ! grep -q '^tee' "$STUB_LOG"
}

@test "setup: a PPA with no release for this Ubuntu is removed again" {
  STUB_APT_UPDATE_FAIL=1 run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"ppa:deadsnakes has no release for ubuntu noble; uv installs any minor without sudo"* ]] || false
  [ ! -e "$STUB_ROOT/etc/apt/keyrings/deadsnakes.asc" ] || false
  [ ! -e "$STUB_ROOT/etc/apt/sources.list.d/deadsnakes.list" ] || false
  assert_log "rm -f /etc/apt/sources.list.d/deadsnakes.list /etc/apt/keyrings/deadsnakes.asc"
  run ! grep -q 'python3.13-venv' "$STUB_LOG"
}

@test "setup: a ~ in the Debian revision is kept, a prerelease is dropped" {
  deadsnakes_added
  echo 3.99 >"$PROJECT_DIR/.python-version"
  run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"python 3.99 is not available via apt (have: 3.9 3.10 3.11 3.12 3.13);"* ]]
}

@test "setup: Ubuntu's own minor needs no PPA" {
  echo 3.12 >"$PROJECT_DIR/.python-version"
  fake_python "$STUB_BIN/python3.12" 3.12.3
  run python_sh setup
  [ "$status" -eq 0 ]
  run ! grep -q '^tee' "$STUB_LOG"
  assert_log "apt-get install -y --no-install-recommends python3.12 python3.12-venv"
}

@test "setup: running twice adds the PPA once" {
  python_sh setup
  python_sh setup
  [ "$(grep -c '^tee /etc/apt/sources.list.d/deadsnakes.list' "$STUB_LOG")" -eq 1 ]
}

@test "setup: Debian never adds the PPA, and points at uv" {
  export OS_RELEASE="$FIXTURES/os-release-debian"
  run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"python 3.13 is not available via apt (have: 3.12); uv installs any minor without sudo"* ]] || false
  run ! grep -q '^tee' "$STUB_LOG"
}

@test "setup: refuses other apt distributions" {
  export OS_RELEASE="$FIXTURES/os-release-rocky"
  run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"supports Debian and Ubuntu, not rocky"* ]]
}

@test "setup: goes through sudo when not root" {
  STUB_UID=1000 run python_sh setup
  [ "$status" -eq 0 ]
  assert_log "sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3.13 python3.13-venv"
}

@test "latest: before the PPA, lists Ubuntu's python and says why" {
  echo 3.12 >"$PROJECT_DIR/.python-version"
  run python_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"ppa:deadsnakes isn't added yet"* ]] || false
  [[ "$output" == *"newest available via apt: 3.12"* ]]
}

@test "latest: with the PPA, the newest minor skips its alphas" {
  deadsnakes_added
  run python_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"newest available via apt: 3.13"* ]]
}

@test "check: runs the minor's binary" {
  run python_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          3.13.18 ✓"* ]]
}

@test "check: names the missing binary" {
  rm "$STUB_BIN/python3.13"
  run python_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *"python3.13 is not installed: run  just python setup"* ]]
}
