#!/usr/bin/env bash
# A consumer project in a temp dir, with this repo vendored by symlink, runs a
# real `just MODULE setup` for PIN. Used by the integration containers and CI.
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
echo "$pin" >".$module-version"
just "$module" backend
just "$module" setup
just "$module" check
