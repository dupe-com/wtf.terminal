#!/usr/bin/env zsh
# wtf-terminal.sh — Terminal detection + escape-sequence features
# Supports: iTerm2, Ghostty, generic (xterm-compatible)
#
# All functions are safe no-ops if the terminal doesn't support the feature.

# ── Detection ────────────────────────────────────────────────────────

# Detect which terminal we're running in. Sets WTF_TERMINAL to one of:
#   iterm2, ghostty, generic
# Call once at source time; result is cached.
wtf_detect_terminal() {
  if [[ -n "$WTF_TERMINAL" ]]; then
    return  # already detected
  fi

  if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
    WTF_TERMINAL="iterm2"
  elif [[ "$TERM_PROGRAM" == "ghostty" ]]; then
    WTF_TERMINAL="ghostty"
  else
    WTF_TERMINAL="generic"
  fi
}

# Check if a feature is available in the current terminal.
# Usage: wtf_has_feature tab_color && ...
wtf_has_feature() {
  local feature="$1"
  case "$feature" in
    tab_title)     [[ "$WTF_TERMINAL" != "generic" || -n "$TERM" ]] ;;
    tab_color)     [[ "$WTF_TERMINAL" == "iterm2" ]] ;;
    badge)         [[ "$WTF_TERMINAL" == "iterm2" ]] ;;
    user_vars)     [[ "$WTF_TERMINAL" == "iterm2" ]] ;;
    progress)      [[ "$WTF_TERMINAL" == "iterm2" || "$WTF_TERMINAL" == "ghostty" ]] ;;
    notification)  [[ "$WTF_TERMINAL" == "iterm2" || "$WTF_TERMINAL" == "ghostty" ]] ;;
    *)             return 1 ;;
  esac
}

# ── Tab Title (OSC 2 — works in iTerm2, Ghostty, most terminals) ─────

wtf_set_tab_title() {
  local title="$1"
  [[ -z "$title" ]] && return
  printf '\033]2;%s\a' "$title"
}

wtf_clear_tab_title() {
  # Reset to shell default by setting empty title
  printf '\033]2;\a'
}

# ── Tab Color (iTerm2 only — OSC 6;1;bg) ────────────────────────────

# Set tab color by RGB (0-255 each)
wtf_set_tab_color() {
  local r="$1" g="$2" b="$3"
  wtf_has_feature tab_color || return 0
  printf '\033]6;1;bg;red;brightness;%d\a' "$r"
  printf '\033]6;1;bg;green;brightness;%d\a' "$g"
  printf '\033]6;1;bg;blue;brightness;%d\a' "$b"
}

wtf_clear_tab_color() {
  wtf_has_feature tab_color || return 0
  printf '\033]6;1;bg;*;default\a'
}

# Set tab color by session state. Maps recency to color.
#   fresh  (< 1h)   → green
#   recent (< 24h)  → blue
#   stale  (< 7d)   → yellow/amber
#   old    (>= 7d)  → dim red
wtf_set_tab_color_by_age() {
  local epoch="$1"
  wtf_has_feature tab_color || return 0
  [[ -z "$epoch" || "$epoch" == "0" ]] && return 0

  local now delta
  now=$(date +%s)
  delta=$(( now - epoch ))

  if (( delta < 900 )); then
    # Fresh  (< 15m)  — green
    wtf_set_tab_color 76 175 80
  elif (( delta < 1800 )); then
    # Recent (< 30m)  — blue
    wtf_set_tab_color 66 165 245
  elif (( delta < 3600 )); then
    # Stale  (< 1h)   — amber
    wtf_set_tab_color 255 183 77
  else
    # Old    (>= 1h)  — dim red
    wtf_set_tab_color 183 28 28
  fi
}

# ── Badge (iTerm2 only — OSC 1337;SetBadgeFormat) ────────────────────

wtf_set_badge() {
  local text="$1"
  wtf_has_feature badge || return 0
  printf '\033]1337;SetBadgeFormat=%s\a' "$(printf '%s' "$text" | base64)"
}

wtf_clear_badge() {
  wtf_has_feature badge || return 0
  printf '\033]1337;SetBadgeFormat=%s\a' "$(printf '' | base64)"
}

# ── User Variables (iTerm2 only — OSC 1337;SetUserVar) ───────────────
# These feed into iTerm2's status bar via Interpolated String components.
# Configure status bar to display: \(user.wtfProject), \(user.wtfBranch), etc.

wtf_set_user_var() {
  local name="$1" value="$2"
  wtf_has_feature user_vars || return 0
  printf '\033]1337;SetUserVar=%s=%s\a' "$name" "$(printf '%s' "$value" | base64)"
}

# Push all session data as user variables at once
wtf_set_user_vars() {
  local project="$1" branch="$2" provider="$3" time_ago="$4" summary="$5"
  wtf_has_feature user_vars || return 0

  wtf_set_user_var "wtfProject"  "$project"
  wtf_set_user_var "wtfBranch"   "$branch"
  wtf_set_user_var "wtfProvider" "$provider"
  wtf_set_user_var "wtfTimeAgo"  "$time_ago"
  wtf_set_user_var "wtfSummary"  "$summary"
}

wtf_clear_user_vars() {
  wtf_has_feature user_vars || return 0
  wtf_set_user_var "wtfProject"  ""
  wtf_set_user_var "wtfBranch"   ""
  wtf_set_user_var "wtfProvider" ""
  wtf_set_user_var "wtfTimeAgo"  ""
  wtf_set_user_var "wtfSummary"  ""
}

# ── Progress Bar (OSC 9;4 — iTerm2 + Ghostty) ───────────────────────

# Show indeterminate progress (spinner/animation)
wtf_progress_start() {
  wtf_has_feature progress || return 0
  printf '\033]9;4;3\a'
}

# Set specific progress percentage (0-100)
wtf_progress_set() {
  local percent="$1"
  wtf_has_feature progress || return 0
  printf '\033]9;4;1;%d\a' "$percent"
}

# Clear progress bar
wtf_progress_clear() {
  wtf_has_feature progress || return 0
  printf '\033]9;4;0\a'
}

# ── Notifications (OSC 9 — iTerm2 + Ghostty) ─────────────────────────

wtf_notify() {
  local message="$1"
  wtf_has_feature notification || return 0
  [[ -z "$message" ]] && return
  printf '\033]9;%s\a' "$message"
}

# ── Composite: Apply All Terminal Features ───────────────────────────
# Call this after session data is resolved. It sets everything at once.

wtf_terminal_update() {
  local project="$1"
  local branch="$2"
  local provider="$3"
  local time_ago="$4"
  local summary="$5"
  local epoch="$6"

  # Tab title: "? project · branch · provider"
  local title="? ${project}"
  [[ -n "$branch" ]] && title+=" · ${branch}"
  [[ -n "$provider" ]] && title+=" · ${provider}"
  wtf_set_tab_title "$title"

  # Tab color by session age (iTerm2)
  wtf_set_tab_color_by_age "$epoch"

  # Badge: summary or branch (iTerm2)
  if [[ -n "$summary" ]]; then
    wtf_set_badge "$summary"
  elif [[ -n "$branch" ]]; then
    wtf_set_badge "$branch"
  fi

  # User variables for status bar (iTerm2)
  wtf_set_user_vars "$project" "$branch" "$provider" "$time_ago" "$summary"
}

# Reset all terminal decorations to defaults
wtf_terminal_clear() {
  wtf_clear_tab_title
  wtf_clear_tab_color
  wtf_clear_badge
  wtf_clear_user_vars
  wtf_progress_clear
}

# ── Auto-detect on source ────────────────────────────────────────────
wtf_detect_terminal
