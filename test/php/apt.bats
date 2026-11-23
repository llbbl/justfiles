setup() {
  load ../helpers
  common_setup
  export PHP_BACKEND=apt OS_RELEASE="$FIXTURES/os-release-ubuntu"
  echo 8.5 >"$PROJECT_DIR/.php-version"
  fake_php "$STUB_BIN/php8.5" 8.5.9
}

sury_added() {
  mkdir -p "$STUB_ROOT/etc/apt/sources.list.d"
  echo "deb https://packages.sury.org/php/ noble main" >"$STUB_ROOT/etc/apt/sources.list.d/php.list"
}

@test "setup: adds packages.sury.org, then installs the extension set" {
  run php_sh setup
  [ "$status" -eq 0 ]
  expected="$(cat <<'LOG'
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl
curl -fsSL https://packages.sury.org/debsuryorg-archive-keyring.deb
dpkg -i <deb>
tee /etc/apt/sources.list.d/php.list
tee< deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ noble main
apt-get update
apt-get install -y --no-install-recommends php8.5-cli php8.5-common php8.5-curl php8.5-mbstring php8.5-xml php8.5-zip php8.5-intl php8.5-gd
LOG
)"
  [ "$(grep -v '^apt-cache' "$STUB_LOG" | sed 's|^dpkg -i .*|dpkg -i <deb>|')" = "$expected" ]
  [[ "$output" == *"+ env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends php8.5-cli"* ]] || false
  [[ "$output" == *"✓ openssl extension present"* ]]
}

@test "setup: Debian uses its own codename" {
  export OS_RELEASE="$FIXTURES/os-release-debian"
  run php_sh setup
  [ "$status" -eq 0 ]
  grep -q ' https://packages.sury.org/php/ trixie main$' "$STUB_ROOT/etc/apt/sources.list.d/php.list"
}

@test "setup: skips the repository when it is already there" {
  sury_added
  run php_sh setup
  [ "$status" -eq 0 ]
  run ! grep -Eq '^(dpkg|tee|curl)' "$STUB_LOG"
  assert_log "apt-get install -y --no-install-recommends php8.5-cli"
}

@test "setup: running twice adds the repository once" {
  php_sh setup
  php_sh setup
  [ "$(grep -c '^dpkg -i' "$STUB_LOG")" -eq 1 ]
}

@test "setup: opcache is a package before PHP 8.5" {
  echo 8.4 >"$PROJECT_DIR/.php-version"
  fake_php "$STUB_BIN/php8.4" 8.4.28
  run php_sh setup
  [ "$status" -eq 0 ]
  assert_log "php8.4-intl php8.4-gd php8.4-opcache"
}

@test "setup: goes through sudo when not root" {
  STUB_UID=1000 run php_sh setup
  [ "$status" -eq 0 ]
  assert_log "sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends php8.5-cli"
  assert_log "sudo dpkg -i"
}

@test "setup: refuses other apt distributions" {
  export OS_RELEASE="$FIXTURES/os-release-rocky"
  run php_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"supports Debian and Ubuntu, not rocky"* ]] || false
  run ! grep -q '^dpkg' "$STUB_LOG"
}

@test "setup: names what is available when the minor is not" {
  echo 9.9 >"$PROJECT_DIR/.php-version"
  run php_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"php 9.9 is not available via apt (have: 5.6 7.0 7.1 7.2 7.3 7.4 8.0 8.1 8.2 8.3 8.4 8.5 8.6)"* ]] || false
  run ! grep -q 'php9.9' "$STUB_LOG"
}

@test "latest: before sury, lists the distro's php and says why" {
  run php_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"packages.sury.org isn't added yet"* ]] || false
  [[ "$output" == *"newest available via apt: 8.3"* ]]
}

@test "latest: with sury, offers the newest minor" {
  sury_added
  run php_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"newest available via apt: 8.6"* ]] || false
  [[ "$output" == *"just php bump 8.6"* ]]
}

@test "check: runs the minor's binary" {
  run php_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          8.5.9 ✓"* ]]
}

@test "check: names the missing binary" {
  rm "$STUB_BIN/php8.5"
  run php_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *"php8.5 is not installed: run  just php setup"* ]]
}

@test "setup: a sury with no release for this system is removed again" {
  STUB_APT_UPDATE_FAIL=php run php_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"apt-get update failed after adding packages.sury.org (it may have no release for ubuntu noble); removed it."* ]] || false
  [ ! -e "$STUB_ROOT/etc/apt/sources.list.d/php.list" ] || false
  assert_log "rm -f /etc/apt/sources.list.d/php.list"
  run ! grep -q 'php8.5-cli' "$STUB_LOG"
}
