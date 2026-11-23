# The module as a consumer uses it: vendored repo + `mod python` in their justfile.

setup() {
  load ../helpers
  common_setup
  export STUB_UNAME=Darwin
  mkdir -p "$PROJECT_DIR/vendor"
  ln -s "$REPO" "$PROJECT_DIR/vendor/justfiles"
  printf "mod python 'vendor/justfiles/python/python.justfile'\n" >"$PROJECT_DIR/justfile"
  echo 3.13.9 >"$PROJECT_DIR/.python-version"
  mise_installed python 3.13.9
  cd "$PROJECT_DIR" || return
}

@test "just python lists the module's recipes" {
  run just python
  [ "$status" -eq 0 ]
  [[ "$output" == *"bump VERSION"* ]] || false
  [[ "$output" == *"floor"* ]]
}

@test "recipes read the pin from the consumer project" {
  run just python version
  [ "$status" -eq 0 ]
  [ "$output" = "Python 3.13.9" ]
}

@test "bump passes its argument through and writes the consumer's pin" {
  run just python bump 3.14
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.python-version")" = 3.14 ]
}
