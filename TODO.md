
# What is this?
* Description of current working plan to make things done

#  Prerequisite
* check README.md - Overview and Structure


# TODO
* Make emacs org usable.
** Major working dir : src/raynet-guix/users/orka/files/emacs
** Apply and validatioan :
  - chnages to src/raynet-guix/users/orka/files/.config/emacs/Emacs.org
  - apply it : src/raynet-guix/users/orka/files/.config/emacs/tangle.sh
  - if guix package changed : use 'make reconfigure-home' on Makefile in project root.
*** Current focus :
    - gather project related command to SPC-p
    - Adopt emacs config of src/raynet-guix/users/orka/files/.config/emacs/20250915140606-dotfiles.org to src/raynet-guix/users/orka/files/.config/emacs/Emacs.org
    - apply changes with tangle.sh then check emacs error (emacs -nw --debug-init).
* Installing emacs pacakges.
  - use src/raynet-guix/home-services/emacs.scm (use 'guix search [package]' to check if the package is available)

# recorcd current status
* record current working status here for later use.
  - applied emacs-meow (dw-meow.el)
  - fixed syntax error in dw-meow.el (extra parenthesis and void variable meow-leader-keymap)

