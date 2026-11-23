# Test image: any supported base + bats + just. Tests mount the repo read-only.
ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}
ARG JUST_VERSION
ARG BATS_VERSION=1.11.1

# Commands are `;`-separated, not `&&`-chained: set -e ignores a failure on
# the left of `&&`, which once let a failed pacman install build "successfully".
# pacman's sandbox needs seccomp, which amd64 emulation on arm64 hosts lacks.
RUN set -e; \
    pkgs="curl ca-certificates jq tar gzip"; \
    command -v bash >/dev/null || pkgs="$pkgs bash"; \
    if command -v apt-get >/dev/null; then \
      apt-get update; apt-get install -y --no-install-recommends $pkgs; rm -rf /var/lib/apt/lists/*; \
    elif command -v dnf >/dev/null; then \
      dnf install -y --setopt=install_weak_deps=False $pkgs; dnf clean all; \
    elif command -v pacman >/dev/null; then \
      pacman -Syu --noconfirm --needed --disable-sandbox $pkgs; pacman -Scc --noconfirm; \
    elif command -v apk >/dev/null; then \
      apk add --no-cache $pkgs; \
    fi; \
    command -v jq; \
    curl -fsSL "https://github.com/bats-core/bats-core/archive/refs/tags/v${BATS_VERSION}.tar.gz" | tar -xz -C /tmp; \
    "/tmp/bats-core-${BATS_VERSION}/install.sh" /usr/local; \
    rm -rf "/tmp/bats-core-${BATS_VERSION}"; \
    curl -fsSL "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-$(uname -m)-unknown-linux-musl.tar.gz" \
      | tar -xz -C /usr/local/bin just; \
    just --version; bash --version | head -n 1

WORKDIR /repo
CMD ["bats", "-r", "test"]
