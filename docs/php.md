# php module

Pins your project's PHP version, installs it, and tells you when to upgrade.

## Install

1. Vendor the repo (any path works; `vendor/justfiles` is used below):

   ```sh
   git submodule add https://github.com/llbbl/justfiles vendor/justfiles
   ```

2. Import the module from your root `justfile`:

   ```just
   mod php 'vendor/justfiles/php/php.justfile'
   ```

3. Pin a version and install it:

   ```sh
   just php bump 8.5.7   # writes .php-version
   just php setup
   ```

## The pin

The pin is `.php-version` in your project root (the directory holding your
root `justfile`). Recipes read and write it there, never inside the vendored
repo.

If your `mise.toml` (or `.mise.toml`) also pins `php` under `[tools]`, the two
must match exactly. On a mismatch every recipe stops and names both files, since
one of them has to change. `just php bump` updates both, so it never creates a
mismatch, and `just php bump <version>` repairs an existing one by writing that
version to both. `8.5` and `8.5.7` count as different: mise would resolve `8.5` to
whatever patch is newest.

### Plain `php` on your PATH

The recipes always run the pinned binary, but composer, phpunit and your IDE run
whatever `php` is on your `PATH`. `just php check` warns when that isn't the
pinned version. To make it so:

- **mise**: activate mise in your shell, or `mise use php@<pin>`.
- **brew**: `brew link --overwrite --force php@X.Y` (non-current minors are keg-only).
- **apt**: `sudo update-alternatives --set php /usr/bin/phpX.Y`.
- **dnf**: `sudo dnf install phpNN-syspaths` (Remi's package that provides `php`).
- **pacman**: `php-legacy` installs as `php-legacy`; alias or symlink it to `php`.
- **apk**: the binary is `phpNN`; symlink it to `php`.

## Recipes

| Recipe                | What it does                                                        |
| --------------------- | ------------------------------------------------------------------- |
| `just php`            | list recipes                                                        |
| `just php setup`      | install the pinned PHP, then verify the openssl extension loaded    |
| `just php check`      | pin vs `mise.toml`, and installed version vs pin                     |
| `just php version`    | print the active PHP version                                        |
| `just php latest`     | latest stable patch in your minor line, vs the pin ([minor backends](#minor-pins): newest minor) |
| `just php bump`       | pin the latest stable patch in your minor line (minor backends: no-op) |
| `just php bump 8.5.7` | pin an explicit stable version (RC tags are refused)               |
| `just php floor`      | oldest branch still in php.net *active* support, in your major      |
| `just php backend`    | which backend would be used, and why                                |

## Backends

A backend is how PHP gets installed. The first one found is used: on macOS
`mise`, then `brew`; on Linux `brew`, then `apt`, `dnf`, `pacman`, `apk`. Set
`PHP_BACKEND` to choose one explicitly (`PHP_BACKEND=brew just php setup`);
`just php backend` shows which one you'd get.

| Backend | Pins        | Platforms      | Repos it adds                                | Root            |
| ------- | ----------- | -------------- | -------------------------------------------- | --------------- |
| mise    | exact patch | macOS          | none                                         | no              |
| brew    | minor       | macOS, Linux   | `shivammathur/php` tap, for minors core lacks | never (no sudo) |
| apt     | minor       | Debian, Ubuntu | packages.sury.org                            | sudo            |
| dnf     | minor       | Fedora         | Remi (`remi-release`)                        | sudo            |
| pacman  | minor       | Arch           | none; `php` and `php-legacy` only            | sudo            |
| apk     | minor       | Alpine         | none; the release's `phpNN` only             | sudo            |

"sudo" means commands that change the system run directly when you're root
and through `sudo` otherwise. Each one is printed before it runs, and a repo
already present is left alone, so re-running `setup` is safe.

Every backend installs the same extension set as the mise build: cli, common,
curl, mbstring, xml, zip, intl, gd and opcache (built into PHP from 8.5), plus
openssl where it's a separate package. `setup` fails if openssl isn't loaded.

### Minor pins

Package managers ship one patch per minor, the newest, so every backend but
mise pins `8.5`, not `8.5.7`.

- A patch pin still works, so one `.php-version` can serve a team where some
  use mise. `setup` and `check` install and accept the newest `8.5.x` and warn
  that the patch can't be pinned.
- `just php latest` compares minors: the pin vs the newest minor the backend has.
- `just php bump` with no version does nothing: the package manager already
  tracks the newest patch. `just php bump 8.6` pins a new minor; `bump 8.6.1`
  is accepted too, with the same warning.

### mise

mise's php plugin builds from source and links the end-of-life `openssl@1.1`,
which leaves PHP with no working https/TLS. `setup` installs the Homebrew C
libraries PHP links against (`gd`, `icu4c`, `libzip`, `oniguruma`, `libxml2`,
`libiconv`), points `PHP_CONFIGURE_OPTIONS` and `PKG_CONFIG_PATH` at
`openssl@3` and Homebrew `libiconv`, runs `mise install php@<pin>`, and fails if
the `openssl` extension is missing.

`version` and `check` run the installed binary directly, so they never trigger
a surprise build the way `mise exec` would. mise is skipped on Linux, where it
doesn't know the build dependencies yet.

### brew

Installs `php@X.Y` from Homebrew core, which covers the supported minors (the
current one is an alias of `php`). Older minors come from the
`shivammathur/php` tap, added on first use.

### apt

Adds [packages.sury.org](https://packages.sury.org/php/README.txt) (keyring
package plus `/etc/apt/sources.list.d/php.list`) on Debian and Ubuntu, then
installs `phpX.Y-*`. Ubuntu uses it too: `ppa:ondrej/php` is frozen and points
there. `latest` before the first `setup` only sees the distro's own php.

### dnf

Fedora only for now (RHEL-family systems need EPEL and a different repo).
Installs `remi-release`, then Remi's `phpNN-php-*` packages; the binary is
`phpNN` (`php85`).

### pacman

Arch ships two minors: `php` (newest) and `php-legacy`. Any other pin fails and
names the two; Homebrew can install other minors. gd and intl are enabled in
`/etc/php/conf.d/justfiles.ini` (or `/etc/php-legacy/...`) since Arch ships
them disabled.

### apk

Installs `phpNN` and its extension packages from the Alpine release's
community repo. Each release ships a few minors (3.22: 8.2 to 8.4); a pin
outside them fails and names what's there.

## Staying current

1. `just php latest` tells you whether a newer patch exists in your minor line
   (on a minor backend: a newer minor).
2. `just php bump` updates the pin (and `mise.toml`, if it pins php).
3. `just php setup` installs it.

`just php floor` queries [endoflife.date](https://endoflife.date) for the
oldest branch still in active support. That's your compatibility floor if you
maintain a library.

## Requirements

- macOS or Linux, with one of: mise (macOS), Homebrew, apt (Debian, Ubuntu),
  dnf (Fedora), pacman (Arch), apk (Alpine)
- `jq`, only for `just php floor`
