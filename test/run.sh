#!/usr/bin/env bash
# Runs the bats suite in each compose service (all by default). Exits non-zero
# if any service fails, after running them all.
set -euo pipefail
cd "$(dirname "$0")"

services="$*"
[ -n "$services" ] || services="$(docker compose config --services)"

failed=""
for s in $services; do
  echo "── $s (just ${JUST_VERSION:-1.46.0}) ──"
  docker compose run --rm --build "$s" || failed="$failed $s"
done

if [ -n "$failed" ]; then
  echo "✗ failed:$failed" >&2
  exit 1
fi
echo "✓ all passed"
