#!/usr/bin/env bash

packages=(
  nss-certs coreutils bash grep sed gawk git openssh-sans-x node swaynotificationcenter
  libcap openssl gcc-toolchain zlib go nginx docker-cli esbuild jq python
)

exec script -qec "$(printf "%q " guix shell --emulate-fhs --network "${packages[@]}" -- env DISABLE_AUTOUPDATER=1 corepack pnpm dlx "@anthropic-ai/claude-code@latest" --dangerously-skip-permissions "$@")" /dev/null
