#!/usr/bin/env bash
#
# Dotfiles package installer — pure-bash TUI.
# Detects the OS (arch / ubuntu / mac), installs the selected tools via
# pacman / apt / brew, then links the dotfiles into place. bash 3.2 compatible.
#
# Tools already present on the system are pre-checked in the TUI.
#
# Usage:
#   ./install.sh            interactive TUI (installs selected, then links)
#   ./install.sh --all      install everything + link, no prompt
#   ./install.sh --list     print the package table and exit
#   ./install.sh --help

# ---------------------------------------------------------------------------
# Package table — edit this to change what the installer offers.
# Format:  name|description|pacman pkg|apt pkg|brew pkg|check commands
# - Use CUSTOM as the apt package to install via a fallback (see install_one).
# - "check commands" are space-separated binaries; if any is on PATH the
#   package counts as already installed (and is pre-checked in the TUI).
# ---------------------------------------------------------------------------
PACKAGES=(
  "eza|Modern ls replacement|eza|eza|eza|eza"
  "bat|cat with syntax highlighting|bat|bat|bat|bat batcat"
  "fd|Fast, friendly find|fd|fd-find|fd|fd fdfind"
  "ripgrep|Fast recursive grep (rg)|ripgrep|ripgrep|ripgrep|rg"
  "fzf|Fuzzy finder|fzf|fzf|fzf|fzf"
  "zoxide|Smarter cd that learns|zoxide|zoxide|zoxide|zoxide"
  "starship|Cross-shell prompt|starship|CUSTOM|starship|starship"
  "git-delta|Syntax-highlighted git diffs|git-delta|git-delta|git-delta|delta"
  "neovim|Hyperextensible vim|neovim|neovim|neovim|nvim"
  "tmux|Terminal multiplexer|tmux|tmux|tmux|tmux"
  "lazygit|Terminal UI for git|lazygit|CUSTOM|lazygit|lazygit"
  "ghostty|Fast, native terminal emulator|ghostty|CUSTOM|cask:ghostty|ghostty"
  "geist-mono-nerd|GeistMono Nerd Font (for terminals)|CUSTOM|CUSTOM|cask:font-geist-mono-nerd-font|file:~/Library/Fonts/GeistMonoNerdFontMono-Regular.otf file:~/.local/share/fonts/GeistMonoNerdFontMono-Regular.otf"
)

# --- colors ---------------------------------------------------------------
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'; REV=$'\033[7m'
  GREEN=$'\033[32m'; RED=$'\033[31m'; CYAN=$'\033[36m'; YELLOW=$'\033[33m'
else
  BOLD=; DIM=; RESET=; REV=; GREEN=; RED=; CYAN=; YELLOW=
fi

# --- OS detection ----------------------------------------------------------
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
      else
        echo unknown
      fi
      ;;
    *) echo unknown ;;
  esac
}

os_pretty() {
  case "$1" in
    arch)   echo "Arch (pacman)" ;;
    ubuntu) echo "Ubuntu/Debian (apt)" ;;
    mac)    echo "macOS (brew)" ;;
    *)      echo "unknown OS" ;;
  esac
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# is_installed "<space-separated tokens>" -> 0 if any matches.
# Tokens: bare name (checked with command -v), or "file:<path>" (path exists).
is_installed() {
  local c p
  for c in $1; do
    case "$c" in
      file:*) p="${c#file:}"; p="${p/#\~/$HOME}"; [ -e "$p" ] && return 0 ;;
      *)      command -v "$c" >/dev/null 2>&1 && return 0 ;;
    esac
  done
  return 1
}

# --- Ubuntu fallbacks for packages not in apt ------------------------------
install_starship_ubuntu() {
  command -v curl >/dev/null 2>&1 || sudo apt-get install -y curl || return 1
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
}

install_geist_mono_nerd_linux() {
  command -v curl  >/dev/null 2>&1 || { echo "curl required" >&2; return 1; }
  command -v unzip >/dev/null 2>&1 || { echo "unzip required" >&2; return 1; }
  local dest="$HOME/.local/share/fonts" tmp rc
  mkdir -p "$dest" || return 1
  tmp=$(mktemp -d) || return 1
  curl -fsSL -o "$tmp/GeistMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/GeistMono.zip" \
    && unzip -o "$tmp/GeistMono.zip" -d "$dest" >/dev/null
  rc=$?
  [ $rc -eq 0 ] && command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1
  rm -rf "$tmp"
  return $rc
}

install_lazygit_ubuntu() {
  command -v curl >/dev/null 2>&1 || sudo apt-get install -y curl || return 1
  local ver arch tmp
  ver=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
          | grep -Po '"tag_name": *"v\K[^"]*')
  [ -n "$ver" ] || { echo "could not resolve lazygit version" >&2; return 1; }
  case "$(uname -m)" in
    x86_64|amd64)  arch=x86_64 ;;
    aarch64|arm64) arch=arm64 ;;
    armv*)         arch=armv6 ;;
    *)             arch=x86_64 ;;
  esac
  tmp=$(mktemp -d) || return 1
  curl -fsSL -o "$tmp/lazygit.tar.gz" \
    "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_Linux_${arch}.tar.gz" \
    && tar -xzf "$tmp/lazygit.tar.gz" -C "$tmp" lazygit \
    && sudo install "$tmp/lazygit" /usr/local/bin/lazygit
  local rc=$?
  rm -rf "$tmp"
  return $rc
}

# --- install a single package ----------------------------------------------
install_one() {
  local os="$1" name="$2" arch_pkg="$3" apt_pkg="$4" brew_pkg="$5"
  case "$os" in
    arch)
      if [ "$arch_pkg" = CUSTOM ]; then
        case "$name" in
          geist-mono-nerd) install_geist_mono_nerd_linux ;;
          *) echo "no fallback for $name" >&2; return 1 ;;
        esac
      else
        sudo pacman -S --needed --noconfirm "$arch_pkg"
      fi
      ;;
    mac)
      # cask:<name> uses `brew install --cask`; bare name uses formula install.
      case "$brew_pkg" in
        cask:*) brew install --cask "${brew_pkg#cask:}" ;;
        *)      brew install "$brew_pkg" ;;
      esac
      ;;
    ubuntu)
      if [ "$apt_pkg" = CUSTOM ]; then
        case "$name" in
          starship)        install_starship_ubuntu ;;
          lazygit)         install_lazygit_ubuntu ;;
          geist-mono-nerd) install_geist_mono_nerd_linux ;;
          *) echo "no fallback for $name" >&2; return 1 ;;
        esac
      else
        sudo apt-get install -y "$apt_pkg"
      fi
      ;;
    *) echo "unsupported OS" >&2; return 1 ;;
  esac
}

# --- run a command with a spinner; hide its output unless it fails ---------
spin() {
  local label="$1"; shift
  local log cr clr
  log="$(mktemp)"
  if [ -t 1 ]; then cr=$'\r'; clr=$'\033[K'; else cr=''; clr=''; fi

  "$@" >"$log" 2>&1 &
  local pid=$! frames='|/-\' i=0
  if [ -t 1 ]; then
    while kill -0 "$pid" 2>/dev/null; do
      i=$(( (i + 1) % 4 ))
      printf '\r  %s%s%s %s %s...%s' "$CYAN" "${frames:$i:1}" "$RESET" "$label" "$DIM" "$RESET"
      sleep 0.1
    done
  fi
  wait "$pid"; local rc=$?

  if [ "$rc" -eq 0 ]; then
    printf '%s  %s✓%s %s%s\n' "$cr" "$GREEN" "$RESET" "$label" "$clr"
  else
    printf '%s  %s✗ %s (failed)%s%s\n' "$cr" "$RED" "$label" "$RESET" "$clr"
    sed 's/^/      /' "$log"
  fi
  rm -f "$log"
  return "$rc"
}

# --- run the install for all selected packages -----------------------------
run_install() {
  local os="$1"; shift
  local sel=("$@")
  [ "${#sel[@]}" -gt 0 ] || { echo "Nothing selected."; return 0; }

  if [ "$os" = mac ] && ! command -v brew >/dev/null 2>&1; then
    echo "${RED}Homebrew not found.${RESET} Install it first: https://brew.sh"
    return 1
  fi

  # Authenticate sudo with a visible prompt, then keep the timestamp warm so
  # backgrounded installs under the spinner never block on a hidden prompt.
  local keepalive=""
  if [ "$os" = arch ] || [ "$os" = ubuntu ]; then
    sudo -v || { echo "${RED}sudo authentication failed.${RESET}" >&2; return 1; }
    ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
    keepalive=$!
  fi

  [ "$os" = ubuntu ] && spin "Updating package lists" sudo apt-get update -y

  local line name desc arch_pkg apt_pkg brew_pkg chk ok=0 fail=0 failed=""
  for line in "${sel[@]}"; do
    IFS='|' read -r name desc arch_pkg apt_pkg brew_pkg chk <<< "$line"
    if spin "$name" install_one "$os" "$name" "$arch_pkg" "$apt_pkg" "$brew_pkg"; then
      ok=$((ok + 1))
    else
      fail=$((fail + 1)); failed="$failed $name"
    fi
  done

  [ -n "$keepalive" ] && kill "$keepalive" 2>/dev/null

  printf '\n%sDone:%s %d installed, %d failed.\n' "$BOLD" "$RESET" "$ok" "$fail"
  [ -n "$failed" ] && printf '%sFailed:%s%s\n' "$YELLOW" "$RESET" "$failed"
  return 0
}

# --- TUI -------------------------------------------------------------------
CURSOR=0
SELECTED=()
INSTALLED=()

tui_cleanup() { printf '\033[?25h\033[?1049l'; }   # show cursor, leave alt screen

# bash 3.2 (stock macOS) only accepts integer read timeouts; 4.0+ allows fractions.
if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then ESC_TIMEOUT=0.01; else ESC_TIMEOUT=1; fi

read_key() {
  KEY=""
  IFS= read -rsn1 KEY 2>/dev/null || { KEY=q; return; }
  if [ "$KEY" = $'\033' ]; then
    local rest=""
    IFS= read -rsn2 -t "$ESC_TIMEOUT" rest 2>/dev/null
    KEY="$KEY$rest"
  fi
}

draw() {
  printf '\033[H'
  printf '%s%sDotfiles package installer%s  %s(%s)%s\033[K\n' \
    "$BOLD" "$CYAN" "$RESET" "$DIM" "$OS_PRETTY" "$RESET"
  printf '%s↑/↓ move · space toggle · a all · n none · enter install+link · q quit%s\033[K\n' "$DIM" "$RESET"
  printf '\033[K\n'

  local i name desc rest mark itag
  for i in "${!PACKAGES[@]}"; do
    IFS='|' read -r name desc rest <<< "${PACKAGES[$i]}"
    mark=' '; [ "${SELECTED[$i]}" = 1 ] && mark='x'
    itag=""
    if [ "${INSTALLED[$i]}" = 1 ]; then
      if [ "$i" -eq "$CURSOR" ]; then itag=" (installed)"; else itag=" ${GREEN}(installed)${RESET}"; fi
    fi
    if [ "$i" -eq "$CURSOR" ]; then
      printf '%s> [%s] %-10s %s%s%s\033[K\n' "$REV" "$mark" "$name" "$desc" "$itag" "$RESET"
    elif [ "$mark" = x ]; then
      printf '  [%sx%s] %-10s %s%s%s%s\033[K\n' "$GREEN" "$RESET" "$name" "$DIM" "$desc" "$RESET" "$itag"
    else
      printf '  [ ] %-10s %s%s%s%s\033[K\n' "$name" "$DIM" "$desc" "$RESET" "$itag"
    fi
  done
  printf '\033[J'
}

tui_loop() {
  trap tui_cleanup EXIT
  printf '\033[?1049h\033[?25l\033[2J'   # alt screen, hide cursor, clear
  local last=$(( ${#PACKAGES[@]} - 1 ))
  while true; do
    draw
    read_key
    case "$KEY" in
      $'\033[A'|k) [ "$CURSOR" -gt 0 ]     && CURSOR=$((CURSOR-1)) ;;
      $'\033[B'|j) [ "$CURSOR" -lt "$last" ] && CURSOR=$((CURSOR+1)) ;;
      ' ') [ "${SELECTED[$CURSOR]}" = 1 ] && SELECTED[$CURSOR]=0 || SELECTED[$CURSOR]=1 ;;
      a|A) local i; for i in "${!SELECTED[@]}"; do SELECTED[$i]=1; done ;;
      n|N) local i; for i in "${!SELECTED[@]}"; do SELECTED[$i]=0; done ;;
      "")  trap - EXIT; tui_cleanup; return 0 ;;   # Enter -> confirm
      q|Q) trap - EXIT; tui_cleanup; echo "Aborted."; exit 0 ;;
    esac
  done
}

# --- helpers ---------------------------------------------------------------
selected_lines() {
  local i
  for i in "${!PACKAGES[@]}"; do
    [ "${SELECTED[$i]}" = 1 ] && printf '%s\n' "${PACKAGES[$i]}"
  done
}

print_list() {
  printf '%-12s %-40s %-10s %-10s %-10s\n' NAME DESCRIPTION PACMAN APT BREW
  local line name desc a b c chk
  for line in "${PACKAGES[@]}"; do
    IFS='|' read -r name desc a b c chk <<< "$line"
    printf '%-12s %-40s %-10s %-10s %-10s\n' "$name" "$desc" "$a" "$b" "$c"
  done
}

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
}

# --- main ------------------------------------------------------------------
main() {
  local mode=tui
  case "${1:-}" in
    --all)  mode=all ;;
    --list) print_list; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    "") ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac

  OS=$(detect_os)
  OS_PRETTY=$(os_pretty "$OS")
  if [ "$OS" = unknown ]; then
    echo "${RED}Could not detect a supported OS (arch/ubuntu/mac).${RESET}" >&2
    exit 1
  fi

  # Detect what's already installed; pre-check those in the TUI.
  local i chk
  for i in "${!PACKAGES[@]}"; do
    IFS='|' read -r _ _ _ _ _ chk <<< "${PACKAGES[$i]}"
    if is_installed "$chk"; then INSTALLED[$i]=1; else INSTALLED[$i]=0; fi
    if [ "$mode" = all ]; then SELECTED[$i]=1; else SELECTED[$i]="${INSTALLED[$i]}"; fi
  done

  if [ "$mode" = tui ]; then
    if [ ! -t 0 ] || [ ! -t 1 ]; then
      echo "Not a terminal — use --all to install non-interactively." >&2
      exit 1
    fi
    tui_loop
  fi

  local sel=()
  while IFS= read -r line; do [ -n "$line" ] && sel+=("$line"); done < <(selected_lines)

  run_install "$OS" "${sel[@]}"

  # Link the dotfiles into place.
  if [ -x "$SCRIPT_DIR/link.sh" ]; then
    printf '\n%s== Linking dotfiles ==%s\n' "$BOLD$CYAN" "$RESET"
    "$SCRIPT_DIR/link.sh" --os "$OS"
  else
    echo "${YELLOW}link.sh not found or not executable; skipping dotfile linking.${RESET}" >&2
  fi
}

main "$@"
