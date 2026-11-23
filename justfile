# Dev tasks for this repo. Tests and lint run in containers, never on the host.

shellcheck_image := "koalaman/shellcheck:v0.10.0"

default:
    @just --list

# Run the bats suite in every container, or the named ones (e.g. `just test alpine bash32`).
test *SERVICES:
    ./test/run.sh {{SERVICES}}

# Run the suite against another just release (e.g. `just test-just 1.31.0`).
test-just VERSION *SERVICES:
    JUST_VERSION={{VERSION}} ./test/run.sh {{SERVICES}}

# shellcheck every script and test.
lint:
    docker run --rm -v "$PWD:/mnt:ro" -w /mnt {{shellcheck_image}} -x \
      */*.sh */backends/*.sh test/stubs/* test/fixtures/fake-*
    docker run --rm -v "$PWD:/mnt:ro" -w /mnt {{shellcheck_image}} -s bash test/helpers.bash
    docker run --rm -v "$PWD:/mnt:ro" -w /mnt {{shellcheck_image}} -s bats -S warning test/*/*.bats
