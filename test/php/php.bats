setup() {
  load ../helpers
  common_setup
  echo 8.5.7 >"$PROJECT_DIR/.php-version"
}

@test "backend: defaults to mise" {
  run php_sh backend
  [ "$status" -eq 0 ]
  [ "$output" = "mise (first available of: mise)" ]
}

@test "backend: PHP_BACKEND naming an unknown backend fails" {
  PHP_BACKEND=nope run php_sh backend
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown backend: nope"* ]]
}

@test "latest: picks the newest patch numerically, ignoring RCs" {
  run php_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"latest stable 8.5.x:     8.5.10"* ]]
  [[ "$output" == *"newer 8.5.x stable: 8.5.10"* ]]
}

@test "latest: reports when the pin is current" {
  echo 8.5.10 >"$PROJECT_DIR/.php-version"
  run php_sh latest
  [[ "$output" == *"✓ pin is the latest 8.5.x stable"* ]]
}

@test "latest: stops on a pin mismatch" {
  printf '[tools]\nphp = "8.4.1"\n' >"$PROJECT_DIR/mise.toml"
  run php_sh latest
  [ "$status" -ne 0 ]
  [[ "$output" == *"pin mismatch"* ]]
}

@test "bump: no argument pins the newest patch in the minor line" {
  run php_sh bump
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.5.10 ]
}

@test "bump: also updates mise.toml when it pins php" {
  printf '[tools]\nphp = "8.5.7"\n' >"$PROJECT_DIR/mise.toml"
  run php_sh bump 8.4.15
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.4.15 ]
  grep -Fxq 'php = "8.4.15"' "$PROJECT_DIR/mise.toml"
}

@test "bump: an explicit version repairs a pin mismatch" {
  printf '[tools]\nphp = "8.4.1"\n' >"$PROJECT_DIR/mise.toml"
  run php_sh bump 8.5.10
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.5.10 ]
  grep -Fxq 'php = "8.5.10"' "$PROJECT_DIR/mise.toml"
}

@test "bump: repairs mise.toml even when .php-version already has the version" {
  printf '[tools]\nphp = "8.4.1"\n' >"$PROJECT_DIR/mise.toml"
  run php_sh bump 8.5.7
  [ "$status" -eq 0 ]
  grep -Fxq 'php = "8.5.7"' "$PROJECT_DIR/mise.toml"
  [[ "$output" != *".php-version: php 8.5.7 → 8.5.7"* ]]
}

@test "bump: no-op when both files already have the version" {
  printf '[tools]\nphp = "8.5.7"\n' >"$PROJECT_DIR/mise.toml"
  before="$(ls -li "$PROJECT_DIR/mise.toml" "$PROJECT_DIR/.php-version"; cat "$PROJECT_DIR/mise.toml")"
  run php_sh bump 8.5.7
  [ "$status" -eq 0 ]
  [[ "$output" == *"already pinned to 8.5.7"* ]]
  [[ "$output" != *"→"* ]]
  [ "$before" = "$(ls -li "$PROJECT_DIR/mise.toml" "$PROJECT_DIR/.php-version"; cat "$PROJECT_DIR/mise.toml")" ]
}

@test "bump: without a version still stops on a mismatch" {
  printf '[tools]\nphp = "8.4.1"\n' >"$PROJECT_DIR/mise.toml"
  run php_sh bump
  [ "$status" -ne 0 ]
  [[ "$output" == *"pin mismatch"* ]]
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.5.7 ]
}

@test "bump: refuses release candidates without listing versions" {
  run php_sh bump 8.5.11RC1
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a stable X.Y.Z version"* ]]
  run ! grep -q 'ls-remote' "$STUB_LOG"
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.5.7 ]
}

@test "bump: refuses versions the backend does not have" {
  run php_sh bump 8.5.99
  [ "$status" -ne 0 ]
  [[ "$output" == *"not available via mise"* ]]
}

@test "bump: no-op when already current" {
  run php_sh bump 8.5.7
  [ "$status" -eq 0 ]
  [[ "$output" == *"already pinned to 8.5.7"* ]]
}

@test "bump: creates the pin file from an explicit version" {
  rm "$PROJECT_DIR/.php-version"
  run php_sh bump v8.4.15
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.4.15 ]
}

@test "bump: an empty pin file can be fixed with an explicit version" {
  : >"$PROJECT_DIR/.php-version"
  run php_sh bump 8.4.15
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.4.15 ]
}

@test "bump: refuses a multi-line version" {
  run php_sh bump "$(printf '8.5.10\nfoo')"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a stable X.Y.Z version"* ]]
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.5.7 ]
}

@test "bump: reports a failed version listing instead of a bad version" {
  STUB_MISE_FAIL=ls-remote run php_sh bump
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not list php versions via mise"* ]]
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.5.7 ]
}

@test "bump: without a pin file or version explains what to do" {
  rm "$PROJECT_DIR/.php-version"
  run php_sh bump
  [ "$status" -ne 0 ]
  [[ "$output" == *"just php bump <version>"* ]]
}

@test "floor: oldest branch still in active support" {
  run php_sh floor
  [ "$status" -eq 0 ]
  [[ "$output" == *"oldest active-support 8.x:   8.4   (active support until 2026-12-31)"* ]]
  [[ "$output" == *"just php bump 8.4.15"* ]]
}

@test "check: passes when installed matches the pin" {
  mise_installed php 8.5.7
  printf '[tools]\nphp = "8.5.7"\n' >"$PROJECT_DIR/mise.toml"
  run php_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          8.5.7 ✓"* ]]
}

@test "check: fails when the pinned version is not installed" {
  run php_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *"just php setup"* ]]
}

@test "version: shows mise's own error, not just 'not installed'" {
  STUB_MISE_FAIL=where run php_sh version
  [ "$status" -ne 0 ]
  [[ "$output" == *"mise ERROR fake failure: where"* ]]
}

@test "version: runs the pinned binary without installing it" {
  mise_installed php 8.5.7
  run php_sh version
  [ "$status" -eq 0 ]
  [[ "$output" == "PHP 8.5.7 (cli)"* ]]
  ! grep -q 'mise install' "$STUB_LOG"
}

@test "setup: mise backend refuses Linux for now" {
  run php_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"only knows macOS build deps"* ]]
}

@test "setup: macOS builds against openssl@3 and verifies the extension" {
  export STUB_UNAME=Darwin
  run php_sh setup
  [ "$status" -eq 0 ]
  assert_log "brew install openssl@3 gd icu4c libzip oniguruma libxml2 libiconv"
  assert_log "mise install php@8.5.7"
  assert_log "PHP_CONFIGURE_OPTIONS=--with-openssl=/opt/homebrew/opt/openssl@3 --with-iconv=/opt/homebrew/opt/libiconv"
  [[ "$output" == *"✓ openssl extension present"* ]]
}

@test "setup: fails when the openssl extension is missing" {
  export STUB_UNAME=Darwin STUB_PHP_MODULES='Core\nzip'
  run php_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"openssl extension MISSING"* ]]
}

@test "setup: stops on a pin mismatch before installing anything" {
  export STUB_UNAME=Darwin
  printf '[tools]\nphp = "8.4.1"\n' >"$PROJECT_DIR/mise.toml"
  run php_sh setup
  [ "$status" -ne 0 ]
  ! grep -q 'install' "$STUB_LOG"
}

@test "requires PROJECT_DIR" {
  PROJECT_DIR='' run php_sh version
  [ "$status" -ne 0 ]
  [[ "$output" == *"PROJECT_DIR is not set"* ]]
}
