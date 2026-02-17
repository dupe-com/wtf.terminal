#!/usr/bin/env bash
# uninstall.sh — Remove wtf.terminal

set -euo pipefail

INSTALL_DIR="${WTF_INSTALL_DIR:-$HOME/.wtf-terminal}"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

info()  { printf '\033[1;36m%s\033[0m\n' "$*"; }

# Remove source line from .zshrc
if [[ -f "$ZSHRC" ]]; then
  # Remove the comment line and source line
  sed -i '' '/# wtf\.terminal/d' "$ZSHRC" 2>/dev/null
  sed -i '' '/wtf\.sh/d' "$ZSHRC" 2>/dev/null
  info "Removed from $ZSHRC"
fi

# Remove install dir
if [[ -d "$INSTALL_DIR" ]]; then
  rm -rf "$INSTALL_DIR"
  info "Removed $INSTALL_DIR"
fi

# Remove cache
if [[ -d "$HOME/.cache/wtf-terminal" ]]; then
  rm -rf "$HOME/.cache/wtf-terminal"
  info "Removed cache"
fi

info "wtf.terminal uninstalled. Restart your shell."
