#!/usr/bin/env bash
# shellcheck source=/dev/null
# [ -f /etc/profile ] && . /etc/profile
guix shell --container --emulate-fhs \
  --expose=$HOME/.gitconfig=$HOME/.gitconfig \
  --share=$HOME/.openclaw=$HOME/.openclaw \
  --share=$HOME/.config/openclaw=$HOME/.config/openclaw \
  --share=$HOME/.config/cron=$HOME/.config/cron \
  --share=$HOME/.cache/pnpm=$HOME/.cache/pnpm \
  --share=$HOME/.local/share/pnpm=$HOME/.local/share/pnpm \
  --expose=$XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  --preserve='^DBUS_SESSION_BUS_ADDRESS' \
  --preserve='^COLORTERM' \
  --share=$HOME=$HOME \
  --network \
  nss-certs coreutils bash grep sed gawk git node swaynotificationcenter libcap openssl@3.0 gcc-toolchain zlib \
  -- corepack pnpm dlx openclaw "$@"
