# Shared bats setup: a scratch PROJECT_DIR, fake commands first on PATH.

common_setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO
  export FIXTURES="$REPO/test/fixtures"
  export PROJECT_DIR="$BATS_TEST_TMPDIR/project"
  export STUB_LOG="$BATS_TEST_TMPDIR/stub.log"
  export STUB_MISE_ROOT="$BATS_TEST_TMPDIR/mise"
  mkdir -p "$PROJECT_DIR" "$STUB_MISE_ROOT"
  : >"$STUB_LOG"
  PATH="$REPO/test/stubs:$PATH"
  unset PHP_BACKEND
}

# Pretend mise already installed TOOL VERSION.
mise_installed() {
  mkdir -p "$STUB_MISE_ROOT/$1/$2/bin"
  cp "$FIXTURES/fake-$1" "$STUB_MISE_ROOT/$1/$2/bin/$1"
}

php_sh() { bash "$REPO/php/php.sh" "$@"; }

assert_log() {
  grep -Fq -- "$1" "$STUB_LOG" || { echo "expected in stub log: $1"; cat "$STUB_LOG"; return 1; }
}
