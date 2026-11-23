# Python toolchain. Import from your root justfile:
#   mod python 'path/to/justfiles/python/python.justfile'

export PROJECT_DIR := justfile_directory()
python_sh := quote(source_directory() / "python.sh")

# List python recipes. Lists this file directly so it works under any `mod` name.
default:
    @{{quote(just_executable())}} --justfile {{quote(source_file())}} --list

# Install the pinned Python (.python-version) with the detected backend.
setup:
    @bash {{python_sh}} setup

# Check the pin against mise.toml and the installed version.
check:
    @bash {{python_sh}} check

# Print the active Python version.
version:
    @bash {{python_sh}} version

# Show the latest stable Python in the pinned minor line, vs the pin.
latest:
    @bash {{python_sh}} latest

# Pin the latest stable patch in the current minor line (or VERSION).
bump VERSION="":
    @bash {{python_sh}} bump {{quote(VERSION)}}

# Show the oldest Python branch not yet end of life: the compatibility floor.
floor:
    @bash {{python_sh}} floor

# Show which backend would be used and why.
backend:
    @bash {{python_sh}} backend
