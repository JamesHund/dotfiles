# macOS ~/.bashrc
# Note: login shells read ~/.bash_profile, not ~/.bashrc. Add this to
# ~/.bash_profile:   [ -r ~/.bashrc ] && source ~/.bashrc
[[ $- != *i* ]] && return   # interactive shells only

export DOTFILES="${DOTFILES:-$HOME/dotfiles}"

# Homebrew on PATH (Apple Silicon first, then Intel).
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

source "$DOTFILES/shell/common.sh"
source "$DOTFILES/shell/bash.sh"
