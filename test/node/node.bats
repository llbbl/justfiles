setup() {
  load ../helpers
  common_setup
  export STUB_UNAME=Darwin
  echo 22.11.0 >"$PROJECT_DIR/.nvmrc"
}

@test "backend: macOS prefers mise, then nvm, fnm and brew" {
  run node_sh backend
  [ "$status" -eq 0 ]
  [ "$output" = "mise (first available of: mise nvm fnm brew)" ]
}

@test "backend: Linux falls through to the distro's package manager" {
  STUB_UNAME=Linux PATH="$(isolated_path uname pacman apk)" run node_sh backend
  [ "$status" -eq 0 ]
  [ "$output" = "pacman (first available of: mise nvm fnm brew apt dnf pacman apk)" ]
}

@test "backend: NODE_BACKEND picks one explicitly" {
  NODE_BACKEND=fnm run node_sh backend
  [ "$status" -eq 0 ]
  [ "$output" = "fnm (set by NODE_BACKEND)" ]
}

@test "pin: aliases like lts/* are refused with a clear message" {
  echo 'lts/*' >"$PROJECT_DIR/.nvmrc"
  run node_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *".nvmrc pins 'lts/*': only a major (22) or an exact version (22.11.0) is supported"* ]]
}

@test "pin: X.Y is refused, since node lines are majors" {
  echo 22.11 >"$PROJECT_DIR/.nvmrc"
  run node_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"pins '22.11'"* ]] || false
  run ! grep -q 'install' "$STUB_LOG"
}

@test "pin: a leading v, as nvm writes it, is dropped" {
  echo v22.11.0 >"$PROJECT_DIR/.nvmrc"
  mise_installed node 22.11.0
  run node_sh version
  [ "$status" -eq 0 ]
  [ "$output" = "v22.11.0" ]
}

@test "setup: installs with mise and checks npm" {
  run node_sh setup
  [ "$status" -eq 0 ]
  assert_log "mise install node@22.11.0"
  [[ "$output" == *"v22.11.0"* ]] || false
  [[ "$output" == *"✓ npm present"* ]]
}

@test "setup: fails when npm is missing" {
  STUB_NODE_NO_NPM=1 run node_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"node 22.11.0 has no npm next to it"* ]]
}

@test "setup: a bare major installs that major's newest release" {
  echo 22 >"$PROJECT_DIR/.nvmrc"
  run node_sh setup
  [ "$status" -eq 0 ]
  assert_log "mise install node@22"
  [[ "$output" == *"v22.23.5"* ]] || false
  [[ "$output" != *"can't pin"* ]]
}

@test "check: passes when installed matches the pin and mise.toml" {
  mise_installed node 22.11.0
  printf '[tools]\nnode = "22.11.0"\n' >"$PROJECT_DIR/mise.toml"
  run node_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          22.11.0 ✓"* ]]
}

@test "check: a bare major accepts any installed release of it" {
  echo 22 >"$PROJECT_DIR/.nvmrc"
  mise_installed node 22.11.0
  run node_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          22.11.0 ✓"* ]]
}

@test "check: pin 2 doesn't match an installed 22" {
  echo 2 >"$PROJECT_DIR/.nvmrc"
  fake_node "$STUB_BIN/node" 22.23.5
  NODE_BACKEND=apk run node_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *"installed node 22.23.5 does not match pin 2"* ]]
}

@test "check: warns when node on PATH isn't the pinned version" {
  mise_installed node 22.11.0
  fake_node "$STUB_BIN/node" 20.19.5
  run node_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"node on PATH is 20.19.5, not 22.11.0: tools that run plain node (npm, pnpm, IDEs) won't use the pinned one; see docs/node.md"* ]]
}

@test "latest: newest release in the pinned major, ignoring prereleases" {
  run node_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"latest stable 22.x:     22.23.5"* ]] || false
  [[ "$output" == *"latest stable overall:  26.13.1"* ]] || false
  [[ "$output" == *"newer 22.x stable: 22.23.5, run: just node bump"* ]]
}

@test "latest: a bare major is compared with the newest LTS major" {
  echo 22 >"$PROJECT_DIR/.nvmrc"
  run node_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"newest LTS via mise: 26"* ]] || false
  [[ "$output" != *"not LTS"* ]] || false
  [[ "$output" == *"→ newer LTS major: 26, run: just node bump 26"* ]]
}

@test "latest: skips odd majors and an even one before its LTS date" {
  echo 22 >"$PROJECT_DIR/.nvmrc"
  STUB_TODAY=2026-06-01 run node_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"newest LTS via mise: 24"* ]] || false
  [[ "$output" == *"newest via mise:     26 (not LTS)"* ]] || false
  [[ "$output" == *"→ newer LTS major: 24, run: just node bump 24"* ]]
}

@test "latest: a pin past the newest LTS major is left alone" {
  echo 25 >"$PROJECT_DIR/.nvmrc"
  STUB_TODAY=2026-06-01 run node_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ pin 25 is newer than the newest LTS major (24)"* ]]
}

@test "latest: without endoflife.date, warns and compares all majors" {
  echo 22 >"$PROJECT_DIR/.nvmrc"
  STUB_CURL_FAIL=1 run node_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"couldn't read LTS majors from endoflife.date (needs jq and network); comparing all majors"* ]] || false
  [[ "$output" == *"→ newer major: 26, run: just node bump 26"* ]]
}

@test "bump: no argument pins the newest release in the major" {
  run node_sh bump
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.nvmrc")" = 22.23.5 ]
}

@test "bump: no argument leaves a bare major alone" {
  echo 22 >"$PROJECT_DIR/.nvmrc"
  run node_sh bump
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ an X pin accepts any installed 22.x; nothing to bump (just node bump 22.N.N to pin a patch)"* ]] || false
  [ "$(cat "$PROJECT_DIR/.nvmrc")" = 22 ]
}

@test "bump: a bare major is accepted and written to mise.toml too" {
  printf '[tools]\nnode = "22.11.0"\n' >"$PROJECT_DIR/mise.toml"
  run node_sh bump 24
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJECT_DIR/.nvmrc")" = 24 ] || false
  grep -Fxq 'node = "24"' "$PROJECT_DIR/mise.toml"
}

@test "bump: refuses X.Y, prereleases and majors the backend lacks" {
  run node_sh bump 24.1
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to pin '24.1': not a stable X or X.Y.Z version"* ]] || false
  run node_sh bump 27.0.0-alpha.0.1.1
  [ "$status" -ne 0 ]
  run node_sh bump 99
  [ "$status" -ne 0 ]
  [[ "$output" == *"version 99 is not available via mise"* ]] || false
  [ "$(cat "$PROJECT_DIR/.nvmrc")" = 22.11.0 ]
}

@test "floor: oldest LTS major not yet end of life, skipping odd majors" {
  run node_sh floor
  [ "$status" -eq 0 ]
  [[ "$output" == *"oldest supported LTS:        22   (supported until 2027-04-30)"* ]] || false
  [[ "$output" == *"apply (supported floor): just node bump 22.23.5"* ]]
}

@test "floor: a non-LTS major is never the floor, even when it outlives an LTS one" {
  STUB_TODAY=2028-05-01 run node_sh floor
  [ "$status" -eq 0 ]
  [[ "$output" == *"oldest supported LTS:        26   (supported until 2029-04-30)"* ]]
}

@test "version: runs the pinned binary without installing it" {
  mise_installed node 22.11.0
  run node_sh version
  [ "$status" -eq 0 ]
  [ "$output" = "v22.11.0" ] || false
  run ! grep -q 'mise install' "$STUB_LOG"
}
