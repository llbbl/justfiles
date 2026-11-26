# python module

Pins your project's Python version, installs it, and tells you when to upgrade.

## Install

1. Vendor the repo (any path works; `vendor/justfiles` is used below):

   ```sh
   git submodule add https://github.com/llbbl/justfiles vendor/justfiles
   ```

2. Import the module from your root `justfile`:

   ```just
   mod python 'vendor/justfiles/python/python.justfile'
   ```

3. Pin a version and install it:

   ```sh
   just python bump 3.13   # writes .python-version
   just python setup
   ```

## The pin

The pin is `.python-version` in your project root (the directory holding your
root `justfile`), the same file uv and pyenv read. Recipes read and write it
there, never inside the vendored repo. Only the first entry counts, so a pyenv
file listing several versions pins the first.

Pins are CPython `X.Y` (any patch of that minor, what `uv python pin` writes)
or `X.Y.Z`. PyPy (`pypy3.10`), free-threaded builds (`3.13t`) and prereleases
are refused with a message saying so.

If your `mise.toml` (or `.mise.toml`) also pins `python` under `[tools]`, the
two must match exactly. On a mismatch every recipe stops and names both files.
`just python bump` updates both, and `just python bump <version>` repairs an
existing mismatch by writing that version to both. `3.13` and `3.13.9` count as
different.

### Plain `python3` on your PATH

The recipes always run the pinned interpreter, but pip, venvs you create by hand
and your IDE run whatever `python3` is on your `PATH`. `just python check` warns
when that isn't the pinned version. To make it so:

- **mise**: activate mise in your shell, or `mise use python@<pin>`.
- **uv**: create venvs with `uv venv`, which reads `.python-version`.
- **brew**: the formula's `bin` has `python3.Y`; `python3` is whichever minor
  Homebrew links.
- **apt, dnf**: the binary is `python3.Y`; create venvs with
  `python3.Y -m venv .venv`. Don't repoint the system `python3`, the OS uses it.
- **pacman, apk**: the system `python3` is the only one, so it already matches.

## Recipes

| Recipe                  | What it does                                                         |
| ----------------------- | -------------------------------------------------------------------- |
| `just python`           | list recipes                                                         |
| `just python setup`     | install the pinned Python, then check `ssl`, `sqlite3` and `venv` work |
| `just python check`     | pin vs `mise.toml`, and installed version vs pin                     |
| `just python version`   | print the active Python version                                      |
| `just python latest`    | latest stable patch in your minor line, vs the pin (`X.Y` pins and minor backends: newest minor) |
| `just python bump`      | pin the latest stable patch in your minor line (`X.Y` pins and minor backends: no-op) |
| `just python bump 3.13` | pin an explicit stable `X.Y` or `X.Y.Z`                              |
| `just python floor`     | oldest branch not yet end of life, in your major                     |
| `just python backend`   | which backend would be used, and why                                 |

## Backends

The first one found is used: on macOS `mise`, `uv`, then `brew`; on Linux
`mise`, `uv`, `brew`, then `apt`, `dnf`, `pacman`, `apk`. Set `PYTHON_BACKEND`
to choose one explicitly (`PYTHON_BACKEND=uv just python setup`).

| Backend | Pins          | Platforms      | Repos it adds                               | Root            |
| ------- | ------------- | -------------- | ------------------------------------------- | --------------- |
| mise    | patch or minor | macOS, Linux  | none                                        | no              |
| uv      | patch or minor | macOS, Linux  | none                                        | no              |
| brew    | minor         | macOS, Linux   | none                                        | never (no sudo) |
| apt     | minor         | Debian, Ubuntu | `ppa:deadsnakes` on Ubuntu, for a minor the archive lacks | sudo |
| dnf     | minor         | Fedora         | none                                        | sudo            |
| pacman  | minor         | Arch           | none; Arch's one `python` only              | sudo            |
| apk     | minor         | Alpine         | none; the release's one `python3` only      | sudo            |

"sudo" means commands that change the system run directly when you're root
and through `sudo` otherwise. Each one is printed before it runs.

A minor a backend can't install fails and names the minors it has. uv installs
any minor, on macOS and Linux, without root: it's the way out.

`setup` then imports `ssl`, `sqlite3`, `venv` and `ensurepip`, and fails if
any is missing; without `ensurepip`, `python -m venv` can't install pip.

### Minor pins

Package managers ship one patch per minor, the newest. On those backends a
patch pin still works (`setup` and `check` accept the newest `3.13.x` and warn
that the patch can't be pinned), `latest` compares minors, and `bump` with no
version does nothing.

On mise and uv an `X.Y` pin accepts any installed patch of that minor:
`check` passes on it, `latest` compares minors and `bump` leaves the pin alone
(`bump 3.13.N` pins a patch). Which patch `setup` installs differs: uv picks
the newest only on first install and keeps it after that, while mise installs
the newest each time a newer one is out. An `X.Y.Z` pin is exact.

### mise

Installs python-build-standalone's precompiled CPython (`mise install
python@<pin>`), on Linux as well as macOS. On musl (Alpine) mise builds from
source instead, which needs a C compiler and Python's build libraries; use uv
there, which has prebuilt musl CPython. `version` and `check` run the
installed binary directly, so they never trigger a surprise install the way
`mise exec` would.

### uv

`uv python install <pin>`, then runs what
`uv python find --python-preference only-managed` returns, so a system Python
of the same version is never picked up.

### brew

Installs `python@X.Y` from Homebrew core and runs its `python3.Y`.

### apt

Installs `python3.Y` and `python3.Y-venv` (Debian and Ubuntu split `ensurepip`
out). On Ubuntu, a minor the archive lacks adds
[deadsnakes](https://launchpad.net/~deadsnakes/+archive/ubuntu/ppa)
(`/etc/apt/keyrings/deadsnakes.asc` and `/etc/apt/sources.list.d/deadsnakes.list`)
first. The PPA's key must have Launchpad's published fingerprint
(`F23C5A6CF475977595C89F51BA6932366A755776`, checked with `gpg`) or nothing is
added, and if the PPA has no release for your Ubuntu (non-LTS releases, a new
LTS before it's built) both files are removed again. `latest` before the
first `setup` only sees Ubuntu's own Python. Debian has only its own minor.

### dnf

Fedora packages most minors side by side as `python3.Y`; the system minor is
`python3`. Either way the binary is `python3.Y`.

### pacman, apk

Arch and Alpine ship one Python each (`python`, `python3`); any other pin fails.

## Staying current

1. `just python latest` tells you whether a newer patch (or minor) exists.
2. `just python bump` updates the pin (and `mise.toml`, if it pins python).
3. `just python setup` installs it.

`just python floor` queries [endoflife.date](https://endoflife.date) for the
oldest branch not yet end of life. That's your compatibility floor if you
maintain a library.

## Requirements

- macOS or Linux, with one of: mise, uv, Homebrew, apt (Debian, Ubuntu),
  dnf (Fedora), pacman (Arch), apk (Alpine)
- `jq`, only for `just python floor`
