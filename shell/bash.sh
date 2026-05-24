# Bash-only interactive settings + tool init.

HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth
shopt -s histappend
shopt -s checkwinsize
shopt -s autocd 2>/dev/null

command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
command -v zoxide   >/dev/null 2>&1 && eval "$(zoxide init bash)"

# fzf integration. `fzf --bash` exists on 0.48+; older packages ship sourceable files.
if command -v fzf >/dev/null 2>&1; then
  if fzf --bash >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  else
    for _f in /usr/share/doc/fzf/examples/key-bindings.bash \
              /usr/share/fzf/key-bindings.bash \
              /usr/share/doc/fzf/examples/completion.bash \
              /usr/share/fzf/completion.bash; do
      [ -f "$_f" ] && source "$_f"
    done
    unset _f
  fi
fi

# Machine-local, untracked overrides (conda, secrets, per-host PATH, ...).
[ -f "$HOME/.bashrc.local" ] && source "$HOME/.bashrc.local"
