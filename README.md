# justfiles

[![test](https://github.com/llbbl/justfiles/actions/workflows/test.yml/badge.svg)](https://github.com/llbbl/justfiles/actions/workflows/test.yml)

Drop-in [`just`](https://github.com/casey/just) modules for language toolchains.
Vendor this repo, add one `mod` line, and get tested recipes for setup, version
pinning and upgrades on macOS and Linux. mise is supported, not required.

```sh
git submodule add https://github.com/llbbl/justfiles vendor/justfiles
echo 8.5.7 > .php-version
```

```just
mod php 'vendor/justfiles/php/php.justfile'
```

```sh
just php setup    # install the pinned PHP, with working TLS
just php latest   # is there a newer patch?
just php bump     # pin it
```

## Modules

| Module         | What you get                                                 | Docs                       |
| -------------- | ------------------------------------------------------------ | -------------------------- |
| [`php/`](php/) | PHP pinned in `.php-version`, checked against `mise.toml`, upgrade recipes; installs with mise, Homebrew, apt, dnf, pacman or apk | [docs/php.md](docs/php.md) |
| [`python/`](python/) | CPython pinned in `.python-version`, checked against `mise.toml`, upgrade recipes; installs with mise, uv, Homebrew, apt, dnf, pacman or apk | [docs/python.md](docs/python.md) |
| [`node/`](node/) | Node.js pinned in `.nvmrc`, checked against `mise.toml`, upgrade recipes; installs with mise, nvm, fnm, Homebrew, apt (NodeSource), dnf, pacman or apk | [docs/node.md](docs/node.md) |

## Versions

Releases are semver tags (`v0.1.0`), listed with their notes on the
[releases page](https://github.com/llbbl/justfiles/releases). Patch releases
are fixes and safe to take. Before 1.0, a minor release may change recipes, pin
rules or `*_BACKEND` variables; its notes say how.

Pin the submodule to a release, and move it when you want an update:

```sh
cd vendor/justfiles && git fetch --tags && git checkout v0.1.0 && cd -
git add vendor/justfiles && git commit -m "justfiles v0.1.0"
```

## Requirements

- macOS or Linux
- `just` 1.31.0 or newer
- bash 3.2 or newer (the macOS default works)

Contributing or running the tests: [docs/development.md](docs/development.md).

## License

[MIT](LICENSE)
