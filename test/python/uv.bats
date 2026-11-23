setup() {
  load ../helpers
  common_setup
  export PYTHON_BACKEND=uv
  echo 3.13 >"$PROJECT_DIR/.python-version"
}

@test "setup: uv installs the pin and the checks pass" {
  run python_sh setup
  [ "$status" -eq 0 ]
  assert_log "uv python install 3.13"
  [[ "$output" == *"Python 3.13.18"* ]] || false
  [[ "$output" == *"✓ ssl, sqlite3, venv and ensurepip present"* ]]
}

@test "setup: never uses sudo, even when not root" {
  STUB_UID=1000 run python_sh setup
  [ "$status" -eq 0 ]
  run ! grep -q '^sudo' "$STUB_LOG"
}

@test "check: finds only uv's own install" {
  python_sh setup
  run python_sh check
  [ "$status" -eq 0 ]
  assert_log "uv python find --python-preference only-managed 3.13"
  [[ "$output" == *"installed:          3.13.18 ✓"* ]]
}

@test "check: says so when uv hasn't installed the pin" {
  run python_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *"python 3.13 is not installed: run  just python setup"* ]]
}

@test "latest: lists CPython only, without free-threaded builds or prereleases" {
  echo 3.13.9 >"$PROJECT_DIR/.python-version"
  run python_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"latest stable 3.13.x:     3.13.18"* ]] || false
  [[ "$output" == *"latest stable overall:  3.15.2"* ]]
}

@test "bump: an exact patch the list has" {
  run python_sh bump 3.12.12
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.python-version")" = 3.12.12 ]
}

@test "bump: a PyPy-only version is not available" {
  run python_sh bump 3.11.13
  [ "$status" -ne 0 ]
  [[ "$output" == *"version 3.11.13 is not available via uv"* ]]
}

@test "bump: reports a failed version listing" {
  STUB_UV_FAIL=1 run python_sh bump 3.14
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not list python versions via uv"* ]]
}

@test "setup: an X.Y pin keeps the patch uv already installed" {
  uv python install 3.13.9
  run python_sh setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"Python 3.13.9"* ]] || false
  [ ! -d "$STUB_ROOT/uv/3.13.18" ]
}

@test "bump: an X.Y pin is left alone, and says how to pin a patch" {
  run python_sh bump
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ an X.Y pin accepts any installed 3.13.x; nothing to bump (just python bump 3.13.N to pin a patch)"* ]] || false
  [ "$(cat "$PROJECT_DIR/.python-version")" = 3.13 ]
}
