if [ -z "$ZDOTDIR" ]; then
    export ZDOTDIR=${XDG_CONFIG_HOME:-$HOME/.config}/zsh
fi
if [ -x /bin/zsh ]; then
    export SHELL="/bin/zsh"
elif [ -x /run/current-system/profile/bin/zsh ]; then
    export SHELL="/run/current-system/profile/bin/zsh"
fi
