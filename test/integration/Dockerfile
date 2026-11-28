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
# Optionally one version manager, from its official installer at the latest release.
ARG TOOL=
RUN set -e; [ -n "$TOOL" ] || exit 0; \
    if command -v apt-get >/dev/null; then \
      apt-get update; apt-get install -y --no-install-recommends curl ca-certificates unzip; rm -rf /var/lib/apt/lists/*; \
    else \
      apk add --no-cache curl; \
    fi; \
    case "$TOOL" in \
      mise) curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh ;; \
      uv) curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh ;; \
      nvm) curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | PROFILE=/dev/null bash ;; \
      fnm) curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir /usr/local/bin --skip-shell ;; \
      *) echo "unknown TOOL $TOOL" >&2; exit 1 ;; \
    esac; \
    # sh has no pipefail: a failed curl pipes nothing and the installer exits 0.
    command -v "$TOOL" || [ -s "$HOME/.nvm/nvm.sh" ]
CMD ["bash", "/repo/test/integration/smoke.sh"]
