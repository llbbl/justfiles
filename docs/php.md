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
mismatch. `8.5` and `8.5.7` count as different: mise would resolve `8.5` to
whatever patch is newest.

## Recipes

| Recipe                | What it does                                                        |
| --------------------- | ------------------------------------------------------------------- |
| `just php`            | list recipes                                                        |
| `just php setup`      | install the pinned PHP, then verify the openssl extension loaded    |
| `just php check`      | pin vs `mise.toml`, and installed version vs pin                     |
| `just php version`    | print the active PHP version                                        |
| `just php latest`     | latest stable patch in your minor line, vs the pin                  |
| `just php bump`       | pin the latest stable patch in your minor line                      |
| `just php bump 8.5.7` | pin an explicit stable version (RC tags are refused)               |
| `just php floor`      | oldest branch still in php.net *active* support, in your major      |
| `just php backend`    | which backend would be used, and why                                |

## Backends

A backend is how PHP gets installed. The first one found is used; set
`PHP_BACKEND` to choose one explicitly.

| Backend | Pins        | Platforms | Notes                                     |
| ------- | ----------- | --------- | ----------------------------------------- |
| mise    | exact patch | macOS     | builds from source against openssl@3      |

Homebrew, apt, dnf, pacman and apk backends are planned.

### mise

mise's php plugin builds from source and links the end-of-life `openssl@1.1`,
which leaves PHP with no working https/TLS. `setup` installs the Homebrew C
libraries PHP links against (`gd`, `icu4c`, `libzip`, `oniguruma`, `libxml2`,
`libiconv`), points `PHP_CONFIGURE_OPTIONS` and `PKG_CONFIG_PATH` at
`openssl@3` and Homebrew `libiconv`, runs `mise install php@<pin>`, and fails if
the `openssl` extension is missing.

`version` and `check` run the installed binary directly, so they never trigger
a surprise build the way `mise exec` would.

## Staying current

1. `just php latest` tells you whether a newer patch exists in your minor line.
2. `just php bump` updates the pin (and `mise.toml`, if it pins php).
3. `just php setup` installs it.

`just php floor` queries [endoflife.date](https://endoflife.date) for the
oldest branch still in active support. That's your compatibility floor if you
maintain a library.

## Requirements

- macOS (for the mise backend today), Homebrew, mise
- `jq`, only for `just php floor`
