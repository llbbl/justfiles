#!/usr/bin/env bash
# A consumer project in a temp dir, with this repo vendored by symlink, runs a
# real `just php setup` for PHP_PIN. Used by the integration containers and CI.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
project="$(mktemp -d)"
trap 'rm -rf "$project"' EXIT
mkdir -p "$project/vendor"
ln -s "$repo" "$project/vendor/justfiles"
cd "$project"
printf "mod php 'vendor/justfiles/php/php.justfile'\n" >justfile
echo "${PHP_PIN:?set PHP_PIN to the version to pin}" >.php-version
just php backend
just php setup
just php check
