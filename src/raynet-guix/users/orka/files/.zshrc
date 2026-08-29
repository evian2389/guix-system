# Auto-start Shepherd via guix home on-first-login (loads proper config with all services)
if [ -f "$HOME/.guix-home/on-first-login" ]; then
    "$HOME/.guix-home/on-first-login"
fi

unset SSH_AGENT_PID
if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket 2>/dev/null)"
fi
if [[ -t 0 && "$TERM_PROGRAM" != "WarpTerminal" && -z "$WARP_BOOTSTRAPPED" ]]; then
  export GPG_TTY=$(tty 2>/dev/null)
  gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
fi

# OpenClaw Completion
if [ -f "/home/orka/.openclaw/completions/openclaw.zsh" ]; then
    autoload -U compinit && compinit -u
    source "/home/orka/.openclaw/completions/openclaw.zsh"
fi

# npm global binaries
export PATH="$HOME/.npm-global/bin:$PATH"

# Added by Helix CLI installer
export PATH="$HOME/.local/bin:$PATH"
