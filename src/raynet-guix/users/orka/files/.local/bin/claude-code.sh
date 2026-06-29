#!/usr/bin/env bash

# Build arguments for guix shell
args=(
  --container
  --emulate-fhs
  --link-profile
  --network
  --preserve='^DBUS_SESSION_BUS_ADDRESS'
  --preserve='^COLORTERM'
  --preserve='^PATH'
  --preserve='^SSH_AUTH_SOCK'
  --preserve='^XDG_RUNTIME_DIR'
  --preserve='^TERM'
  --preserve='^ANTHROPIC_API_KEY'
  --preserve='^OPENAI_API_KEY'
  --preserve='^GOOGLE_API_KEY'
  --preserve='^LANG'
  --preserve='^LC_'
  --preserve='^DOCKER_HOST'
  --preserve='^USER'
  --preserve='^SHELL'
  --preserve='^HOME'
)

# Function to add expose/share if path exists
add_mount() {
  local type="$1"
  local src="$2"
  local dst="$3"
  if [ -n "$src" ] && [ -e "$src" ]; then
    args+=("$type=$src=$dst")
  fi
}

add_mount --expose "$HOME/.gitconfig" "$HOME/.gitconfig"
add_mount --expose "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK"
add_mount --expose "$HOME/.ssh" "$HOME/.ssh"
add_mount --expose "/var/run/docker.sock" "/var/run/docker.sock"
add_mount --share "$HOME/.claude" "$HOME/.claude"
add_mount --share "$HOME/.claude.json" "$HOME/.claude.json"
add_mount --share "$HOME/.config/claude" "$HOME/.config/claude"
add_mount --share "$HOME/.config/cron" "$HOME/.config/cron"
add_mount --share "$HOME/.cache/pnpm" "$HOME/.cache/pnpm"
add_mount --share "$HOME/.local/share/pnpm" "$HOME/.local/share/pnpm"
add_mount --share "/nix" "/nix"
add_mount --expose "$XDG_RUNTIME_DIR" "$XDG_RUNTIME_DIR"
add_mount --share "$HOME/work" "$HOME/work"

packages=(
  nss-certs coreutils bash grep sed gawk git openssh-sans-x node
  libcap openssl gcc-toolchain zlib go nginx docker-cli esbuild jq python
)

# Construct the command to run inside script
# Using printf %q to ensure proper escaping of all arguments
inner_cmd=("guix" "shell" "${args[@]}" "${packages[@]}" "--" "env" "DISABLE_AUTOUPDATER=1" "corepack" "pnpm" "dlx" "@anthropic-ai/claude-code@latest" "--dangerously-skip-permissions" "$@")

script -qec "$(printf "%q " "${inner_cmd[@]}")" /dev/null
