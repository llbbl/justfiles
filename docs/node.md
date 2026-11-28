# node module

Pins your project's Node.js version, installs it, and tells you when to upgrade.

## Install

1. Vendor the repo (any path works; `vendor/justfiles` is used below):

   ```sh
   git submodule add https://github.com/llbbl/justfiles vendor/justfiles
   ```

2. Import the module from your root `justfile`:

   ```just
   mod node 'vendor/justfiles/node/node.justfile'
   ```

3. Pin a version and install it:

   ```sh
   just node bump 24   # writes .nvmrc
   just node setup
   ```

## The pin

The pin is `.nvmrc` in your project root (the directory holding your root
`justfile`), the file nvm, fnm, mise and `actions/setup-node` read. Recipes
read and write it there, never inside the vendored repo. A leading `v`
(`v22.11.0`) is fine.

Pins are a major (`22`: any release of it) or an exact version (`22.11.0`).
Node's release line is the major, so `X.Y` pins are refused, and so are nvm
aliases (`lts/*`, `lts/jod`, `node`), since what they mean changes over time.

If your `mise.toml` (or `.mise.toml`) also pins `node` under `[tools]`, the
two must match exactly. On a mismatch every recipe stops and names both files.
`just node bump` updates both, and `just node bump <version>` repairs an
existing mismatch by writing that version to both. `22` and `22.11.0` count as
different.

### Plain `node` on your PATH

The recipes always run the pinned node, but npm, pnpm and your IDE run whatever
`node` is on your `PATH`. `just node check` warns when that isn't the pinned
version. To make it so:

- **mise**: activate mise in your shell, or `mise use node@<pin>`.
- **nvm**: `nvm use` in the project (it reads `.nvmrc`).
- **fnm**: `fnm use`, or `eval "$(fnm env --use-on-cd)"` in your shell.
- **brew**: `node@N` is keg-only; put `$(brew --prefix node@N)/bin` first on
  `PATH`.
- **dnf**: a side-by-side major's binaries are `node-N` and `npm-N`.
- **apt, pacman, apk**: one node is installed at a time, so it already matches.

## Recipes

| Recipe                | What it does                                                       |
| --------------------- | ------------------------------------------------------------------ |
| `just node`           | list recipes                                                       |
| `just node setup`     | install the pinned node, then check npm is installed next to it    |
| `just node check`     | pin vs `mise.toml`, and installed version vs pin                   |
| `just node version`   | print the active node version                                      |
| `just node latest`    | latest release in your major, vs the pin (major pins and major backends: newest LTS major) |
| `just node bump`      | pin the latest release in your major (major pins and major backends: no-op) |
| `just node bump 24`   | pin an explicit major or `X.Y.Z`                                   |
| `just node floor`     | oldest LTS major not yet end of life                               |
| `just node backend`   | which backend would be used, and why                               |

## Backends

The first one found is used: on macOS `mise`, `nvm`, `fnm`, then `brew`; on
Linux the same, then `apt`, `dnf`, `pacman`, `apk`. Set `NODE_BACKEND` to
choose one explicitly (`NODE_BACKEND=nvm just node setup`).

| Backend | Pins           | Platforms      | Repos it adds                                  | Root            |
| ------- | -------------- | -------------- | ---------------------------------------------- | --------------- |
| mise    | exact or major | macOS, Linux   | none                                           | no              |
| nvm     | exact or major | macOS, Linux   | none                                           | no              |
| fnm     | exact or major | macOS, Linux   | none                                           | no              |
| brew    | major          | macOS, Linux   | none                                           | never (no sudo) |
| apt     | major          | Debian, Ubuntu | NodeSource `node_N.x`                          | sudo            |
| dnf     | major          | Fedora         | none                                           | sudo            |
| pacman  | major          | Arch           | none; `nodejs` and the `nodejs-lts-*` packages | sudo            |
| apk     | major          | Alpine         | none; `nodejs` and `nodejs-current`            | sudo            |

"sudo" means commands that change the system run directly when you're root
and through `sudo` otherwise. Each one is printed before it runs.

A major a backend can't install fails and names the majors it has. mise, nvm
and fnm install any release, on macOS and Linux, without root.

`setup` fails if the installed version doesn't match the pin afterwards, then
checks that npm is installed next to node (`npm`, or Fedora's
`npm-N`), since Debian, Arch and Alpine package it separately.

### Major pins

Package managers ship one release per major, the newest. On those backends an
exact pin still works (`setup` and `check` accept the newest `22.x` and warn
that minors and patches can't be pinned), `latest` compares majors, and `bump`
with no version does nothing.

On mise, nvm and fnm a major pin accepts any installed release of it: `check`
passes on it, `latest` compares majors and `bump` leaves the pin alone
(`bump 22.N.N` pins an exact version). `setup` installs the newest release of
the major. An `X.Y.Z` pin is exact.

When `latest` compares majors, it recommends the newest major the backend has
that [endoflife.date](https://endoflife.date/nodejs) lists as LTS today. A
newer major that isn't LTS yet, an odd one or a new even one still in Current,
is shown as `(not LTS)` but never recommended. A pin newer than the newest LTS
is left alone. Without `jq` or network, `latest` warns and compares all majors.

### mise

`mise install node@<pin>`, then runs the installed binary directly, so
`version` and `check` never trigger a surprise install the way `mise exec`
would.

### nvm

nvm is a shell function, so each call sources `nvm.sh` from `$NVM_DIR`
(default `~/.nvm`) or Homebrew's `opt/nvm`, in a subshell. `nvm install <pin>`,
then runs what `nvm which <pin>` returns.

### fnm

`fnm install <pin>`, then runs the binary `fnm exec --using=<pin>` resolves.

### brew

Installs `node@N` from Homebrew core (core's current `node` answers to its
`node@N` name too) and runs its keg's `node`.

### apt

Always installs from [NodeSource](https://github.com/nodesource/distributions):
Debian's and Ubuntu's own node is end of life and lacks npm. `setup` adds
`/etc/apt/keyrings/nodesource.asc` and `/etc/apt/sources.list.d/nodesource.list`
for the pinned major, then installs `nodejs=N.*`. The key must have
NodeSource's fingerprint (`6F71F525282841EEDAF851B42F59B5F99B1BE0B4`, checked
with `gpg`) or nothing is added. The repo carries one major, so pinning another
rewrites the list. If NodeSource doesn't publish the major, `setup` stops before
touching either file. If `apt-get update` still fails after the rewrite, the
previous major's list and key are put back (on a first add, both are removed).
`latest` before the first `setup` only sees the distro's own node.

### dnf

Fedora's default `nodejs` is one major; others install side by side as
`nodejsN`, with npm in `nodejsN-npm`. Either way the binary is `node-N`.

### pacman, apk

Arch ships the current major as `nodejs` and LTS majors as
`nodejs-lts-<codename>`; Alpine ships `nodejs` (LTS) and `nodejs-current`. The
packages conflict, so one major is installed at a time: pinning another major
replaces the installed package. npm is installed with it.

## Staying current

1. `just node latest` tells you whether a newer release (or LTS major) exists.
2. `just node bump` updates the pin (and `mise.toml`, if it pins node).
3. `just node setup` installs it.

`just node floor` queries [endoflife.date](https://endoflife.date) for the
oldest LTS major not yet end of life. That's your compatibility floor if you
maintain a library (`engines.node`).

## Requirements

- macOS or Linux, with one of: mise, nvm, fnm, Homebrew, apt (Debian, Ubuntu),
  dnf (Fedora), pacman (Arch), apk (Alpine)
- `jq`, for `just node floor`, and for `just node latest` to tell which majors
  are LTS (without it, `latest` compares all majors)
