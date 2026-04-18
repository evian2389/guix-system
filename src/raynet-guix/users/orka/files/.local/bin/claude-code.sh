guix shell --container --emulate-fhs \
  --expose=$HOME/.gitconfig=$HOME/.gitconfig \
  --share=$HOME/.claude=$HOME/.claude \
  --share=$HOME/.claude.json=$HOME/.claude.json \
  --share=$HOME/.config/claude=$HOME/.config/claude \
  --share=$HOME/.cache/pnpm=$HOME/.cache/pnpm \
  --share=$HOME/.local/share/pnpm=$HOME/.local/share/pnpm \
  --expose=$XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  --preserve='^DBUS_SESSION_BUS_ADDRESS' \
  --preserve='^COLORTERM' \
  --share=$PWD=$PWD \
  --network \
  nss-certs coreutils bash grep sed gawk git node gh swaynotificationcenter \
  -- corepack pnpm dlx @anthropic-ai/claude-code --dangerously-skip-permissions
