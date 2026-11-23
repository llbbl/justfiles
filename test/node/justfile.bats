# The module as a consumer uses it: vendored repo + `mod node` in their justfile.

setup() {
  load ../helpers
  common_setup
  export STUB_UNAME=Darwin
  mkdir -p "$PROJECT_DIR/vendor"
  ln -s "$REPO" "$PROJECT_DIR/vendor/justfiles"
  printf "mod node 'vendor/justfiles/node/node.justfile'\n" >"$PROJECT_DIR/justfile"
  echo 22.11.0 >"$PROJECT_DIR/.nvmrc"
  mise_installed node 22.11.0
  cd "$PROJECT_DIR" || return
}

@test "just node lists the module's recipes" {
  run just node
  [ "$status" -eq 0 ]
  [[ "$output" == *"bump VERSION"* ]] || false
  [[ "$output" == *"floor"* ]]
}

@test "recipes read the pin from the consumer project" {
  run just node version
  [ "$status" -eq 0 ]
  [ "$output" = "v22.11.0" ]
}

@test "bump passes its argument through and writes the consumer's pin" {
  run just node bump 24
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.nvmrc")" = 24 ]
}
