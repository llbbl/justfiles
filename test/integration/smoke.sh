#!/usr/bin/env bash
# A consumer project in a temp dir, with this repo vendored by symlink, runs a
# real `just MODULE setup` for PIN, then for PIN2 if set (switching versions);
# SETUP=0 skips installing.
# Used by the integration containers and CI.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
module="${MODULE:-php}"
pin="${PIN:?set PIN to the version to pin}"
project="$(mktemp -d)"
trap 'rm -rf "$project"' EXIT
mkdir -p "$project/vendor"
ln -s "$repo" "$project/vendor/justfiles"
cd "$project"
printf "mod %s 'vendor/justfiles/%s/%s.justfile'\n" "$module" "$module" "$module" >justfile
pin_file=".$module-version"
[ "$module" != node ] || pin_file=.nvmrc
echo "$pin" >"$pin_file"
just "$module" backend
if [ "${SETUP:-1}" = 0 ]; then
  just "$module" latest
  just "$module" bump
  just "$module" latest | grep -F '✓ pin is the latest'
  exit 0
fi
just "$module" setup
just "$module" check
if [ -n "${PIN2:-}" ]; then
  echo "$PIN2" >"$pin_file"
  just "$module" setup
  just "$module" check
fi
