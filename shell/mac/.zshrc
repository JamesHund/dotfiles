# macOS ~/.zshrc  (zsh is the default login shell on macOS)
export DOTFILES="${DOTFILES:-$HOME/dotfiles}"

# Homebrew on PATH (Apple Silicon first, then Intel).
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

source "$DOTFILES/shell/common.sh"
source "$DOTFILES/shell/zsh.sh"

# Anaconda (only if installed at the Homebrew prefix).
if [ -d /opt/homebrew/anaconda3 ]; then
  __conda_setup="$('/opt/homebrew/anaconda3/bin/conda' 'shell.zsh' 'hook' 2>/dev/null)"
  if [ $? -eq 0 ]; then
    eval "$__conda_setup"
  elif [ -f /opt/homebrew/anaconda3/etc/profile.d/conda.sh ]; then
    . /opt/homebrew/anaconda3/etc/profile.d/conda.sh
  else
    export PATH="/opt/homebrew/anaconda3/bin:$PATH"
  fi
  unset __conda_setup
fi

# Azure CLI bash-style completion (az is distributed without a native zsh completion).
if command -v az >/dev/null 2>&1; then
  _az_comp="$(brew --prefix 2>/dev/null)/etc/bash_completion.d/az"
  if [ -f "$_az_comp" ]; then
    autoload -U bashcompinit && bashcompinit
    source "$_az_comp"
  fi
  unset _az_comp
fi
