setup() {
  load ../helpers
  common_setup
  . "$REPO/lib/common.sh"
  . "$REPO/lib/pin.sh"
  cd "$PROJECT_DIR" || return
}

@test "pin_read skips comments and blanks, strips v" {
  printf '# pinned\n\n  v8.5.7  \n' >.php-version
  run pin_read .php-version
  [ "$output" = 8.5.7 ]
}

@test "pin_read fails on missing or empty file" {
  run pin_read .php-version
  [ "$status" -ne 0 ]
  : >.php-version
  run pin_read .php-version
  [ "$status" -ne 0 ]
}

# Each form is its own test: bats ignores failures before the last command of an && list.
@test "mise_pin reads the string form" {
  printf '[tools]\nphp = "8.5.7"\n' >mise.toml
  mise_pin php
  [ "$MISE_PIN" = 8.5.7 ]
  [ "$MISE_PIN_FILE" = mise.toml ]
}

@test "mise_pin reads the table form, version first or not" {
  printf '[tools]\nphp = { version = "8.4.1", postinstall = "x" }\n' >mise.toml
  mise_pin php
  [ "$MISE_PIN" = 8.4.1 ]
  printf '[tools]\nphp = { postinstall = "composer install", version = "8.4.2" }\n' >mise.toml
  mise_pin php
  [ "$MISE_PIN" = 8.4.2 ]
}

@test "mise_pin reads the first entry of an array" {
  printf "[tools]\nphp = ['8.3.0', '8.2.0']\n" >mise.toml
  mise_pin php
  [ "$MISE_PIN" = 8.3.0 ]
}

@test "mise_pin ignores 'version =' in a comment after a string pin" {
  printf '[tools]\nphp = "8.5.7" # version = bumped by ops\n' >mise.toml
  mise_pin php
  [ "$MISE_PIN" = 8.5.7 ]
}

@test "mise_pin reads a quoted key and strips v" {
  printf '[tools]\n"php" = "v8.5.10"\n' >mise.toml
  mise_pin php
  [ "$MISE_PIN" = 8.5.10 ]
}

@test "mise_pin and pin_read handle CRLF files" {
  printf '[tools]\r\nphp = "8.5.7"\r\n' >mise.toml
  printf '8.5.7\r\n' >.php-version
  mise_pin php
  [ "$MISE_PIN" = 8.5.7 ]
  [ "$(pin_read .php-version)" = 8.5.7 ]
}

@test "mise_pin ignores other tables and similarly named tools" {
  printf '[env]\nphp = "1.0.0"\n[tools]\nphpstan = "2.0.0"\nnode = "22"\n' >mise.toml
  run mise_pin php
  [ "$status" -ne 0 ]
}

@test "mise_pin falls back to .mise.toml" {
  printf '[tools]\nphp = "8.5.7"\n' >.mise.toml
  mise_pin php
  [ "$MISE_PIN_FILE" = .mise.toml ]
}

@test "pin_get returns the pin when mise agrees or is absent" {
  echo 8.5.7 >.php-version
  run pin_get php .php-version
  [ "$output" = 8.5.7 ]
  printf '[tools]\nphp = "8.5.7"\n' >mise.toml
  run pin_get php .php-version
  [ "$status" -eq 0 ]
  [ "$output" = 8.5.7 ]
}

@test "pin_get dies on mismatch, naming both files" {
  echo 8.5.7 >.php-version
  printf '[tools]\nphp = "8.4.1"\n' >mise.toml
  run pin_get php .php-version
  [ "$status" -ne 0 ]
  [[ "$output" == *".php-version says php 8.5.7"* ]]
  [[ "$output" == *"mise.toml says 8.4.1"* ]]
}

@test "pin_get treats a prefix as a mismatch" {
  echo 8.5 >.php-version
  printf '[tools]\nphp = "8.5.7"\n' >mise.toml
  run pin_get php .php-version
  [ "$status" -ne 0 ]
}

@test "pin_get without a pin file suggests the mise value" {
  printf '[tools]\nphp = "8.5.7"\n' >mise.toml
  run pin_get php .php-version
  [ "$status" -ne 0 ]
  [[ "$output" == *"echo 8.5.7 > .php-version"* ]]
}

@test "pin_get without any pin suggests bump" {
  run pin_get php .php-version
  [ "$status" -ne 0 ]
  [[ "$output" == *"just php bump"* ]]
}

@test "pin_write updates the mise pin and nothing else" {
  echo 8.5.7 >.php-version
  printf '# top\n[tools]\nnode = "22"\nphp = "8.5.7" # keep\n\n[env]\nphp = "x"\n' >mise.toml
  pin_write php .php-version 8.5.10
  [ "$(cat .php-version)" = 8.5.10 ]
  [ "$(cat mise.toml)" = "$(printf '# top\n[tools]\nnode = "22"\nphp = "8.5.10" # keep\n\n[env]\nphp = "x"')" ]
}

@test "pin_write changes the version key of a table, not the first string" {
  printf '[tools]\nphp = { postinstall = "composer install", version = "8.4.1" }\n' >mise.toml
  pin_write php .php-version 8.4.15
  [ "$(cat mise.toml)" = "$(printf '[tools]\nphp = { postinstall = "composer install", version = "8.4.15" }')" ]
}

@test "pin_write updates a string pin followed by a 'version =' comment" {
  printf '[tools]\nphp = "8.5.7" # version = bumped by ops\n' >mise.toml
  pin_write php .php-version 8.5.10
  [ "$(cat mise.toml)" = "$(printf '[tools]\nphp = "8.5.10" # version = bumped by ops')" ]
}

@test "pin_write keeps CRLF line endings" {
  printf '[tools]\r\nphp = "8.5.7"\r\n' >mise.toml
  pin_write php .php-version 8.5.10
  [ "$(cat mise.toml)" = "$(printf '[tools]\r\nphp = "8.5.10"\r')" ]
}

@test "pin_write does not create a mise file" {
  pin_write php .php-version 8.5.10
  [ "$(cat .php-version)" = 8.5.10 ]
  [ ! -e mise.toml ]
}
