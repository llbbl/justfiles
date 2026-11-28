# Development

## Layout

```
lib/              shared helpers: common.sh, pin.sh (pins + mise.toml), backend.sh,
                  commands.sh (check, setup, version, latest, bump, floor, backend),
                  apt.sh (signed third-party apt repos)
<lang>/           <lang>.justfile (one-line recipes), <lang>.sh (module config +
                  hooks), backends/<name>.sh
test/             bats suites, fake commands (stubs/), fixtures/, Dockerfile, compose.yaml,
                  integration/ (real installs)
scripts/          release.sh (run by the release workflow)
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

`main` refuses to run if any of these is missing. These are optional:

- `RELEASE_LINE`: `minor` (default; php 8.5, python 3.13) or `major` (node 22).
  `latest` and `bump` work within the pin's line, and coarse backends
  (`backend_granularity` of `minor` or `major`) install its newest release.
- `LINE_PINS=1` (python, node): a bare line pin (`3.13`, `22`) is allowed on a
  patch backend and accepts any installed release of that line; `latest`
  compares lines for it.
- `LTS=1` (node): `floor` picks the oldest LTS cycle instead of the oldest
  cycle in the pin's major, and when `latest` compares lines it recommends the
  newest line that is in LTS today (per endoflife.date), falling back to all
  lines with a warning when that can't be read.
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

`.github/workflows/integration.yml` runs a real `just <module> setup` for php,
python and node, weekly and on demand, through `test/integration/smoke.sh` (a
scratch consumer project; `MODULE` and `PIN` pick what it sets up):

- **macos-php-setup**: the mise backend on a fresh Mac. It builds PHP (up to
  ~16 minutes), so it runs only on manual dispatch, not weekly. Run it when a
  Homebrew lib PHP builds against changes (a new `icu4c`, say).
- **macos-php-mise-check**: the same mise path without the compile, weekly. It
  runs the backend's own `brew install` and `brew --prefix` steps with `mise`
  stubbed out, then `just php backend`, `latest` and `bump` (`SETUP=0` in
  `smoke.sh`). Catches renamed or removed formulae and breakage in mise's php
  plugin or version list; not a lib PHP no longer builds against.
- **macos-brew-setup**: `PHP_BACKEND=brew` on a fresh Mac.
- **macos-python-setup**: python with each of mise, uv and brew on a fresh Mac.
- **macos-node-setup**: node with each of mise, nvm, fnm and brew on a fresh Mac.
- **linux**: each `test/integration/compose.yaml` service, the same thing
  `just test-integration` runs locally: a stock distro image with network on,
  one service per distro for php and one each (`python-<distro>`,
  `node-<distro>`) for python and node. `python-<tool>` and `node-<tool>` add
  one version manager (mise, uv, nvm, fnm) to Ubuntu from its official
  installer and force that backend; `python-uv-alpine` does the same on Alpine.
  Only uv gets an Alpine service: nodejs.org ships no musl builds, and mise
  compiles python from source on musl.

Too slow for every push. To test a branch, run it against that branch:

```sh
gh workflow run integration.yml --ref <branch>
```

or use the Actions tab: integration → "Run workflow" → pick the branch.
GitHub disables the weekly schedule after 60 days without repo activity; re-enable
it from the Actions tab.

Locally, a cached Arch integration image keeps the package database from when it
was built, and weeks later its downloads fail. Rebuild it with
`docker compose -f test/integration/compose.yaml build --no-cache arch`. The
same goes for the version-manager images: a cached one keeps the mise, uv, nvm
or fnm release it was built with, while CI always installs the latest.

## Releasing

`.github/workflows/release.yml` runs `scripts/release.sh`. Nothing reads commit
messages; version numbers only move as below.

- **Patch, automatic.** A merge to `main` that changes `lib/`, `php/`,
  `python/` or `node/` publishes the next patch after the highest `vX.Y.Z` tag,
  on that commit. Docs-, test- or CI-only merges publish nothing; their PRs
  appear in the next release's notes. Nothing is published before the first tag.
  A merge whose PR is labeled `breaking` gets no patch either: tag a minor (or
  major) on it. The hold covers every merge since the last release, so a later
  unlabeled merge can't ship the breaking change as a patch either.
- **Minor or major, by hand.** Tag `main` and push it:

  ```sh
  git fetch origin && git tag -a v0.2.0 -m "one-line summary" origin/main
  git push origin v0.2.0
  ```

  The workflow publishes that tag's release, with the tag message at the top.
  The list below it covers everything since the previous `X.Y.0`, not just
  since the last patch. A lightweight tag (no `-a`) gets the list alone.
  Tags the workflow creates start no other workflows, so nothing loops.

Notes are GitHub's generated release notes: merged PR titles, grouped by label
per `.github/release.yml` (`breaking`, `enhancement`, `bug`, `documentation`;
`no-release-notes` hides a PR). Labels never pick a version number; `breaking`
only holds back the automatic patch. Edit a published release with
`gh release edit` or on GitHub.

Tagging a minor on a commit that already got its patch (the usual case when
`main`'s tip is a code merge) leaves both tags on it. That's harmless: they
name the same code, and the minor's notes still cover the whole previous line.

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
