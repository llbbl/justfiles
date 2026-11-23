# shellcheck shell=bash
# Fake nvm.sh: defines nvm(). Installs live under $STUB_ROOT/nvm/<version>; a
# bare major means its newest listed release (install) or installed one (which).
_fake_nvm_newest() { awk -v p="$1" '$0 == p || index($0, p ".") == 1' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1; }
nvm() {
  echo "nvm $*" >>"$STUB_LOG"
  local ver
  case "$1" in
    ls-remote)
      grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' "$FIXTURES/mise-ls-remote-node.txt" |
        awk '{ printf "%s      v%s%s\n", ($0 == "22.23.5" ? "->" : "  "), $0, ($0 ~ /^22\./ ? "   (LTS: Jod)" : "") }' ;;
    install)
      ver="$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' "$FIXTURES/mise-ls-remote-node.txt" | _fake_nvm_newest "$2")"
      [ -n "$ver" ] || { echo "Version '$2' not found - try \`nvm ls-remote\` to browse available versions." >&2; return 3; }
      mkdir -p "$STUB_ROOT/nvm/node/$ver/bin"
      cp "$FIXTURES/fake-node" "$STUB_ROOT/nvm/node/$ver/bin/node" ;;
    which)
      ver="$(for d in "$STUB_ROOT/nvm/node"/*; do [ ! -d "$d" ] || echo "${d##*/}"; done | _fake_nvm_newest "$2")"
      [ -n "$ver" ] || { echo "N/A: version \"v$2\" is not yet installed." >&2; return 1; }
      echo "$STUB_ROOT/nvm/node/$ver/bin/node" ;;
    *) echo "fake nvm: unhandled: $*" >&2; return 2 ;;
  esac
}
