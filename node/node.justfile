# Node.js toolchain. Import from your root justfile:
#   mod node 'path/to/justfiles/node/node.justfile'

export PROJECT_DIR := justfile_directory()
node_sh := quote(source_directory() / "node.sh")

# List node recipes. Lists this file directly so it works under any `mod` name.
default:
    @{{quote(just_executable())}} --justfile {{quote(source_file())}} --list

# Install the pinned Node.js (.nvmrc) with the detected backend.
setup:
    @bash {{node_sh}} setup

# Check the pin against mise.toml and the installed version.
check:
    @bash {{node_sh}} check

# Print the active Node.js version.
version:
    @bash {{node_sh}} version

# Show the latest stable Node.js in the pinned major, vs the pin.
latest:
    @bash {{node_sh}} latest

# Pin the latest release in the current major (or VERSION).
bump VERSION="":
    @bash {{node_sh}} bump {{quote(VERSION)}}

# Show the oldest LTS major not yet end of life: the compatibility floor.
floor:
    @bash {{node_sh}} floor

# Show which backend would be used and why.
backend:
    @bash {{node_sh}} backend
