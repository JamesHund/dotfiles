#!/usr/bin/env bash
#
# Deploy dotfiles. Two strategies:
#   shell rc files (.bashrc/.zshrc)   -> a managed source-block in your REAL
#                                        ~/.bashrc/~/.zshrc (NOT a symlink), so
#                                        installers that append to them can't
#                                        sever a link or pollute the repo.
#   config files (alacritty/starship) -> symlinked into ~/.config.
#
# Re-running is safe: the managed block is refreshed in place and everything
# else in the file (including lines appended by installers) is preserved.
#
# Usage:
#   ./link.sh                 interactive
#   ./link.sh --dry-run       show what would happen, change nothing
#   ./link.sh --os <name>     force arch | ubuntu | mac
#   ./link.sh --help
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0
FORCE_OS=""

BLOCK_BEGIN="# >>> dotfiles (managed by link.sh) >>>"
BLOCK_END="# <<< dotfiles <<<"

if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  GREEN=$'\033[32m'; RED=$'\033[31m'; CYAN=$'\033[36m'; YELLOW=$'\033[33m'
else
  BOLD=; DIM=; RESET=; GREEN=; RED=; CYAN=; YELLOW=
fi
info() { printf '%s%s%s\n' "$DIM" "$1" "$RESET"; }
ok()   { printf '%s%s%s\n' "$GREEN" "$1" "$RESET"; }
warn() { printf '%s%s%s\n' "$YELLOW" "$1" "$RESET"; }
err()  { printf '%s%s%s\n' "$RED" "$1" "$RESET" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# Link only if $1 is on PATH; otherwise print a skip note.
link_if_installed() {
  local tool="$1" src="$2" dst="$3"
  if have "$tool"; then
    process_link "$src" "$dst"
  else
    info "skip ($tool not installed): $dst"
  fi
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo mac ;;
    Linux)
      if [ -r /etc/os-release ]; then
        . /etc/os-release
        case "$ID $ID_LIKE" in
          *arch*|*manjaro*|*endeavouros*|*cachyos*) echo arch ;;
          *ubuntu*|*debian*|*pop*|*mint*)           echo ubuntu ;;
          *) echo unknown ;;
        esac
      else echo unknown; fi ;;
    *) echo unknown ;;
  esac
}

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; }

# The managed block written into the real ~/.bashrc / ~/.zshrc.
make_block() {
  local repo_rc="$1"
  cat <<EOF
$BLOCK_BEGIN
export DOTFILES="$REPO"
[ -f "$repo_rc" ] && . "$repo_rc"
$BLOCK_END
EOF
}

# Migrate an existing, unmanaged rc file (interactive).
migrate_rc() {
  local rc="$1" repo_rc="$2"
  warn "  $rc exists and isn't managed yet."
  warn "  (Machine-specific lines belong in ${rc}.local, which the repo sources.)"
  while true; do
    printf '  %s[r]%s replace with clean stub  %s[a]%s append block, keep current  %s[v]%s view  %s[s]%s skip  %s[q]%s quit > ' \
      "$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET"
    local ans=""
    IFS= read -r ans </dev/tty || ans=q
    case "$ans" in
      r) make_block "$repo_rc" > "$rc"; ok "  replaced with clean stub: $rc"; return ;;
      a) printf '\n' >> "$rc"; make_block "$repo_rc" >> "$rc"; ok "  appended block to: $rc"; return ;;
      v) if command -v less >/dev/null 2>&1; then less "$rc" </dev/tty >/dev/tty 2>&1; else cat "$rc"; fi ;;
      s) info "  skipped: $rc"; return ;;
      q) echo "Aborted."; exit 0 ;;
      *) ;;
    esac
  done
}

# Ensure the managed source-block is present in a real rc file.
ensure_block() {
  local rc="$1" repo_rc="$2"
  [ -e "$repo_rc" ] || { err "missing in repo: $repo_rc"; return; }

  if [ ! -e "$rc" ]; then
    if [ "$DRY" = 1 ]; then warn "would create $rc with the dotfiles source-block"; return; fi
    make_block "$repo_rc" > "$rc"; ok "created: $rc"; return
  fi

  if grep -qF "$BLOCK_BEGIN" "$rc"; then
    # Managed already: refresh just the block, preserve everything else.
    if [ "$DRY" = 1 ]; then info "ok (managed): $rc — would refresh the dotfiles block"; return; fi
    local tmp; tmp="$(mktemp)"
    awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
      $0==b {skip=1}
      skip!=1 {print}
      $0==e {skip=0; next}
    ' "$rc" > "$tmp"
    make_block "$repo_rc" >> "$tmp"
    mv "$tmp" "$rc"
    ok "refreshed dotfiles block in: $rc"; return
  fi

  # Unmanaged existing file.
  if [ "$DRY" = 1 ]; then warn "DIFFERS: $rc is unmanaged (would prompt: replace / append / skip)"; return; fi
  warn "unmanaged: $rc"
  migrate_rc "$rc" "$repo_rc"
}

# --- symlinked config files (alacritty, starship) --------------------------
reconcile() {
  local dst="$1" src="$2"
  warn "  differs from repo copy:"
  while true; do
    printf '  %s[d]%s diff  %s[e]%s edit repo copy  %s[k]%s keep repo & link  %s[s]%s skip  %s[q]%s quit > ' \
      "$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET"
    local ans=""
    IFS= read -r ans </dev/tty || ans=q
    case "$ans" in
      d) diff -u "$dst" "$src" || true ;;
      e) "${EDITOR:-vi}" "$src" </dev/tty >/dev/tty 2>&1
         if diff -q "$dst" "$src" >/dev/null 2>&1; then ok "  repo copy now matches the old file."; fi ;;
      k|"") return 0 ;;
      s) return 1 ;;
      q) echo "Aborted."; exit 0 ;;
      *) ;;
    esac
  done
}

process_link() {
  local src="$REPO/$1" dst="$2"
  [ -e "$src" ] || { err "missing in repo: $1"; return; }

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    info "ok (already linked): $dst"; return
  fi

  local parent; parent="$(dirname "$dst")"

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    if diff -q "$dst" "$src" >/dev/null 2>&1; then
      info "identical, will relink: $dst"
    else
      if [ "$DRY" = 1 ]; then
        warn "DIFFERS: $dst vs repo ($1)  (would prompt to reconcile, then link)"
        diff -u "$dst" "$src" || true
        return
      fi
      warn "conflict: $dst"
      reconcile "$dst" "$src" || { info "skipped: $dst"; return; }
    fi
  fi

  if [ "$DRY" = 1 ]; then
    warn "would link: $dst -> $src"
    [ -d "$parent" ] || warn "would create dir: $parent"
    return
  fi

  [ -d "$parent" ] || mkdir -p "$parent"
  rm -f "$dst"
  ln -s "$src" "$dst"
  ok "linked: $dst -> $src"
}

# On macOS, login shells read ~/.bash_profile, not ~/.bashrc.
ensure_bash_profile() {
  local bp="$HOME/.bash_profile" line='[ -r ~/.bashrc ] && source ~/.bashrc'
  if [ -f "$bp" ] && grep -qF 'source ~/.bashrc' "$bp"; then
    info "ok: ~/.bash_profile already sources ~/.bashrc"; return
  fi
  if [ "$DRY" = 1 ]; then warn "would ensure ~/.bash_profile sources ~/.bashrc"; return; fi
  printf '%s\n' "$line" >> "$bp"
  ok "updated: ~/.bash_profile now sources ~/.bashrc"
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) DRY=1 ;;
      --os) shift; FORCE_OS="${1:-}" ;;
      -h|--help) usage; exit 0 ;;
      *) err "unknown option: $1"; usage; exit 2 ;;
    esac
    shift
  done

  local os="${FORCE_OS:-$(detect_os)}"
  case "$os" in
    arch|ubuntu|mac) ;;
    *) err "could not detect a supported OS; pass --os arch|ubuntu|mac"; exit 1 ;;
  esac

  printf '%sLinking dotfiles%s  %s(os: %s, repo: %s)%s\n' "$BOLD" "$RESET" "$DIM" "$os" "$REPO" "$RESET"
  [ "$DRY" = 1 ] && warn "dry run — no changes will be made"
  echo

  # Only link configs for tools that are actually installed.
  if have bash; then ensure_block "$HOME/.bashrc" "$REPO/shell/$os/.bashrc"
  else               info "skip (bash not installed): $HOME/.bashrc"; fi
  if have zsh;  then ensure_block "$HOME/.zshrc"  "$REPO/shell/$os/.zshrc"
  else               info "skip (zsh not installed): $HOME/.zshrc"; fi

  link_if_installed alacritty ".config/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
  link_if_installed nvim      ".config/nvim/init.lua"            "$HOME/.config/nvim/init.lua"
  link_if_installed starship  "starship.toml"                    "$HOME/.config/starship.toml"

  # Ghostty config: macOS reads from Application Support; linux uses XDG.
  if [ "$os" = mac ]; then
    link_if_installed ghostty ".config/ghostty/config.ghostty" \
      "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
  else
    link_if_installed ghostty ".config/ghostty/config.ghostty" \
      "$HOME/.config/ghostty/config.ghostty"
  fi

  [ "$os" = mac ] && have bash && { echo; ensure_bash_profile; }

  echo
  ok "Done."
}

main "$@"
