# shellcheck shell=bash
# Version pins: the module's pin file in PROJECT_DIR, cross-checked against
# mise config. Expects cwd = PROJECT_DIR and lib/common.sh sourced.

MISE_FILES="mise.toml .mise.toml"

# First non-blank, non-comment token of FILE, leading "v" stripped.
pin_read() {
  [ -f "$1" ] || return 1
  local v
  v="$(awk '{ sub(/\r$/, "") } NF && $1 !~ /^#/ { sub(/^v/, "", $1); print $1; exit }' "$1")"
  [ -n "$v" ] || return 1
  printf '%s\n' "$v"
}

# Sets MISE_PIN and MISE_PIN_FILE (globals, so callers needn't subshell);
# returns 1 if no mise file pins TOOL. Parses one-line `tool = "x"`,
# `tool = { version = "x" }` and arrays (first entry wins, as in mise) under
# [tools]; `[tools.x]` tables, multi-line arrays and other mise files are not seen.
mise_pin() {
  local f v
  MISE_PIN=""
  MISE_PIN_FILE=""
  for f in $MISE_FILES; do
    [ -f "$f" ] || continue
    v="$(awk -v tool="$1" '
      { sub(/\r$/, "") }
      /^[ \t]*\[/ { in_tools = ($0 ~ /^[ \t]*\[tools\][ \t]*(#.*)?$/); next }
      in_tools && $0 ~ ("^[ \t]*[\"\047]?" tool "[\"\047]?[ \t]*=") {
        s = $0; sub(/^[^=]*=/, "", s)
        if (s ~ /^[ \t]*[{]/ && match(s, /version[ \t]*=/)) s = substr(s, RSTART + RLENGTH)
        if (match(s, /["\047][^"\047]*["\047]/)) {
          v = substr(s, RSTART + 1, RLENGTH - 2); sub(/^v/, "", v); print v; exit
        }
      }' "$f")"
    if [ -n "$v" ]; then
      MISE_PIN="$v"
      MISE_PIN_FILE="$f"
      return 0
    fi
  done
  return 1
}

# Prints the pin for TOOL from PINFILE; dies if missing or if a mise file
# disagrees. Compared as exact strings: "8.5" vs "8.5.7" can resolve to
# different patches, so it counts as a mismatch.
pin_get() {
  local tool="$1" pinfile="$2" pin
  if ! pin="$(pin_read "$pinfile")"; then
    if mise_pin "$tool"; then
      die "no $pinfile in $PWD ($MISE_PIN_FILE pins $tool $MISE_PIN): run  echo $MISE_PIN > $pinfile"
    fi
    die "no $pinfile in $PWD: run  just $tool bump <version>  (or  echo <version> > $pinfile)"
  fi
  if mise_pin "$tool" && [ "$MISE_PIN" != "$pin" ]; then
    die "pin mismatch: $pinfile says $tool $pin, $MISE_PIN_FILE says $MISE_PIN. Change one so they agree."
  fi
  printf '%s\n' "$pin"
}

# Writes VERSION to PINFILE, and to the mise file too if it pins TOOL, so a
# bump never creates a mismatch. The pin file is written last so a failed mise
# rewrite changes neither; matching uses a CR-stripped copy to keep CRLF endings.
pin_write() {
  local tool="$1" pinfile="$2" version="$3"
  if mise_pin "$tool"; then
    # shellcheck disable=SC2016 # awk program, expanded by awk not the shell
    rewrite_file "$MISE_PIN_FILE" awk -v tool="$tool" -v ver="$version" '
      { l = $0; sub(/\r$/, "", l) }
      l ~ /^[ \t]*\[/ { in_tools = (l ~ /^[ \t]*\[tools\][ \t]*(#.*)?$/) }
      in_tools && !done && l ~ ("^[ \t]*[\"\047]?" tool "[\"\047]?[ \t]*=") {
        i = index($0, "="); head = substr($0, 1, i); rest = substr($0, i + 1)
        if (rest ~ /^[ \t]*[{]/ && match(rest, /version[ \t]*=/)) {
          head = head substr(rest, 1, RSTART + RLENGTH - 1); rest = substr(rest, RSTART + RLENGTH)
        }
        if (sub(/["\047][^"\047]*["\047]/, "\"" ver "\"", rest)) { $0 = head rest; done = 1 }
      }
      { print }' "$MISE_PIN_FILE" || return 1
    log "$MISE_PIN_FILE: $tool → $version"
  fi
  printf '%s\n' "$version" >"$pinfile"
}
