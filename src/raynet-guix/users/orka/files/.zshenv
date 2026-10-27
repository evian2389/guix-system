if [ -z "$ZDOTDIR" ]; then
    export ZDOTDIR=${XDG_CONFIG_HOME:-$HOME/.config}/zsh
fi
# /etc/profile uses /etc/profile.d/*.sh; zsh's NOMATCH option errors when
# that directory has no matching files. This runs before the global zprofile.
setopt nonomatch
if [ -x /bin/zsh ]; then
    export SHELL="/bin/zsh"
elif [ -x /run/current-system/profile/bin/zsh ]; then
    export SHELL="/run/current-system/profile/bin/zsh"
fi
