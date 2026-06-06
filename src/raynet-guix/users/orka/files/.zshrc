# Auto-start Shepherd via guix home on-first-login (loads proper config with all services)
if [ -f "$HOME/.guix-home/on-first-login" ]; then
    "$HOME/.guix-home/on-first-login"
fi

unset SSH_AGENT_PID
if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
fi
export GPG_TTY=$(tty)
gpg-connect-agent updatestartuptty /bye >/dev/null

# OpenClaw Completion
if [ -f "/home/orka/.openclaw/completions/openclaw.zsh" ]; then
    source "/home/orka/.openclaw/completions/openclaw.zsh"
fi
\n# npm global binaries\nexport PATH="$HOME/.npm-global/bin:$PATH"

# Added by Helix CLI installer
export PATH="$HOME/.local/bin:$PATH"
