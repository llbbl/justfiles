# PHP toolchain. Import from your root justfile:
#   mod php 'path/to/justfiles/php/php.justfile'

export PROJECT_DIR := justfile_directory()
php_sh := quote(source_directory() / "php.sh")

# List php recipes. Lists this file directly so it works under any `mod` name.
default:
    @{{quote(just_executable())}} --justfile {{quote(source_file())}} --list

# Install the pinned PHP (.php-version) with the detected backend.
setup:
    @bash {{php_sh}} setup

# Check the pin against mise.toml and the installed version.
check:
    @bash {{php_sh}} check

# Print the active PHP version.
version:
    @bash {{php_sh}} version

# Show the latest stable PHP in the pinned minor line, vs the pin.
latest:
    @bash {{php_sh}} latest

# Pin the latest stable patch in the current minor line (or VERSION).
bump VERSION="":
    @bash {{php_sh}} bump {{quote(VERSION)}}

# Show the oldest php.net active-support branch: the compatibility floor.
floor:
    @bash {{php_sh}} floor

# Show which backend would be used and why.
backend:
    @bash {{php_sh}} backend
