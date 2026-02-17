#!/usr/bin/env bash
# install.sh — Install wtf.terminal
# Usage:
#   curl -sSL https://raw.githubusercontent.com/ramin/wtf.terminal/main/install.sh | bash
#   — or —
#   git clone ... && ./install.sh

set -euo pipefail

REPO="dupe-com/wtf.terminal"
INSTALL_DIR="${WTF_INSTALL_DIR:-$HOME/.wtf-terminal}"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

info()  { printf '\033[1;36m%s\033[0m\n' "$*"; }
error() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; }

# --- Preflight checks ---

if ! command -v jq &>/dev/null; then
  error "wtf.terminal requires jq"
  echo "  brew install jq    # macOS"
  echo "  apt install jq     # debian/ubuntu"
  exit 1
fi

if ! command -v git &>/dev/null; then
  error "git is required to install wtf.terminal"
  exit 1
fi

# --- Download / Update ---

if [[ -d "$INSTALL_DIR/.git" ]]; then
  info "Updating wtf.terminal..."
  git -C "$INSTALL_DIR" pull --ff-only --quiet
else
  info "Installing wtf.terminal to $INSTALL_DIR..."
  rm -rf "$INSTALL_DIR"
  git clone --depth 1 "https://github.com/$REPO.git" "$INSTALL_DIR" --quiet
fi

# --- Wire into .zshrc ---

SOURCE_LINE="source \"$INSTALL_DIR/wtf.sh\""

if [[ -f "$ZSHRC" ]] && grep -qF "wtf.sh" "$ZSHRC" 2>/dev/null; then
  info "Already in .zshrc — skipped"
else
  printf '\n# wtf.terminal — context recall for terminal sessions\n%s\n' "$SOURCE_LINE" >> "$ZSHRC"
  info "Added to $ZSHRC"
fi

# --- Done ---

info "Done! Open a new terminal or run:"
echo "  source $ZSHRC"
echo ""
echo "Then type ? in any directory with Claude Code sessions."
