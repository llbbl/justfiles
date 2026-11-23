# Development

## Layout

```
lib/              shared helpers: common.sh, pin.sh (pins + mise.toml), backend.sh
<lang>/           <lang>.justfile (one-line recipes), <lang>.sh (entrypoint),
                  backends/<name>.sh
test/             bats suites, fake commands (stubs/), fixtures/, Dockerfile, compose.yaml
```

Recipes stay one line: `bash {{php_sh}} <command>`. All logic lives in the
`.sh` files so it can be tested and linted.

A backend defines `backend_available`, `backend_granularity`
(`patch`/`minor`/`major`), `backend_versions`, `backend_install PIN` and
`backend_exec PIN ARGS...`. `lib/backend.sh` refuses one missing any of these.

## Tests

Everything runs in containers; nothing is installed on your machine.

```sh
just test                 # every image
just test alpine bash32   # some of them
just test-just 1.31.0     # against another just release
just lint                 # shellcheck
```

Images: Ubuntu 24.04, Debian 13, Fedora 43, Arch, Alpine 3.22, and `bash:3.2`
(stands in for macOS's `/bin/bash`). Arch runs as amd64 because it publishes no
arm64 image. Containers run with no network.

Tests never call real package managers or the network: `test/stubs/` holds fake
`mise`, `brew`, `curl`, `uname` and `date` that log their arguments to
`$STUB_LOG` and answer from `test/fixtures/`. Linux containers can't exercise
BSD userland (`sed`, `sort`, `awk` on macOS); that needs a macOS CI runner.

## Shell rules

- `#!/usr/bin/env bash` and `set -euo pipefail`; target bash 3.2. No
  associative arrays, `mapfile`, `${var,,}`, `&>>`, or empty-array expansion
  under `set -u`.
- Never pipe into `grep -q`: grep exits early, the writer gets SIGPIPE, and
  pipefail reports a failure. Capture to a variable and use a here-string.
- No `sed -i` (BSD and GNU disagree); use `rewrite_file`.
- No `sort -V` (busybox); use `version_sort`.
- `just lint` must pass.

## Minimum just

1.31.0, the release where `mod` became stable. `just test-just <version>`
re-checks it.
