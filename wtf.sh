#!/usr/bin/env zsh
# wtf.sh — Entry point for wtf.terminal
# Source this file in your .zshrc to get the `?` and `wtfctx` commands.

WTF_VERSION="0.3.0"
WTF_DIR="${0:A:h}"

source "$WTF_DIR/lib/wtf-resolve.sh"
source "$WTF_DIR/lib/wtf-extract.sh"
source "$WTF_DIR/lib/wtf-format.sh"
source "$WTF_DIR/lib/wtf-terminal.sh"
source "$WTF_DIR/lib/wtf-codex.sh"
source "$WTF_DIR/lib/wtf-opencode.sh"

# ── Helpers ──────────────────────────────────────────────────────────

# Convert any modified timestamp to epoch seconds for comparison.
_wtf_to_epoch() {
  local ts="$1"
  [[ -z "$ts" ]] && echo 0 && return

  if [[ "$ts" == *T* ]]; then
    date -j -f "%Y-%m-%dT%H:%M:%S" "${ts%%.*}" +%s 2>/dev/null || echo 0
  elif (( ts > 9999999999 )); then
    echo $(( ts / 1000 ))
  else
    echo "$ts"
  fi
}

# ── Core: find best session across providers ─────────────────────────
# Sets _wtf_best_* locals in the caller's scope.

_wtf_find_best_session() {
  _wtf_best_provider=""
  _wtf_best_epoch=0
  _wtf_best_modified=""
  _wtf_best_summary=""
  _wtf_best_last_human=""
  _wtf_best_git_branch=""
  _wtf_best_project_path=""
  _wtf_best_session_path=""
  _wtf_best_first_prompt=""

  wtf_resolve_project_root
  _wtf_project_root="$WTF_PROJECT_ROOT"
  _wtf_project_name="${_wtf_project_root:t}"

  [[ -n "$WTF_DEBUG" ]] && print -u2 "debug: project_root=$_wtf_project_root"

  # --- Claude Code ---
  [[ -n "$WTF_DEBUG" ]] && print -u2 "debug: checking claude..."
  local claude_dir
  claude_dir=$(wtf_resolve_claude "$_wtf_project_root")
  if [[ $? -eq 0 ]]; then
    wtf_find_latest_session "$claude_dir"
    if [[ $? -eq 0 ]]; then
      local epoch=$(_wtf_to_epoch "$WTF_MODIFIED")
      [[ -n "$WTF_DEBUG" ]] && print -u2 "  claude: epoch=$epoch modified=$WTF_MODIFIED"
      if (( epoch > _wtf_best_epoch )); then
        _wtf_best_epoch=$epoch
        _wtf_best_provider="claude"
        _wtf_best_modified="$WTF_MODIFIED"
        _wtf_best_summary="$WTF_SUMMARY"
        _wtf_best_git_branch="$WTF_GIT_BRANCH"
        _wtf_best_project_path="$WTF_PROJECT_PATH"
        _wtf_best_session_path="$WTF_SESSION_PATH"
        _wtf_best_first_prompt="$WTF_FIRST_PROMPT"
        _wtf_best_last_human=""
      fi
    fi
  fi

  # --- Codex ---
  [[ -n "$WTF_DEBUG" ]] && print -u2 "debug: checking codex..."
  wtf_codex_find_session "$_wtf_project_root"
  if [[ $? -eq 0 ]]; then
    local epoch=$(_wtf_to_epoch "$WTF_MODIFIED")
    [[ -n "$WTF_DEBUG" ]] && print -u2 "  codex: epoch=$epoch modified=$WTF_MODIFIED"
    if (( epoch > _wtf_best_epoch )); then
      _wtf_best_epoch=$epoch
      _wtf_best_provider="codex"
      _wtf_best_modified="$WTF_MODIFIED"
      _wtf_best_summary="$WTF_SUMMARY"
      _wtf_best_git_branch="$WTF_GIT_BRANCH"
      _wtf_best_project_path="$WTF_PROJECT_PATH"
      _wtf_best_session_path="$WTF_SESSION_PATH"
      _wtf_best_first_prompt="$WTF_FIRST_PROMPT"
      _wtf_best_last_human="$WTF_LAST_HUMAN"
    fi
  fi

  # --- OpenCode ---
  [[ -n "$WTF_DEBUG" ]] && print -u2 "debug: checking opencode..."
  wtf_opencode_find_session "$_wtf_project_root"
  if [[ $? -eq 0 ]]; then
    local epoch=$(_wtf_to_epoch "$WTF_MODIFIED")
    [[ -n "$WTF_DEBUG" ]] && print -u2 "  opencode: epoch=$epoch modified=$WTF_MODIFIED"
    if (( epoch > _wtf_best_epoch )); then
      _wtf_best_epoch=$epoch
      _wtf_best_provider="opencode"
      _wtf_best_modified="$WTF_MODIFIED"
      _wtf_best_summary="$WTF_SUMMARY"
      _wtf_best_git_branch="$WTF_GIT_BRANCH"
      _wtf_best_project_path="$WTF_PROJECT_PATH"
      _wtf_best_session_path="$WTF_SESSION_PATH"
      _wtf_best_first_prompt="$WTF_FIRST_PROMPT"
      _wtf_best_last_human="$WTF_LAST_HUMAN"
    fi
  fi

  [[ -z "$_wtf_best_provider" ]] && return 1

  # For Claude, extract messages (Codex/OpenCode already extracted)
  if [[ "$_wtf_best_provider" == "claude" ]]; then
    wtf_extract_messages "$_wtf_best_session_path"
    _wtf_best_last_human="${WTF_LAST_HUMAN:-$_wtf_best_first_prompt}"
  fi

  return 0
}

# ── Subcommands ──────────────────────────────────────────────────────

_wtf_cmd_show() {
  wtf_progress_start
  _wtf_find_best_session
  local rc=$?
  wtf_progress_clear

  if [[ $rc -ne 0 ]]; then
    echo "? no sessions found for this directory"
    return 1
  fi

  local time_ago git_info
  time_ago=$(wtf_time_ago "$_wtf_best_modified")
  git_info=$(wtf_git_info "$_wtf_best_git_branch")

  wtf_terminal_update "$_wtf_project_name" "$_wtf_best_git_branch" \
    "$_wtf_best_provider" "$time_ago" "$_wtf_best_summary" "$_wtf_best_epoch"

  wtf_format "$_wtf_project_name" "$git_info" "$time_ago" \
    "$_wtf_best_summary" "$_wtf_best_last_human" "$_wtf_best_provider"
}

_wtf_cmd_title() {
  local title="$1"
  if [[ -n "$title" ]]; then
    wtf_set_tab_title "$title"
    return
  fi
  # No arg: set from session data
  _wtf_find_best_session || { echo "? no session — cannot set title"; return 1; }
  local t="? ${_wtf_project_name}"
  [[ -n "$_wtf_best_git_branch" ]] && t+=" · ${_wtf_best_git_branch}"
  [[ -n "$_wtf_best_provider" ]] && t+=" · ${_wtf_best_provider}"
  wtf_set_tab_title "$t"
  echo "tab title set: $t"
}

_wtf_cmd_color() {
  if ! wtf_has_feature tab_color; then
    echo "? tab color not supported (requires iTerm2)"
    return 1
  fi

  case "$1" in
    ""|auto)
      _wtf_find_best_session || { echo "? no session"; return 1; }
      wtf_set_tab_color_by_age "$_wtf_best_epoch"
      local time_ago=$(wtf_time_ago "$_wtf_best_modified")
      echo "tab color set by age ($time_ago)"
      ;;
    clear|reset)
      wtf_clear_tab_color
      echo "tab color cleared"
      ;;
    green)   wtf_set_tab_color 76 175 80  ; echo "tab color: green"  ;;
    blue)    wtf_set_tab_color 66 165 245  ; echo "tab color: blue"   ;;
    amber)   wtf_set_tab_color 255 183 77  ; echo "tab color: amber"  ;;
    red)     wtf_set_tab_color 183 28 28   ; echo "tab color: red"    ;;
    purple)  wtf_set_tab_color 156 39 176  ; echo "tab color: purple" ;;
    cyan)    wtf_set_tab_color 0 188 212   ; echo "tab color: cyan"   ;;
    *)
      # Try R G B
      if [[ "$#" -ge 3 && "$1" =~ ^[0-9]+$ ]]; then
        wtf_set_tab_color "$1" "$2" "$3"
        echo "tab color: rgb($1, $2, $3)"
      else
        echo "usage: wtfctx color [auto|clear|green|blue|amber|red|purple|cyan|R G B]"
        return 1
      fi
      ;;
  esac
}

_wtf_cmd_badge() {
  if ! wtf_has_feature badge; then
    echo "? badge not supported (requires iTerm2)"
    return 1
  fi

  case "$1" in
    clear|reset|"")
      if [[ -z "$1" ]]; then
        # No arg: set from session data
        _wtf_find_best_session || { echo "? no session"; return 1; }
        local text="${_wtf_best_summary:-${_wtf_best_git_branch:-$_wtf_project_name}}"
        wtf_set_badge "$text"
        echo "badge set: $text"
      else
        wtf_clear_badge
        echo "badge cleared"
      fi
      ;;
    *)
      wtf_set_badge "$*"
      echo "badge set: $*"
      ;;
  esac
}

_wtf_cmd_notify() {
  if ! wtf_has_feature notification; then
    echo "? notifications not supported (requires iTerm2 or Ghostty)"
    return 1
  fi

  local msg="$*"
  if [[ -z "$msg" ]]; then
    _wtf_find_best_session || { echo "? no session"; return 1; }
    msg="? ${_wtf_project_name}: ${_wtf_best_summary:-last active $(wtf_time_ago "$_wtf_best_modified")}"
  fi
  wtf_notify "$msg"
  echo "notification sent"
}

_wtf_cmd_progress() {
  if ! wtf_has_feature progress; then
    echo "? progress bar not supported (requires iTerm2 or Ghostty)"
    return 1
  fi

  case "$1" in
    start)  wtf_progress_start ; echo "progress: indeterminate" ;;
    stop|clear|done) wtf_progress_clear ; echo "progress: cleared" ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 0 && $1 <= 100 )); then
        wtf_progress_set "$1"
        echo "progress: ${1}%"
      else
        echo "usage: wtfctx progress [start|stop|0-100]"
        return 1
      fi
      ;;
  esac
}

_wtf_cmd_clear() {
  wtf_terminal_clear
  echo "terminal decorations cleared"
}

_wtf_cmd_info() {
  echo "terminal:  $WTF_TERMINAL"
  echo "features:"
  local feat
  for feat in tab_title tab_color badge user_vars progress notification; do
    if wtf_has_feature "$feat"; then
      echo "  $feat: yes"
    else
      echo "  $feat: no"
    fi
  done

  if _wtf_find_best_session 2>/dev/null; then
    echo ""
    echo "session:"
    echo "  project:  $_wtf_project_name"
    echo "  provider: $_wtf_best_provider"
    echo "  branch:   ${_wtf_best_git_branch:-(none)}"
    echo "  modified: $(wtf_time_ago "$_wtf_best_modified")"
    echo "  summary:  ${_wtf_best_summary:-(none)}"
  fi
}

_wtf_cmd_help() {
  cat <<'EOF'
wtfctx — terminal context for AI coding sessions

usage: wtfctx [command] [args]
       ?                          shorthand for `wtfctx`

commands:
  (none)          show session context (default)
  title [TEXT]    set tab title (auto from session if no arg)
  color [COLOR]   set tab color (iTerm2 only)
                    auto       color by session age (default)
                    clear      reset to default
                    green blue amber red purple cyan
                    R G B      custom RGB (0-255)
  badge [TEXT]    set badge overlay (iTerm2 only, auto if no arg)
                    clear      remove badge
  notify [MSG]    send desktop notification (auto if no msg)
  progress N      set progress bar (0-100, start, stop)
  clear           reset all terminal decorations
  info            show detected terminal + available features
  help            show this help

environment:
  WTF_TERMINAL    detected terminal (iterm2, ghostty, generic)
  NO_COLOR        set to disable colored output
  WTF_DEBUG       set for debug output (or pass --debug)
EOF
}

# ── Main dispatcher ──────────────────────────────────────────────────

wtfctx() {
  local WTF_DEBUG=""
  # Peel off --debug from anywhere in args
  local -a args=()
  local a
  for a in "$@"; do
    if [[ "$a" == "--debug" ]]; then
      WTF_DEBUG=1
    else
      args+=("$a")
    fi
  done

  local cmd="${args[1]:-}"
  # Remove first element to get subcommand args (zsh arrays are 1-indexed)
  local -a sub_args=("${args[@]:1}")

  case "$cmd" in
    "")          _wtf_cmd_show                    ;;
    title)       _wtf_cmd_title "${sub_args[@]}"  ;;
    color)       _wtf_cmd_color "${sub_args[@]}"  ;;
    badge)       _wtf_cmd_badge "${sub_args[@]}"  ;;
    notify)      _wtf_cmd_notify "${sub_args[@]}" ;;
    progress)    _wtf_cmd_progress "${sub_args[@]}" ;;
    clear)       _wtf_cmd_clear                   ;;
    info)        _wtf_cmd_info                    ;;
    help|--help|-h)  _wtf_cmd_help               ;;
    *)
      echo "? unknown command: $cmd"
      echo "  run 'wtfctx help' for usage"
      return 1
      ;;
  esac
}

# Make ? work as a command despite being a zsh glob character.
disable -p '?'
alias '?'='wtfctx'
