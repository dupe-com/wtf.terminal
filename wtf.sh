#!/usr/bin/env zsh
# wtf.sh — Entry point for wtf.terminal
# Source this file in your .zshrc to get the `?` and `wtfctx` commands.

WTF_DIR="${0:A:h}"

source "$WTF_DIR/lib/wtf-resolve.sh"
source "$WTF_DIR/lib/wtf-extract.sh"
source "$WTF_DIR/lib/wtf-format.sh"
source "$WTF_DIR/lib/wtf-codex.sh"
source "$WTF_DIR/lib/wtf-opencode.sh"

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

wtfctx() {
  # --debug flag: set WTF_DEBUG for this invocation
  local WTF_DEBUG=""
  if [[ "$1" == "--debug" ]]; then
    WTF_DEBUG=1
  fi

  # 1. Find project root (git root or CWD)
  wtf_resolve_project_root
  local project_root="$WTF_PROJECT_ROOT"
  local project_name="${project_root:t}"

  [[ -n "$WTF_DEBUG" ]] && print -u2 "debug: project_root=$project_root"

  # 2. Try all providers, track the most recent session
  local best_provider=""
  local best_epoch=0
  local best_modified="" best_summary="" best_last_human=""
  local best_git_branch="" best_project_path="" best_session_path=""
  local best_first_prompt=""

  # --- Claude Code ---
  [[ -n "$WTF_DEBUG" ]] && print -u2 "debug: checking claude..."
  local claude_dir
  claude_dir=$(wtf_resolve_claude "$project_root")
  if [[ $? -eq 0 ]]; then
    wtf_find_latest_session "$claude_dir"
    if [[ $? -eq 0 ]]; then
      local epoch=$(_wtf_to_epoch "$WTF_MODIFIED")
      [[ -n "$WTF_DEBUG" ]] && print -u2 "  claude: found session epoch=$epoch modified=$WTF_MODIFIED summary=$WTF_SUMMARY"
      if (( epoch > best_epoch )); then
        best_epoch=$epoch
        best_provider="claude"
        best_modified="$WTF_MODIFIED"
        best_summary="$WTF_SUMMARY"
        best_git_branch="$WTF_GIT_BRANCH"
        best_project_path="$WTF_PROJECT_PATH"
        best_session_path="$WTF_SESSION_PATH"
        best_first_prompt="$WTF_FIRST_PROMPT"
        best_last_human=""
      fi
    else
      [[ -n "$WTF_DEBUG" ]] && print -u2 "  claude: no sessions"
    fi
  else
    [[ -n "$WTF_DEBUG" ]] && print -u2 "  claude: no project dir"
  fi

  # --- Codex ---
  [[ -n "$WTF_DEBUG" ]] && print -u2 "debug: checking codex..."
  wtf_codex_find_session "$project_root"
  if [[ $? -eq 0 ]]; then
    local epoch=$(_wtf_to_epoch "$WTF_MODIFIED")
    [[ -n "$WTF_DEBUG" ]] && print -u2 "  codex: found session epoch=$epoch modified=$WTF_MODIFIED"
    if (( epoch > best_epoch )); then
      best_epoch=$epoch
      best_provider="codex"
      best_modified="$WTF_MODIFIED"
      best_summary="$WTF_SUMMARY"
      best_git_branch="$WTF_GIT_BRANCH"
      best_project_path="$WTF_PROJECT_PATH"
      best_session_path="$WTF_SESSION_PATH"
      best_first_prompt="$WTF_FIRST_PROMPT"
      best_last_human="$WTF_LAST_HUMAN"
    fi
  else
    [[ -n "$WTF_DEBUG" ]] && print -u2 "  codex: no sessions"
  fi

  # --- OpenCode ---
  [[ -n "$WTF_DEBUG" ]] && print -u2 "debug: checking opencode..."
  wtf_opencode_find_session "$project_root"
  if [[ $? -eq 0 ]]; then
    local epoch=$(_wtf_to_epoch "$WTF_MODIFIED")
    [[ -n "$WTF_DEBUG" ]] && print -u2 "  opencode: found session epoch=$epoch modified=$WTF_MODIFIED summary=$WTF_SUMMARY"
    if (( epoch > best_epoch )); then
      best_epoch=$epoch
      best_provider="opencode"
      best_modified="$WTF_MODIFIED"
      best_summary="$WTF_SUMMARY"
      best_git_branch="$WTF_GIT_BRANCH"
      best_project_path="$WTF_PROJECT_PATH"
      best_session_path="$WTF_SESSION_PATH"
      best_first_prompt="$WTF_FIRST_PROMPT"
      best_last_human="$WTF_LAST_HUMAN"
    fi
  else
    [[ -n "$WTF_DEBUG" ]] && print -u2 "  opencode: no sessions"
  fi

  # 3. No sessions found anywhere
  if [[ -z "$best_provider" ]]; then
    echo "? no sessions found for this directory"
    return 1
  fi

  [[ -n "$WTF_DEBUG" ]] && print -u2 "debug: winner=$best_provider epoch=$best_epoch"

  # 4. For Claude, extract messages (Codex/OpenCode already extracted)
  if [[ "$best_provider" == "claude" ]]; then
    wtf_extract_messages "$best_session_path"
    best_last_human="${WTF_LAST_HUMAN:-$best_first_prompt}"
  fi

  # 5. Compute display values
  local time_ago
  time_ago=$(wtf_time_ago "$best_modified")

  local git_info
  git_info=$(wtf_git_info "$best_git_branch")

  # 6. Format and print
  wtf_format "$project_name" "$git_info" "$time_ago" "$best_summary" "$best_last_human" "$best_provider"
}

# Make ? work as a command despite being a zsh glob character.
disable -p '?'
alias '?'='wtfctx'
