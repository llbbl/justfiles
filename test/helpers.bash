# Shared bats setup: a scratch PROJECT_DIR, fake commands first on PATH.

common_setup() {
  bats_require_minimum_version 1.5.0
  REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO
  export FIXTURES="$REPO/test/fixtures"
  export PROJECT_DIR="$BATS_TEST_TMPDIR/project"
  export STUB_LOG="$BATS_TEST_TMPDIR/stub.log"
  export STUB_MISE_ROOT="$BATS_TEST_TMPDIR/mise"
  # Where stubs keep system state (repo files, installed packages) instead of /.
  export STUB_ROOT="$BATS_TEST_TMPDIR/root"
  export STUB_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$PROJECT_DIR" "$STUB_MISE_ROOT" "$STUB_ROOT" "$STUB_BIN"
  : >"$STUB_LOG"
  PATH="$STUB_BIN:$REPO/test/stubs:$PATH"
  unset PHP_BACKEND
}

# Pretend mise already installed TOOL VERSION.
mise_installed() {
  mkdir -p "$STUB_MISE_ROOT/$1/$2/bin"
  cp "$FIXTURES/fake-$1" "$STUB_MISE_ROOT/$1/$2/bin/$1"
}

# fake_php PATH VERSION: an executable at PATH that answers as php VERSION.
fake_php() {
  mise_installed php "$2"
  mkdir -p "$(dirname "$1")"
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$STUB_MISE_ROOT/php/$2/bin/php" >"$1"
  chmod +x "$1"
}

# isolated_path STUB...: a PATH holding only basic tools and the named stubs,
# to hide a command the image really has (sudo, apt-get, a stub like brew).
isolated_path() {
  local bin="$BATS_TEST_TMPDIR/isolated" t
  mkdir -p "$bin"
  for t in bash dirname cat cut grep sed awk sort tail tr mktemp rm; do
    ln -sf "$(command -v "$t")" "$bin/$t"
  done
  for t in "$@"; do ln -sf "$REPO/test/stubs/$t" "$bin/$t"; done
  echo "$bin"
}

php_sh() { bash "$REPO/php/php.sh" "$@"; }

assert_log() {
  grep -Fq -- "$1" "$STUB_LOG" || { echo "expected in stub log: $1"; cat "$STUB_LOG"; return 1; }
}
