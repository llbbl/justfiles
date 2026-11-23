setup() {
  load ../helpers
  common_setup
  . "$REPO/lib/common.sh"
  . "$REPO/lib/backend.sh"
  MOD="$BATS_TEST_TMPDIR/mod"
  mkdir -p "$MOD/backends"
  for b in yes1 yes2; do fake_backend "$b" 0; done
  fake_backend no 1
}

fake_backend() {
  cat >"$MOD/backends/$1.sh" <<EOB
backend_available() { return $2; }
backend_granularity() { echo patch; }
backend_versions() { :; }
backend_install() { :; }
backend_exec() { :; }
EOB
}

@test "picks the first available backend in order" {
  backend_select "$MOD" X_BACKEND no yes2 yes1
  [ "$BACKEND" = yes2 ]
  [[ "$BACKEND_REASON" == "first available of: no yes2 yes1" ]]
}

@test "env var overrides the order" {
  X_BACKEND=yes1 backend_select "$MOD" X_BACKEND yes2
  [ "$BACKEND" = yes1 ]
  [ "$BACKEND_REASON" = "set by X_BACKEND" ]
}

@test "env var naming an unknown backend fails" {
  X_BACKEND=nope run backend_select "$MOD" X_BACKEND yes1
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown backend: nope"* ]]
}

@test "env var naming an unavailable backend fails" {
  X_BACKEND=no run backend_select "$MOD" X_BACKEND yes1
  [ "$status" -ne 0 ]
  [[ "$output" == *"X_BACKEND=no, but no is not available on this system"* ]]
}

@test "fails when nothing is available" {
  run backend_select "$MOD" X_BACKEND no
  [ "$status" -ne 0 ]
  [[ "$output" == *"no supported backend found (tried: no)"* ]]
}

@test "rejects a backend missing part of the contract" {
  printf 'backend_available() { :; }\n' >"$MOD/backends/half.sh"
  run backend_select "$MOD" X_BACKEND half
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not define backend_granularity"* ]]
}

@test "an earlier candidate's functions don't fill in a later one's contract" {
  printf 'backend_available() { :; }\n' >"$MOD/backends/half.sh"
  run backend_select "$MOD" X_BACKEND no half
  [ "$status" -ne 0 ]
  [[ "$output" == *"backend half does not define backend_granularity"* ]]
}
