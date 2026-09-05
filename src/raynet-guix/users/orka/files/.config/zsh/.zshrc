  # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
  # Initialization code that may require console input (password prompts, [y/n]
  # confirmations, etc.) must go above this block; everything else may go below.
  #
  ##############GUIX##########

  GUIX_SESSION_PROFILE="$HOME/.session-profile"
  if [ -f "$GUIX_SESSION_PROFILE" ]; then
     source "$GUIX_SESSION_PROFILE"
  fi

 #export LD_LIBRARY_PATH="$HOME/.guix-home/profile/lib:$HOME/guix-system/env/profile/lib:$HOME/.guix-profile/lib:$HOME/.guix-profiles/orka-extra/lib:$LD_LIBRARY_PATH"

  #export GTK_IM_MODULE=fcitx
  #export QT_IM_MODULE=fcitx
  export XMODIFIERS=@im=fcitx
  export GLFW_IM_MODULE=fcitx

  export BROWSER=google-chrome

  export XDG_DATA_DIRS="$HOME/.local/share:$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS"
  export PATH=$PATH:$HOME/.npm-global/bin:$HOME/.local/bin:~/.cargo/bin:~/.npm-packages/bin:~/.config/emacs/bin/:~/.nix-profile/bin:~/.surrealdb

  export GIT_EXTERNAL_DIFF="difft --display=side-by-side"

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
if [[ "$TERM_PROGRAM" != "WarpTerminal" && -z "$WARP_BOOTSTRAPPED" ]]; then
  source ~/powerlevel10k/powerlevel10k.zsh-theme
fi

  # Enable Vi mode
  bindkey -v
  export KEYTIMEOUT=1

  # Change cursor shape for different vi modes
  # function zle-keymap-select {
  #   if [[ ${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
  #     echo -ne '\e[1 q' # Block
  #   elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || [[ ${KEYMAP} == "" ]] || [[ $1 = 'beam' ]]; then
  #     echo -ne '\e[5 q' # Beam
  #   fi
  # }
  # zle -N zle-keymap-select
  # _fix_cursor() { echo -ne '\e[5 q' } # Start with beam
  # precmd_functions+=(_fix_cursor)

  # Keybindings for autosuggestions in Vi mode
  # In Vi mode, we need to ensure right-arrow and Ctrl+F still work to accept suggestions
  bindkey -M viins '^f' vi-forward-word
  bindkey -M vicmd '^f' vi-forward-word

  # History configuration
  HISTFILE=$HOME/.config/zsh/.histfile
  HISTSIZE=10000
  SAVEHIST=10000
  setopt appendhistory
  setopt sharehistory
  setopt hist_ignore_dups
  setopt hist_ignore_space

  # Autosuggestions (installed via Guix)
  if [ -f "$HOME/.guix-home/profile/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$HOME/.guix-home/profile/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
  elif [ -f "/run/current-system/profile/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "/run/current-system/profile/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
  fi

  # Keybindings for autosuggestions
  # Right arrow or Ctrl+F to accept full suggestion
  # Alt+Right arrow to accept one word
  bindkey '^f' vi-forward-word

  #################
  # nix
  if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
  . ~/.nix-profile/etc/profile.d/nix.sh
  fi
  #
  # ################
  if [[ "$TERM_PROGRAM" != "WarpTerminal" && -z "$WARP_BOOTSTRAPPED" ]]; then
    if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
      source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
    fi
  fi


 # source $HOME/dotfiles/config/zsh/cachyos-config.zsh

  # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
  if [[ "$TERM_PROGRAM" != "WarpTerminal" && -z "$WARP_BOOTSTRAPPED" ]]; then
    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
  fi


  # BEGIN opam configuration
  # This is useful if you're using opam as it adds:
  #   - the correct directories to the PATH
  #   - auto-completion for the opam binary
  # This section can be safely removed at any time if needed.
  [[ ! -r '/home/orka/.opam/opam-init/init.zsh' ]] || source '/home/orka/.opam/opam-init/init.zsh' > /dev/null 2> /dev/null
  # END opam configuration

  #export HELIX_RUNTIME=~/workspace/helix/runtime
  export EDITOR=helix
  export VISUAL=helix


  source /home/orka/.config/broot/launcher/bash/br

  unset SSH_AGENT_PID
  if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
    export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
  fi
  if [[ -t 0 && "$TERM_PROGRAM" != "WarpTerminal" && -z "$WARP_BOOTSTRAPPED" ]]; then
    export GPG_TTY=$(tty 2>/dev/null)
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
  fi

  alias em="emacs -nw"
  alias tree="eza --tree -a --icons"
  alias la='eza -a --color=always --group-directories-first --icons'
  alias ll='eza -al --color=always --group-directories-first --icons'
  alias lt='eza -aT --color=always --group-directories-first --icons'
  alias element-desktop='element-desktop --password-store=gnome-libsecret'
  alias oculante='flatpak run io.github.woelper.Oculante'
  alias agy='/home/orka/.local/bin/agy-wrapper'
  alias surreal='/home/orka/.local/bin/surreal-wrapper'
  # `claude` resolves via PATH to the Guix package (claude-code-bin, shikanox channel).
  # `claude-latest` runs the native self-updating install (`claude-latest update` to bump).
  alias claude-latest="$HOME/.local/bin/claude-latest"
  alias claude-container='claude-code.sh'
  alias claude-nocontainer='claude-code-nocontainer.sh'
  alias pi='LD_LIBRARY_PATH=/gnu/store/m31vlvwm79m89fk3xk0z4h7snk61y510-glibc-2.41/lib:/home/orka/.guix-home/profile/lib:$LD_LIBRARY_PATH /gnu/store/m31vlvwm79m89fk3xk0z4h7snk61y510-glibc-2.41/lib/ld-linux-x86-64.so.2 $HOME/.local/bin/pi'

  # Navigation
  alias ..='cd ..'
  alias ...='cd ../..'
  alias ....='cd ../../..'

  # Git shortcuts
  alias gs='git status'
  alias ga='git add'
  alias gc='git commit'
  alias gp='git push'
  alias gl='git pull'

  # Functions
  backup() { cp "$1" "$1.bak"; }
  mkcd() { mkdir -p "$1" && cd "$1"; }
  extract() {
    if [ -f "$1" ]; then
      case "$1" in
        *.tar.bz2) tar xjf "$1" ;;
        *.tar.gz)  tar xzf "$1" ;;
        *.bz2)     bunzip2 "$1" ;;
        *.rar)     unrar x "$1" ;;
        *.gz)      gunzip "$1" ;;
        *.tar)     tar xvf "$1" ;;
        *.tbz2)    tar xjf "$1" ;;
        *.tgz)     tar xzf "$1" ;;
        *.zip)     unzip "$1" ;;
        *.Z)       uncompress "$1" ;;
        *.7z)      7z x "$1" ;;
        *)         echo "'$1' cannot be extracted via extract()" ;;
      esac
    else
      echo "'$1' is not a valid file"
    fi
  }

  #export ZELLIJ=zellij
  #export ZELLIJ_SESSION_NAME=main

  # if [[ -z "$ZELLIJ" ]]; then
  #     if [[ "$ZELLIJ_AUTO_ATTACH" == "true" ]]; then
  #         zellij attach -c
  #     else
  #         zellij
  #     fi
  #
  #     if [[ "$ZELLIJ_AUTO_EXIT" == "true" ]]; then
  #         exit
  #     fi
  # fi

source /home/orka/.config/broot/launcher/bash/br


# To customize prompt, run `p10k configure` or edit ~/.config/zsh/.p10k.zsh.
if [[ "$TERM_PROGRAM" != "WarpTerminal" && -z "$WARP_BOOTSTRAPPED" ]]; then
  [[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh
fi
