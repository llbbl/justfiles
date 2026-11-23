setup() {
  load ../helpers
  common_setup
  export PHP_BACKEND=apk
  echo 8.4 >"$PROJECT_DIR/.php-version"
  fake_php "$STUB_BIN/php84" 8.4.27
}

@test "setup: installs phpNN, the extension set and openssl" {
  run php_sh setup
  [ "$status" -eq 0 ]
  assert_log "apk --no-cache add php84 php84-common php84-curl php84-mbstring php84-xml php84-zip php84-intl php84-gd php84-opcache php84-openssl"
  [[ "$output" == *"✓ openssl extension present"* ]]
}

@test "setup: goes through sudo when not root" {
  STUB_UID=1000 run php_sh setup
  [ "$status" -eq 0 ]
  assert_log "sudo apk --no-cache add php84"
}

@test "setup: a minor this release lacks fails, naming what it has" {
  echo 8.5 >"$PROJECT_DIR/.php-version"
  run php_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"php 8.5 is not available via apk (have: 8.2 8.3 8.4); other Alpine releases ship other minors"* ]] || false
  run ! grep -q ' add ' "$STUB_LOG"
}

@test "check: runs the phpNN binary" {
  run php_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          8.4.27 ✓"* ]]
}
