# Arch Linux ~/.bashrc
[[ $- != *i* ]] && return   # interactive shells only

export DOTFILES="${DOTFILES:-$HOME/dotfiles}"

source "$DOTFILES/shell/common.sh"
source "$DOTFILES/shell/bash.sh"
