# The module as a consumer uses it: vendored repo + `mod php` in their justfile.

setup() {
  load ../helpers
  common_setup
  mkdir -p "$PROJECT_DIR/vendor"
  ln -s "$REPO" "$PROJECT_DIR/vendor/justfiles"
  printf "mod php 'vendor/justfiles/php/php.justfile'\n" >"$PROJECT_DIR/justfile"
  echo 8.5.7 >"$PROJECT_DIR/.php-version"
  mise_installed php 8.5.7
  cd "$PROJECT_DIR" || return
}

@test "just php lists the module's recipes, not the vendored repo's" {
  run just php
  [ "$status" -eq 0 ]
  [[ "$output" == *"bump VERSION"* ]]
  [[ "$output" == *"floor"* ]]
}

@test "just <name> lists recipes when the module is imported under another name" {
  printf "mod tools 'vendor/justfiles/php/php.justfile'\n" >"$PROJECT_DIR/justfile"
  run just tools
  [ "$status" -eq 0 ]
  [[ "$output" == *"bump VERSION"* ]]
}

@test "recipes read the pin from the consumer project" {
  run just php version
  [ "$status" -eq 0 ]
  [[ "$output" == "PHP 8.5.7 (cli)"* ]]
}

@test "works when invoked from a subdirectory" {
  mkdir -p sub && cd sub
  run just php version
  [ "$status" -eq 0 ]
  [[ "$output" == "PHP 8.5.7 (cli)"* ]]
}

@test "bump passes its argument through and writes the consumer's pin" {
  run just php bump 8.4.15
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.php-version")" = 8.4.15 ]
}
