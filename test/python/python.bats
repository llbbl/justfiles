setup() {
  load ../helpers
  common_setup
  export STUB_UNAME=Darwin
  echo 3.13.9 >"$PROJECT_DIR/.python-version"
}

@test "backend: macOS prefers mise, then uv, then brew" {
  run python_sh backend
  [ "$status" -eq 0 ]
  [ "$output" = "mise (first available of: mise uv brew)" ]
}

@test "backend: macOS without mise uses uv" {
  PATH="$(isolated_path uname uv brew)" run python_sh backend
  [ "$status" -eq 0 ]
  [ "$output" = "uv (first available of: mise uv brew)" ]
}

@test "backend: Linux uses mise too, then falls through in order" {
  STUB_UNAME=Linux run python_sh backend
  [ "$status" -eq 0 ]
  [ "$output" = "mise (first available of: mise uv brew apt dnf pacman apk)" ] || false
  STUB_UNAME=Linux PATH="$(isolated_path uname dnf apk)" run python_sh backend
  [ "$output" = "dnf (first available of: mise uv brew apt dnf pacman apk)" ]
}

@test "backend: PYTHON_BACKEND picks one explicitly" {
  PYTHON_BACKEND=uv run python_sh backend
  [ "$status" -eq 0 ]
  [ "$output" = "uv (set by PYTHON_BACKEND)" ]
}

@test "pin: PyPy is refused with a clear message" {
  echo pypy3.10 >"$PROJECT_DIR/.python-version"
  run python_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *".python-version pins 'pypy3.10': only CPython X.Y or X.Y.Z is supported"* ]]
}

@test "pin: a free-threaded build is refused before installing anything" {
  echo 3.13t >"$PROJECT_DIR/.python-version"
  run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"pins '3.13t'"* ]] || false
  run ! grep -q 'install' "$STUB_LOG"
}

@test "pin: the first line of a multi-version pyenv file is the pin" {
  printf '3.13.9\n3.12.12\n' >"$PROJECT_DIR/.python-version"
  mise_installed python 3.13.9
  run python_sh version
  [ "$status" -eq 0 ]
  [ "$output" = "Python 3.13.9" ]
}

@test "setup: installs with mise and checks ssl, sqlite3 and venv" {
  run python_sh setup
  [ "$status" -eq 0 ]
  assert_log "mise install python@3.13.9"
  [[ "$output" == *"Python 3.13.9"* ]] || false
  [[ "$output" == *"✓ ssl, sqlite3, venv and ensurepip present"* ]]
}

@test "setup: fails when a stdlib module is missing" {
  STUB_PYTHON_MISSING=ensurepip run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"No module named 'ensurepip'"* ]] || false
  [[ "$output" == *"python 3.13.9 is missing ssl, sqlite3, venv or ensurepip"* ]]
}

@test "setup: an X.Y pin installs that minor's newest patch" {
  echo 3.13 >"$PROJECT_DIR/.python-version"
  run python_sh setup
  [ "$status" -eq 0 ]
  assert_log "mise install python@3.13"
  [[ "$output" == *"Python 3.13.18"* ]] || false
  [[ "$output" != *"can't pin patches"* ]]
}

@test "check: passes when installed matches the pin" {
  mise_installed python 3.13.9
  printf '[tools]\npython = "3.13.9"\n' >"$PROJECT_DIR/mise.toml"
  run python_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          3.13.9 ✓"* ]]
}

@test "check: an X.Y pin accepts the newest installed patch" {
  echo 3.13 >"$PROJECT_DIR/.python-version"
  mise_installed python 3.13.0
  mise_installed python 3.13.9
  run python_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          3.13.9 ✓"* ]]
}

@test "check: fails when the pinned version is not installed" {
  run python_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *"python 3.13.9 is not installed: run  just python setup"* ]]
}

@test "check: warns when python3 on PATH isn't the pinned version" {
  mise_installed python 3.13.9
  fake_python "$STUB_BIN/python3" 3.12.1
  run python_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"python3 on PATH is 3.12.1, not 3.13.9: tools that run plain python3 (pip, venvs, IDEs) won't use the pinned one; see docs/python.md"* ]]
}

@test "check: no PATH warning when python3 on PATH is the pinned version" {
  mise_installed python 3.13.9
  fake_python "$STUB_BIN/python3" 3.13.9
  run python_sh check
  [ "$status" -eq 0 ]
  [[ "$output" != *"on PATH"* ]]
}

@test "latest: newest patch in the minor line, ignoring RCs and other pythons" {
  run python_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"latest stable 3.13.x:     3.13.18"* ]] || false
  [[ "$output" == *"latest stable overall:  3.15.2"* ]] || false
  [[ "$output" == *"newer 3.13.x stable: 3.13.18, run: just python bump"* ]]
}

@test "latest: an X.Y pin compares minors" {
  echo 3.13 >"$PROJECT_DIR/.python-version"
  run python_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"newest available via mise: 3.15"* ]] || false
  [[ "$output" == *"→ newer minor: 3.15, run: just python bump 3.15"* ]]
}

@test "latest: an X.Y pin on the newest minor is current" {
  echo 3.15 >"$PROJECT_DIR/.python-version"
  run python_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ pin is the newest minor mise has"* ]]
}

@test "bump: no argument pins the newest patch in the minor line" {
  run python_sh bump
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.python-version")" = 3.13.18 ]
}

@test "bump: no argument leaves an X.Y pin alone" {
  echo 3.13 >"$PROJECT_DIR/.python-version"
  run python_sh bump
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ an X.Y pin accepts any installed 3.13.x; nothing to bump (just python bump 3.13.N to pin a patch)"* ]] || false
  [ "$(cat "$PROJECT_DIR/.python-version")" = 3.13 ]
}

@test "bump: X.Y is accepted on a patch backend, without a warning" {
  printf '[tools]\npython = "3.13.9"\n' >"$PROJECT_DIR/mise.toml"
  run python_sh bump 3.14
  [ "$status" -eq 0 ]
  [[ "$output" != *"can't pin patches"* ]] || false
  [ "$(cat "$PROJECT_DIR/.python-version")" = 3.14 ]
  grep -Fxq 'python = "3.14"' "$PROJECT_DIR/mise.toml"
}

@test "bump: refuses a minor the backend lacks" {
  run python_sh bump 3.99
  [ "$status" -ne 0 ]
  [[ "$output" == *"version 3.99 is not available via mise"* ]] || false
  [ "$(cat "$PROJECT_DIR/.python-version")" = 3.13.9 ]
}

@test "bump: refuses prereleases and free-threaded versions" {
  run python_sh bump 3.15.0a1
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a stable X.Y or X.Y.Z version"* ]] || false
  run python_sh bump 3.13t
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a stable X.Y or X.Y.Z version"* ]]
}

@test "bump: without a pin file or version explains what to do" {
  rm "$PROJECT_DIR/.python-version"
  run python_sh bump
  [ "$status" -ne 0 ]
  [[ "$output" == *"just python bump <version>"* ]]
}

@test "floor: oldest branch not yet end of life" {
  run python_sh floor
  [ "$status" -eq 0 ]
  [[ "$output" == *"oldest supported 3.x:        3.11   (supported until 2027-10-31)"* ]] || false
  [[ "$output" == *"apply (supported floor): just python bump 3.11.14"* ]]
}

@test "version: runs the pinned binary without installing it" {
  mise_installed python 3.13.9
  run python_sh version
  [ "$status" -eq 0 ]
  [ "$output" = "Python 3.13.9" ] || false
  run ! grep -q 'mise install' "$STUB_LOG"
}

@test "setup: stops on a pin mismatch before installing anything" {
  printf '[tools]\npython = "3.12"\n' >"$PROJECT_DIR/mise.toml"
  run python_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"pin mismatch"* ]] || false
  run ! grep -q 'install' "$STUB_LOG"
}

@test "setup: an X.Y pin installs the newest patch even with an older one installed, as mise does" {
  echo 3.13 >"$PROJECT_DIR/.python-version"
  mise_installed python 3.13.9
  run python_sh setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"Python 3.13.18"* ]]
}
