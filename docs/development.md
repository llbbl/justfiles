# Development

## Layout

```
lib/              shared helpers: common.sh, pin.sh (pins + mise.toml), backend.sh,
                  commands.sh (check, setup, version, latest, bump, floor, backend)
<lang>/           <lang>.justfile (one-line recipes), <lang>.sh (module config +
                  hooks), backends/<name>.sh
test/             bats suites, fake commands (stubs/), fixtures/, Dockerfile, compose.yaml,
                  integration/ (real installs)
```

Recipes stay one line: `bash {{php_sh}} <command>`. All logic lives in the
`.sh` files so it can be tested and linted.

A backend defines `backend_available`, `backend_granularity`
(`patch`/`minor`/`major`), `backend_versions`, `backend_install PIN` and
`backend_exec PIN ARGS...`. `lib/backend.sh` refuses one missing any of these.

A module's `<lang>.sh` sets these, sources `lib/commands.sh`, and calls `main "$@"`:

- `TOOL` (`php`): the name used in hints (`just php ...`), the mise tool key,
  the `docs/php.md` link and the backend override variable, `PHP_BACKEND`. The
  consumer's `mod` name, not `TOOL`, names the recipes.
- `PIN_FILE`, `MODULE_DIR` (holds `backends/`), `BACKEND_ORDER_MACOS`,
  `BACKEND_ORDER_LINUX` (arrays, first available wins).
- `EOL_URL` (an endoflife.date API URL) and `FLOOR_FIELD`: `support` floors at
  the oldest cycle in active support, `eol` at the oldest not yet end of life.
- `TOOL_VERSION_ARGS`: array of args that make the binary print its bare version.
- `PATH_TOOL`, `PATH_TOOL_USERS`: the plain command `check` warns about when it
  isn't the pinned version, and what runs it.
- `verify_install PIN`: post-setup checks; dies on failure.

`main` refuses to run if any of these is missing. Two are optional:

- `MINOR_PINS=1` (python): an `X.Y` pin is allowed on a patch backend and
  accepts any installed patch of that minor; `latest` compares minors for it.
- `validate_pin PIN`: dies on a pin the module can't install (python: anything
  but CPython `X.Y`/`X.Y.Z`). `module_pin`, the one place commands read the pin,
  calls it.

Helpers the module's backends need beyond `lib/` (`php_packages`, `UV_HINT`)
live in its `.sh`.

## Tests

Everything runs in containers; nothing is installed on your machine.

```sh
just test                 # every image
just test alpine bash32   # some of them
just test-just 1.31.0     # against another just release
just test-integration     # real installs per distro, network on (slow)
just lint                 # shellcheck
```

Images: Ubuntu 24.04, Debian 13, Fedora 43, Arch, Alpine 3.22, and `bash:3.2`
(stands in for macOS's `/bin/bash`). Arch runs as amd64 because it publishes no
arm64 image. Containers run with no network.

Tests never call real package managers or the network: `test/stubs/` holds
fake `mise`, `uv`, `brew`, `apt-get`, `apt-cache`, `dpkg`, `dnf`, `rpm`, `pacman`, `apk`,
`sudo`, `id`, `tee`, `curl`, `uname` and `date` that log their arguments to
`$STUB_LOG` and answer from `test/fixtures/`. System state (a sources file, an
installed package) lives under `$STUB_ROOT`, never `/`; `OS_RELEASE` points
`os_release_field` at a fixture instead of `/etc/os-release`.

## CI

`.github/workflows/test.yml` runs on every push to `main` and every pull
request:

- **lint**: `just lint`.
- **linux**: each container image against just 1.31.0 and the current release.
- **macos**: the suite natively on `macos-latest`, with `/usr/bin` and `/bin`
  first on `PATH` so the stock bash 3.2 and BSD `sed`/`awk`/`sort`/`find` are
  what's tested. This is the only coverage of macOS userland.
- **ci**: passes only when all of the above pass. It's the single check the
  `main` ruleset requires, so changing the matrix never touches the ruleset.

`.github/workflows/integration.yml` runs a real `just php setup` and `just python setup`,
weekly and on demand, through `test/integration/smoke.sh` (a scratch consumer
project; `MODULE` and `PIN` pick what it sets up):

- **macos-php-setup**: the mise backend on a fresh Mac. It builds PHP.
- **macos-brew-setup**: `PHP_BACKEND=brew` on a fresh Mac.
- **macos-python-setup**: python with each of mise, uv and brew on a fresh Mac.
- **linux**: each `test/integration/compose.yaml` service, the same thing
  `just test-integration` runs locally: a stock distro image with network on,
  one service per distro for php and one (`python-<distro>`) for python.

Too slow for every push. To test a branch, run it against that branch:

```sh
gh workflow run integration.yml --ref <branch>
```

or use the Actions tab: integration → "Run workflow" → pick the branch.
GitHub disables the weekly schedule after 60 days without repo activity; re-enable
it from the Actions tab.

Locally, a cached Arch integration image keeps the package database from when it
was built, and weeks later its downloads fail. Rebuild it with
`docker compose -f test/integration/compose.yaml build --no-cache arch`.

## Shell rules

- `#!/usr/bin/env bash` and `set -euo pipefail`; target bash 3.2. No
  associative arrays, `mapfile`, `${var,,}`, `&>>`, or empty-array expansion
  under `set -u`.
- Never pipe into `grep -q`: grep exits early, the writer gets SIGPIPE, and
  pipefail reports a failure. Capture to a variable and use a here-string.
- No `sed -i` (BSD and GNU disagree); use `rewrite_file`.
- No `sort -V` (busybox); use `version_sort`.
- `just lint` must pass.
- In bats, end a `[[ ]]` that isn't a test's last line with `|| false`:
  bash before 4.1 doesn't fail a test on a mid-test `[[ ]]`. Bare `!` has the
  same problem; use `run !`.

## Minimum just

1.31.0, the release where `mod` became stable. `just test-just <version>`
re-checks it.
