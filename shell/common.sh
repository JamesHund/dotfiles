# Shared, shell-agnostic config. Sourced by both bash and zsh on every system.

export DOTFILES="${DOTFILES:-$HOME/dotfiles}"

export EDITOR="${EDITOR:-nvim}"
export VISUAL="$EDITOR"

# Use the starship config tracked in this repo.
[ -f "$DOTFILES/starship.toml" ] && export STARSHIP_CONFIG="$DOTFILES/starship.toml"

# Prepend a dir to PATH only if it exists and isn't already there.
for _d in "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.npm-global/bin"; do
  case ":$PATH:" in
    *":$_d:"*) ;;
    *) [ -d "$_d" ] && PATH="$_d:$PATH" ;;
  esac
done
unset _d
export PATH

# --- aliases (guarded so they apply only when the tool is installed) -------
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -lah --group-directories-first --git --icons=auto'
  alias la='eza -a --group-directories-first --icons=auto'
  alias l='eza -F --icons=auto'
  alias lt='eza --tree --level=2 --icons=auto'
  alias tree='eza --tree --icons=auto'
fi

# On Debian/Ubuntu the binaries are batcat / fdfind.
command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1 && alias bat='batcat'
command -v fdfind >/dev/null 2>&1 && ! command -v fd  >/dev/null 2>&1 && alias fd='fdfind'

# cat -> bat (no pager). Use whichever binary exists.
if command -v batcat >/dev/null 2>&1; then
  alias cat='batcat --paging=never'
elif command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
fi

if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
  alias vi='nvim'
fi
command -v lazygit >/dev/null 2>&1 && alias lg='lazygit'
command -v xclip   >/dev/null 2>&1 && alias clip='xclip -selection clipboard'
