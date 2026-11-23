# shellcheck shell=bash
# Shared helpers, sourced by module entrypoints. Targets bash 3.2.

die() { printf '✗ %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "needs $1${2:+ ($2)}"
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux) echo linux ;;
    *) die "unsupported OS: $(uname -s) (macOS and Linux only)" ;;
  esac
}

# stdin → only X.Y.Z lines (drops RC/alpha/dev tags).
stable_versions() { grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true; }

# Numeric X.Y.Z sort; busybox sort may lack -V.
version_sort() { sort -t. -k1,1n -k2,2n -k3,3n; }

version_minor() { printf '%s\n' "$1" | cut -d. -f1-2; }
version_major() { printf '%s\n' "$1" | cut -d. -f1; }

# True if INSTALLED satisfies PIN, where PIN may be a prefix ("8.5" matches "8.5.7").
version_matches() {
  [ "$1" = "$2" ] && return 0
  case "$1" in "$2".*) return 0 ;; esac
  return 1
}

# rewrite_file FILE CMD...: replace FILE with CMD's output, only if CMD
# succeeds. Copies back instead of mv so permissions and symlinks survive.
rewrite_file() {
  local f="$1" tmp
  shift
  tmp="$(mktemp)"
  "$@" >"$tmp" || { rm -f "$tmp"; return 1; }
  cat "$tmp" >"$f"
  rm -f "$tmp"
}

http_get() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    die "needs curl or wget"
  fi
}
