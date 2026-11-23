setup() {
  load ../helpers
  common_setup
  export PHP_BACKEND=brew STUB_BREW_PREFIX="$BATS_TEST_TMPDIR/brew"
  echo 8.5 >"$PROJECT_DIR/.php-version"
  fake_php "$STUB_BREW_PREFIX/opt/php@8.5/bin/php" 8.5.13
}

@test "setup: core minors install php@X.Y without a tap" {
  run php_sh setup
  [ "$status" -eq 0 ]
  assert_log "brew install php@8.5"
  run ! grep -q 'brew tap ' "$STUB_LOG"
}

@test "setup: older minors add the shivammathur/php tap first" {
  echo 7.4 >"$PROJECT_DIR/.php-version"
  fake_php "$STUB_BREW_PREFIX/opt/php@7.4/bin/php" 7.4.33
  run php_sh setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"adding Homebrew tap shivammathur/php for php@7.4"* ]] || false
  [ "$(grep -E '^brew (tap |install)' "$STUB_LOG")" = "$(printf '%s\n' \
    "brew tap shivammathur/php" "brew install shivammathur/php/php@7.4")" ]
}

@test "setup: an existing tap is not added again" {
  echo 7.4 >"$PROJECT_DIR/.php-version"
  fake_php "$STUB_BREW_PREFIX/opt/php@7.4/bin/php" 7.4.33
  php_sh setup
  php_sh setup
  [ "$(grep -c '^brew tap shivammathur/php' "$STUB_LOG")" -eq 1 ]
}

@test "setup: never uses sudo, even when not root" {
  STUB_UID=1000 run php_sh setup
  [ "$status" -eq 0 ]
  run ! grep -q '^sudo' "$STUB_LOG"
}

@test "latest: lists core minors, including the alias for the current php" {
  run php_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"newest available via brew: 8.6"* ]]
}

@test "check: runs the formula's php" {
  run php_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          8.5.13 ✓"* ]]
}

@test "check: names the formula when it isn't installed" {
  echo 8.4 >"$PROJECT_DIR/.php-version"
  run php_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *"php@8.4 is not installed: run  just php setup"* ]]
}

@test "setup: a disabled core formula falls back to the tap" {
  echo 8.1 >"$PROJECT_DIR/.php-version"
  fake_php "$STUB_BREW_PREFIX/opt/php@8.1/bin/php" 8.1.33
  STUB_BREW_DISABLED=php@8.1 run php_sh setup
  [ "$status" -eq 0 ]
  assert_log "brew tap shivammathur/php"
  assert_log "brew install shivammathur/php/php@8.1"
}
