# Auto-start Shepherd if not already running
if [ -z "$SHEPHERD_STARTED" ] && [ -S "$XDG_RUNTIME_DIR/shepherd/socket" ] || herd status >/dev/null 2>&1; then
    : # Shepherd is already running
else
    echo "Starting Shepherd..."
    shepherd --silent
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
