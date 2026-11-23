setup() {
  load ../helpers
  common_setup
  export PHP_BACKEND=pacman
  echo 8.5 >"$PROJECT_DIR/.php-version"
}

@test "setup: the newest minor is php, plus php-gd, with gd and intl enabled" {
  fake_php "$STUB_BIN/php" 8.5.13
  run php_sh setup
  [ "$status" -eq 0 ]
  assert_log "pacman -S --needed --noconfirm php php-gd"
  [ "$(cat "$STUB_ROOT/etc/php/conf.d/justfiles.ini")" = "$(printf 'extension=gd\nextension=intl')" ]
}

@test "setup: the older minor is php-legacy" {
  echo 8.3 >"$PROJECT_DIR/.php-version"
  fake_php "$STUB_BIN/php-legacy" 8.3.37
  run php_sh setup
  [ "$status" -eq 0 ]
  assert_log "pacman -S --needed --noconfirm php-legacy php-legacy-gd"
  [ -f "$STUB_ROOT/etc/php-legacy/conf.d/justfiles.ini" ]
}

@test "setup: any other minor fails, naming the two Arch has" {
  echo 8.4 >"$PROJECT_DIR/.php-version"
  run php_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"php 8.4 is not available via pacman (have: 8.3 8.5); Homebrew can install other minors"* ]] || false
  run ! grep -q 'pacman -S ' "$STUB_LOG"
}

@test "check: picks the installed package whose minor matches" {
  printf 'php 8.5.13-1\nphp-legacy 8.3.37-1\n' >"$STUB_ROOT/pacman-local"
  fake_php "$STUB_BIN/php-legacy" 8.3.37
  echo 8.3 >"$PROJECT_DIR/.php-version"
  run php_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          8.3.37 ✓"* ]]
}

@test "check: says so when the minor isn't installed" {
  printf 'php 8.5.13-1\n' >"$STUB_ROOT/pacman-local"
  echo 8.3 >"$PROJECT_DIR/.php-version"
  run php_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *"php 8.3 is not installed: run  just php setup"* ]]
}

@test "latest: compares minors from the sync database" {
  echo 8.3 >"$PROJECT_DIR/.php-version"
  run php_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"newest available via pacman: 8.5"* ]]
}

@test "setup: enables only the modules php.ini doesn't already load" {
  fake_php "$STUB_BIN/php" 8.5.13
  STUB_PHP_MODULES='Core\ngd\nopenssl' run php_sh setup
  [ "$status" -eq 0 ]
  [ "$(cat "$STUB_ROOT/etc/php/conf.d/justfiles.ini")" = "extension=intl" ]
}

@test "setup: writes no ini when gd and intl are already loaded" {
  fake_php "$STUB_BIN/php" 8.5.13
  STUB_PHP_MODULES='Core\ngd\nintl\nopenssl' run php_sh setup
  [ "$status" -eq 0 ]
  [ ! -e "$STUB_ROOT/etc/php/conf.d/justfiles.ini" ]
}
