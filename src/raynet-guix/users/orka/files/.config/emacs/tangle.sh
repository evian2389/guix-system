#!/usr/bin/env bash
# Script to tangle Emacs.org configuration file in the current directory

set +x

cd "$(dirname "$0")"

echo "Tangling Emacs.org configuration..."
# Use Emacs to tangle the file
emacs -Q --batch \
  --eval "(require 'ob-tangle)" \
  --eval "(org-babel-tangle-file \"Emacs.org\")" \
  --kill

echo "Configuration tangled successfully!"

stow --adopt -d /home/orka/guix-system/src/raynet-guix/users/orka -t /home/orka files
