setup() {
  load ../helpers
  common_setup
  export PYTHON_BACKEND=brew STUB_BREW_PREFIX="$BATS_TEST_TMPDIR/brew"
  echo 3.13 >"$PROJECT_DIR/.python-version"
  fake_python "$STUB_BREW_PREFIX/opt/python@3.13/bin/python3.13" 3.13.9
}

@test "setup: installs python@X.Y" {
  run python_sh setup
  [ "$status" -eq 0 ]
  assert_log "brew install python@3.13"
  [[ "$output" == *"✓ ssl, sqlite3, venv and ensurepip present"* ]]
}

@test "setup: a minor core lacks fails, pointing at uv" {
  echo 3.8 >"$PROJECT_DIR/.python-version"
  run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"python 3.8 is not available via brew (have: 3.10 3.11 3.12 3.13 3.14); uv installs any minor without sudo"* ]] || false
  run ! grep -q 'brew install' "$STUB_LOG"
}

@test "check: runs the formula's python3.Y" {
  run python_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          3.13.9 ✓"* ]]
}

@test "check: names the formula when it isn't installed" {
  echo 3.12 >"$PROJECT_DIR/.python-version"
  run python_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *"python@3.12 is not installed: run  just python setup"* ]]
}

@test "latest: compares minors" {
  run python_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"→ newer minor: 3.14, run: just python bump 3.14"* ]]
}
