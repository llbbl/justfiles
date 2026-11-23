# check/latest/bump on a backend that pins minors (apk here; they share this code).

setup() {
  load ../helpers
  common_setup
  export PHP_BACKEND=apk
  echo 8.3 >"$PROJECT_DIR/.php-version"
  fake_php "$STUB_BIN/php83" 8.3.36
}

@test "check: a minor pin passes without a warning" {
  run php_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          8.3.36 ✓"* ]] || false
  [[ "$output" != *"can't pin patches"* ]]
}

@test "check: a patch pin passes at minor granularity, with a warning" {
  echo 8.3.7 >"$PROJECT_DIR/.php-version"
  run php_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"apk can't pin patches; installed 8.3.36 for pin 8.3.7"* ]] || false
  [[ "$output" == *"installed:          8.3.36 ✓"* ]]
}

@test "check: a patch pin that happens to match does not warn" {
  echo 8.3.36 >"$PROJECT_DIR/.php-version"
  run php_sh check
  [ "$status" -eq 0 ]
  [[ "$output" != *"can't pin patches"* ]]
}

@test "setup: a patch pin warns after installing" {
  echo 8.3.7 >"$PROJECT_DIR/.php-version"
  run php_sh setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"apk can't pin patches; installed 8.3.36 for pin 8.3.7"* ]]
}

@test "latest: compares minors" {
  run php_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"pinned (.php-version):  8.3"* ]] || false
  [[ "$output" == *"newest available via apk: 8.4"* ]] || false
  [[ "$output" == *"→ newer minor: 8.4, run: just php bump 8.4"* ]]
}

@test "latest: reports when the pin is the newest minor" {
  echo 8.4.1 >"$PROJECT_DIR/.php-version"
  run php_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ pin is the newest minor apk has"* ]]
}

@test "bump: without a version leaves the pin alone" {
  run php_sh bump
  [ "$status" -eq 0 ]
  [[ "$output" == *"apk tracks the newest 8.3.x itself; nothing to bump"* ]] || false
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.3 ]
}

@test "bump: without a version still stops on a mismatch" {
  printf '[tools]\nphp = "8.4"\n' >"$PROJECT_DIR/mise.toml"
  run php_sh bump
  [ "$status" -ne 0 ]
  [[ "$output" == *"pin mismatch"* ]]
}

@test "bump: X.Y writes a minor pin" {
  run php_sh bump 8.4
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.4 ]
}

@test "bump: X.Y.Z is accepted for a mixed team, with a warning" {
  printf '[tools]\nphp = "8.3"\n' >"$PROJECT_DIR/mise.toml"
  run php_sh bump 8.4.2
  [ "$status" -eq 0 ]
  [[ "$output" == *"apk can't pin patches; setup installs the newest 8.4.x"* ]] || false
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.4.2 ]
  grep -Fxq 'php = "8.4.2"' "$PROJECT_DIR/mise.toml"
}

@test "bump: refuses a minor the backend lacks" {
  run php_sh bump 8.5
  [ "$status" -ne 0 ]
  [[ "$output" == *"version 8.5 is not available via apk"* ]] || false
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.3 ]
}

@test "bump: still refuses release candidates" {
  run php_sh bump 8.4.0RC1
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a stable X.Y or X.Y.Z version"* ]]
}

@test "bump: an unlisted minor explains how to pin before setup adds the repo" {
  run php_sh bump 8.9
  [ "$status" -ne 0 ]
  [[ "$output" == *"echo 8.9 > .php-version && just php setup"* ]]
}

@test "check: warns when php on PATH isn't the pinned version" {
  fake_php "$STUB_BIN/php" 8.2.1
  run php_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"php on PATH is 8.2.1, not 8.3"* ]]
}

@test "check: no PATH warning when php on PATH is the pinned version" {
  fake_php "$STUB_BIN/php" 8.3.36
  run php_sh check
  [ "$status" -eq 0 ]
  [[ "$output" != *"php on PATH"* ]]
}
