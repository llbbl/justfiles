# dnf, pacman and apk: one package per major, picked from what the distro ships.

setup() {
  load ../helpers
  common_setup
}

@test "dnf: a side-by-side major installs nodejsN and its npm" {
  export NODE_BACKEND=dnf
  echo 24 >"$PROJECT_DIR/.nvmrc"
  fake_node "$STUB_BIN/node-24" 24.14.1
  run node_sh setup
  [ "$status" -eq 0 ]
  assert_log "dnf install -y nodejs24 nodejs24-npm"
  [[ "$output" == *"✓ npm present"* ]]
}

@test "dnf: the default major installs nodejs and nodejs-npm" {
  export NODE_BACKEND=dnf
  echo 22 >"$PROJECT_DIR/.nvmrc"
  fake_node "$STUB_BIN/node-22" 22.22.2
  run node_sh setup
  [ "$status" -eq 0 ]
  assert_log "dnf install -y nodejs nodejs-npm"
}

@test "dnf: lists majors without -devel or -npm packages" {
  export NODE_BACKEND=dnf
  echo 18 >"$PROJECT_DIR/.nvmrc"
  run node_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"node 18 is not available via dnf (have: 20 22 24)"* ]]
}

@test "dnf: check runs node-N" {
  export NODE_BACKEND=dnf
  echo 24 >"$PROJECT_DIR/.nvmrc"
  fake_node "$STUB_BIN/node-24" 24.14.1
  run node_sh check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed:          24.14.1 ✓"* ]]
}

@test "pacman: an LTS major installs its nodejs-lts package and npm" {
  export NODE_BACKEND=pacman
  echo 22 >"$PROJECT_DIR/.nvmrc"
  fake_node "$STUB_BIN/node" 22.23.5
  run node_sh setup
  [ "$status" -eq 0 ]
  assert_log "pacman -S --needed --noconfirm --ask 4 nodejs-lts-jod npm"
}

@test "pacman: the current major installs nodejs" {
  export NODE_BACKEND=pacman
  echo 26 >"$PROJECT_DIR/.nvmrc"
  fake_node "$STUB_BIN/node" 26.13.1
  run node_sh setup
  [ "$status" -eq 0 ]
  assert_log "pacman -S --needed --noconfirm --ask 4 nodejs npm"
}

@test "pacman: any other major fails, naming what Arch has" {
  export NODE_BACKEND=pacman
  echo 20 >"$PROJECT_DIR/.nvmrc"
  run node_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"node 20 is not available via pacman (have: 22 24 26)"* ]] || false
  run ! grep -q 'pacman -S ' "$STUB_LOG"
}

@test "apk: the LTS major installs nodejs and npm" {
  export NODE_BACKEND=apk
  echo 22 >"$PROJECT_DIR/.nvmrc"
  fake_node "$STUB_BIN/node" 22.23.5
  STUB_UID=1000 run node_sh setup
  [ "$status" -eq 0 ]
  assert_log "sudo apk --no-cache add nodejs npm"
}

@test "apk: the current major installs nodejs-current" {
  export NODE_BACKEND=apk
  echo 23 >"$PROJECT_DIR/.nvmrc"
  fake_node "$STUB_BIN/node" 23.11.1
  run node_sh setup
  [ "$status" -eq 0 ]
  assert_log "apk --no-cache add nodejs-current npm"
}

@test "apk: switching majors removes the other node package" {
  export NODE_BACKEND=apk APK_WORLD="$BATS_TEST_TMPDIR/world"
  printf 'busybox\nnodejs-current\nnpm\nnodejs\n' >"$APK_WORLD"
  echo 22 >"$PROJECT_DIR/.nvmrc"
  fake_node "$STUB_BIN/node" 22.23.5
  run node_sh setup
  [ "$status" -eq 0 ]
  assert_log "apk --no-cache add nodejs npm"
  assert_log "apk --no-cache del nodejs-current"
  run ! grep -q 'del nodejs$' "$STUB_LOG"
}

@test "setup: fails when the package manager left another major in place" {
  export NODE_BACKEND=apk
  echo 22 >"$PROJECT_DIR/.nvmrc"
  fake_node "$STUB_BIN/node" 23.11.1
  run node_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"setup left node 23.11.1 installed, not 22"* ]] || false
  [[ "$output" != *"npm present"* ]]
}

@test "apk: any other major fails, naming what the release has" {
  export NODE_BACKEND=apk
  echo 24 >"$PROJECT_DIR/.nvmrc"
  run node_sh setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"node 24 is not available via apk (have: 22 23)"* ]]
}
