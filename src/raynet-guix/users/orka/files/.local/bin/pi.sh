#!/usr/bin/env bash
# shellcheck source=/dev/null

# Get the directory of this script to find the 'pi' binary
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

script -qec "guix shell --container --emulate-fhs \
  --link-profile \
  --expose=$HOME/.gitconfig=$HOME/.gitconfig \
  --expose=$SSH_AUTH_SOCK=$SSH_AUTH_SOCK \
  --expose=$HOME/.ssh=$HOME/.ssh \
  --share=$HOME/.pi=$HOME/.pi \
  --share=$PWD=$PWD \
  --expose=$XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  --preserve='^DBUS_SESSION_BUS_ADDRESS' \
  --preserve='^COLORTERM' \
  --preserve='^PATH' \
  --preserve='^SSH_AUTH_SOCK' \
  --preserve='^ANTHROPIC_API_KEY' \
  --preserve='^OPENAI_API_KEY' \
  --preserve='^GOOGLE_API_KEY' \
  --network \
  nss-certs coreutils bash grep sed gawk git ripgrep fd openssh gcc-toolchain zlib \
  -- $BIN_DIR/pi $*" /dev/null
