# nvm and fnm: exact versions without root; nvm is a sourced shell function.

setup() {
  load ../helpers
  common_setup
  echo 22.11.0 >"$PROJECT_DIR/.nvmrc"
}

nvm_in() {
  mkdir -p "$1"
  cp "$FIXTURES/nvm.sh" "$1/nvm.sh"
}

@test "nvm: found in NVM_DIR and picked before fnm and brew" {
  nvm_in "$NVM_DIR"
  STUB_UNAME=Darwin PATH="$(isolated_path uname fnm brew)" run node_sh backend
  [ "$status" -eq 0 ]
  [ "$output" = "nvm (first available of: mise nvm fnm brew)" ]
}

@test "nvm: Homebrew's nvm.sh is found too" {
  nvm_in "$HOMEBREW_PREFIX/opt/nvm"
  STUB_UNAME=Darwin PATH="$(isolated_path uname)" run node_sh backend
  [ "$status" -eq 0 ]
  [ "$output" = "nvm (first available of: mise nvm fnm brew)" ]
}

@test "nvm: setup installs and runs the pinned version" {
  nvm_in "$NVM_DIR"
  NODE_BACKEND=nvm run node_sh setup
  [ "$status" -eq 0 ]
  assert_log "nvm install 22.11.0"
  [[ "$output" == *"v22.11.0"* ]] || false
  [[ "$output" == *"✓ npm present"* ]]
}

@test "nvm: check fails clearly when the version isn't installed" {
  nvm_in "$NVM_DIR"
  NODE_BACKEND=nvm run node_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *"node 22.11.0 is not installed: run  just node setup"* ]]
}

@test "nvm: latest reads ls-remote, markers and LTS labels included" {
  nvm_in "$NVM_DIR"
  NODE_BACKEND=nvm run node_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"latest stable 22.x:     22.23.5"* ]] || false
  [[ "$output" == *"latest stable overall:  26.13.1"* ]]
}

@test "nvm: without nvm.sh, NODE_BACKEND=nvm is refused" {
  NODE_BACKEND=nvm run node_sh backend
  [ "$status" -ne 0 ]
  [[ "$output" == *"NODE_BACKEND=nvm, but nvm is not available on this system"* ]]
}

@test "fnm: setup installs and runs the newest release of a bare major" {
  echo 24 >"$PROJECT_DIR/.nvmrc"
  NODE_BACKEND=fnm run node_sh setup
  [ "$status" -eq 0 ]
  assert_log "fnm install 24"
  [[ "$output" == *"v24.22.3"* ]] || false
  [[ "$output" == *"✓ npm present"* ]]
}

@test "fnm: check fails clearly when the version isn't installed" {
  NODE_BACKEND=fnm run node_sh check
  [ "$status" -ne 0 ]
  [[ "$output" == *"node 22.11.0 is not installed: run  just node setup"* ]]
}

@test "fnm: latest reads list-remote" {
  NODE_BACKEND=fnm run node_sh latest
  [ "$status" -eq 0 ]
  [[ "$output" == *"latest stable 22.x:     22.23.5"* ]]
}
