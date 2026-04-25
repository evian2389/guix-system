#!/usr/bin/env bash
# shellcheck source=/dev/null
# [ -f /etc/profile ] && . /etc/profile
script -qec "guix shell --container --emulate-fhs \
  --link-profile \
  --expose=$HOME/.gitconfig=$HOME/.gitconfig \
  --expose=$SSH_AUTH_SOCK=$SSH_AUTH_SOCK \
  --expose=$HOME/.ssh=$HOME/.ssh \
  --share=$HOME/.claude=$HOME/.claude \
  --share=$HOME/.claude.json=$HOME/.claude.json \
  --share=$HOME/.config/claude=$HOME/.config/claude \
  --share=$HOME/.config/cron=$HOME/.config/cron \
  --share=$HOME/.cache/pnpm=$HOME/.cache/pnpm \
  --share=$HOME/.local/share/pnpm=$HOME/.local/share/pnpm \
  --share=/nix=/nix \
  --expose=$XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  --preserve='^DBUS_SESSION_BUS_ADDRESS' \
  --preserve='^COLORTERM' \
  --preserve='^PATH' \
  --preserve='^SSH_AUTH_SOCK' \
  --share=$HOME/work=$HOME/work \
  --network \
  nss-certs coreutils bash grep sed gawk git openssh node swaynotificationcenter libcap openssl@3.0 gcc-toolchain zlib \
  -- corepack pnpm dlx @anthropic-ai/claude-code --dangerously-skip-permissions $*" /dev/null
