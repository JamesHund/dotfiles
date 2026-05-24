# Zsh-only interactive settings + tool init.

HISTSIZE=10000
SAVEHIST=20000
HISTFILE="$HOME/.zsh_history"
setopt append_history share_history hist_ignore_all_dups hist_ignore_space
setopt autocd

autoload -Uz compinit && compinit

command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide   >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# fzf integration. `fzf --zsh` exists on 0.48+; older packages ship sourceable files.
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    eval "$(fzf --zsh)"
  else
    for _f in /usr/share/doc/fzf/examples/key-bindings.zsh \
              /usr/share/fzf/key-bindings.zsh \
              /usr/share/doc/fzf/examples/completion.zsh \
              /usr/share/fzf/completion.zsh; do
      [ -f "$_f" ] && source "$_f"
    done
    unset _f
  fi
fi

# Machine-local, untracked overrides (conda, secrets, per-host PATH, ...).
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
