# dnf, pacman and apk: one python package each, run as pythonX.Y.

setup() {
  load ../helpers
  common_setup
  export OS_RELEASE="$FIXTURES/os-release-fedora"
}

@test "dnf: a side-by-side minor installs python3.Y" {
  export PYTHON_BACKEND=dnf
  echo 3.12 >"$PROJECT_DIR/.python-version"
  fake_python "$STUB_BIN/python3.12" 3.12.16
  run python_sh setup
  [ "$status" -eq 0 ]
  assert_log "dnf install -y python3.12"
  [[ "$output" == *"✓ ssl, sqlite3, venv and ensurepip present"* ]]
}

@test "dnf: the system minor installs python3" {
  export PYTHON_BACKEND=dnf
  echo 3.14 >"$PROJECT_DIR/.python-version"
  fake_python "$STUB_BIN/python3.14" 3.14.10
  run python_sh setup
  [ "$status" -eq 0 ]
  assert_log "dnf install -y python3"
  run ! grep -q 'dnf install -y python3.14' "$STUB_LOG"
}

@test "dnf: lists side-by-side and system minors, without prereleases or -devel" {
  export PYTHON_BACKEND=dnf
  echo 3.99 >"$PROJECT_DIR/.python-version"
  run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"python 3.99 is not available via dnf (have: 3.9 3.10 3.11 3.12 3.13 3.14 3.15); uv installs"* ]]
}

@test "dnf: check runs python3.Y" {
  export PYTHON_BACKEND=dnf
  echo 3.12 >"$PROJECT_DIR/.python-version"
  fake_python "$STUB_BIN/python3.12" 3.12.16
  run python_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          3.12.16 ✓"* ]]
}

@test "pacman: installs python when the pin is Arch's minor" {
  export PYTHON_BACKEND=pacman
  echo 3.14 >"$PROJECT_DIR/.python-version"
  fake_python "$STUB_BIN/python3.14" 3.14.10
  run python_sh setup
  [ "$status" -eq 0 ]
  assert_log "pacman -S --needed --noconfirm python"
}

@test "pacman: any other minor fails, pointing at uv" {
  export PYTHON_BACKEND=pacman
  echo 3.12 >"$PROJECT_DIR/.python-version"
  run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"python 3.12 is not available via pacman (have: 3.14); uv installs any minor without sudo"* ]] || false
  run ! grep -q 'pacman -S ' "$STUB_LOG"
}

@test "apk: installs python3 when the pin is the release's minor" {
  export PYTHON_BACKEND=apk
  echo 3.12 >"$PROJECT_DIR/.python-version"
  fake_python "$STUB_BIN/python3.12" 3.12.16
  STUB_UID=1000 run python_sh setup
  [ "$status" -eq 0 ]
  assert_log "sudo apk --no-cache add python3"
}

@test "apk: any other minor fails, pointing at uv" {
  export PYTHON_BACKEND=apk
  echo 3.13 >"$PROJECT_DIR/.python-version"
  run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"python 3.13 is not available via apk (have: 3.12); uv installs any minor without sudo"* ]]
}

@test "apk: a patch pin works, with the minor-backend warning" {
  export PYTHON_BACKEND=apk
  echo 3.12.1 >"$PROJECT_DIR/.python-version"
  fake_python "$STUB_BIN/python3.12" 3.12.16
  run python_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"apk can't pin patches; installed 3.12.16 for pin 3.12.1"* ]]
}
