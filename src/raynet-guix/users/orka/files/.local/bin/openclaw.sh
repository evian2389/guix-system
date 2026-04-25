#!/usr/bin/env bash
# shellcheck source=/dev/null
# [ -f /etc/profile ] && . /etc/profile
guix shell --container --emulate-fhs \
  --link-profile \
  --expose=$HOME/.gitconfig=$HOME/.gitconfig \
  --expose=$SSH_AUTH_SOCK=$SSH_AUTH_SOCK \
  --expose=$HOME/.ssh=$HOME/.ssh \
  --share=$HOME/.openclaw=$HOME/.openclaw \
  --share=$HOME/.config/openclaw=$HOME/.config/openclaw \
  --share=$HOME/.config/cron=$HOME/.config/cron \
  --share=$HOME/.cache/pnpm=$HOME/.cache/pnpm \
  --share=$HOME/.local/share/pnpm=$HOME/.local/share/pnpm \
  --expose=$XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  --preserve='^DBUS_SESSION_BUS_ADDRESS' \
  --preserve='^COLORTERM' \
  --preserve='^PATH' \
  --preserve='^SSH_AUTH_SOCK' \
  --share=$HOME/work=$HOME/work \
  --network \
  nss-certs coreutils bash grep sed gawk git openssh node swaynotificationcenter libcap openssl@3.0 gcc-toolchain zlib \
  -- corepack pnpm dlx openclaw "$@"
