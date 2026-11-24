setup() {
  load ../helpers
  common_setup
  export NODE_BACKEND=brew STUB_BREW_PREFIX="$BATS_TEST_TMPDIR/brew"
  echo 24 >"$PROJECT_DIR/.nvmrc"
  fake_node "$STUB_BREW_PREFIX/opt/node@24/bin/node" 24.22.3
}

@test "setup: installs node@N" {
  run node_sh setup
  [ "$status" -eq 0 ]
  assert_log "brew install node@24"
  [[ "$output" == *"✓ npm present"* ]]
}

@test "setup: a major Homebrew lacks fails, naming what it has" {
  echo 18 >"$PROJECT_DIR/.nvmrc"
  run node_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"node 18 is not available via brew (have: 20 22 24 26)"* ]] || false
  run ! grep -q 'brew install' "$STUB_LOG"
}

@test "check: an exact pin works, with the major-backend warning" {
  echo 24.0.0 >"$PROJECT_DIR/.nvmrc"
  run node_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew can't pin minors or patches; installed 24.22.3 for pin 24.0.0"* ]] || false
  [[ "$output" == *"installed:          24.22.3 ✓"* ]]
}

@test "check: the formula not installed says to run setup" {
  echo 22 >"$PROJECT_DIR/.nvmrc"
  run node_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *"node@22 is not installed: run  just node setup"* ]]
}

@test "latest and bump work in majors" {
  run node_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"→ newer LTS major: 26, run: just node bump 26"* ]] || false
  run node_sh bump
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ brew tracks the newest 24.x itself; nothing to bump"* ]] || false
  run node_sh bump 22.1.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew can't pin minors or patches; setup installs the newest 22.x"* ]] || false
  [ "$(cat "$PROJECT_DIR/.nvmrc")" = 22.1.0 ]
}

@test "latest: a newer major that isn't LTS yet is shown, not recommended" {
  STUB_TODAY=2026-06-01 run node_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"newest LTS via brew: 24"* ]] || false
  [[ "$output" == *"newest via brew:     26 (not LTS)"* ]] || false
  [[ "$output" == *"✓ pin is the newest LTS major brew has"* ]]
}
