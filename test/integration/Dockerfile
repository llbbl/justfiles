# A stock distro plus only what a consumer brings: bash and just.
ARG BASE_IMAGE=ubuntu:24.04

FROM alpine:3.22 AS just
ARG JUST_VERSION=1.46.0
RUN set -e; apk add --no-cache curl; \
    curl -fsSL "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-$(uname -m)-unknown-linux-musl.tar.gz" \
      | tar -xz -C /usr/local/bin just

FROM ${BASE_IMAGE}
COPY --from=just /usr/local/bin/just /usr/local/bin/just
# Arch: a synced, fully upgraded system, as on a real install (partial upgrades
# break php's libssl). The sandbox needs seccomp, which amd64 emulation lacks.
RUN set -e; \
    if command -v pacman >/dev/null; then \
      sed -i 's/^#DisableSandbox/DisableSandbox/' /etc/pacman.conf; pacman -Syu --noconfirm; pacman -Scc --noconfirm; \
    elif command -v apk >/dev/null; then \
      apk add --no-cache bash; \
    fi
CMD ["bash", "/repo/test/integration/smoke.sh"]
