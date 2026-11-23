setup() {
  load ../helpers
  common_setup
  export PHP_BACKEND=dnf OS_RELEASE="$FIXTURES/os-release-fedora"
  echo 8.5 >"$PROJECT_DIR/.php-version"
  fake_php "$STUB_BIN/php85" 8.5.13
}

@test "setup: adds Remi's repository, then installs the extension set" {
  run php_sh setup
  [ "$status" -eq 0 ]
  [ "$(grep '^dnf install' "$STUB_LOG")" = "$(printf '%s\n' \
    "dnf install -y https://rpms.remirepo.net/fedora/remi-release-43.rpm" \
    "dnf install -y php85-php-cli php85-php-common php85-php-curl php85-php-mbstring php85-php-xml php85-php-zip php85-php-intl php85-php-gd")" ]
  [[ "$output" == *"✓ openssl extension present"* ]]
}

@test "setup: running twice adds Remi's repository once" {
  php_sh setup
  php_sh setup
  [ "$(grep -c 'remi-release-43.rpm' "$STUB_LOG")" -eq 1 ]
}

@test "setup: opcache is a package before PHP 8.5" {
  echo 8.3 >"$PROJECT_DIR/.php-version"
  fake_php "$STUB_BIN/php83" 8.3.30
  run php_sh setup
  [ "$status" -eq 0 ]
  assert_log "php83-php-gd php83-php-opcache"
}

@test "setup: refuses non-Fedora systems before changing anything" {
  export OS_RELEASE="$FIXTURES/os-release-rocky"
  run php_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"supports Fedora only, not rocky"* ]] || false
  run ! grep -q '^dnf install' "$STUB_LOG"
}

@test "latest: before Remi, says why nothing is listed" {
  run php_sh latest
  [ "$status" -ne 0 ]
  [[ "$output" == *"Remi's repository isn't added yet"* ]]
}

@test "latest: with Remi, offers the newest minor" {
  touch "$STUB_ROOT/remi-release"
  run php_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"newest available via dnf: 8.6"* ]]
}

@test "check: runs Remi's phpNN binary" {
  run php_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          8.5.13 ✓"* ]]
}
