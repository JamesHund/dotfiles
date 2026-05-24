# Ubuntu/Debian ~/.bashrc
[[ $- != *i* ]] && return   # interactive shells only

export DOTFILES="${DOTFILES:-$HOME/dotfiles}"

# Make less friendly for non-text input files (Debian default).
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

source "$DOTFILES/shell/common.sh"
source "$DOTFILES/shell/bash.sh"
