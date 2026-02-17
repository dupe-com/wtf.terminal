#!/usr/bin/env zsh
# wtf.sh — Entry point for wtf.terminal
# Source this file in your .zshrc to get the `?` command.

WTF_DIR="${0:A:h}"

source "$WTF_DIR/lib/wtf-resolve.sh"
source "$WTF_DIR/lib/wtf-extract.sh"
source "$WTF_DIR/lib/wtf-format.sh"
source "$WTF_DIR/lib/wtf-cache.sh"

function \? {
  # 1. Resolve CWD to a Claude project dir
  local project_dir
  project_dir=$(wtf_resolve_project_dir) || {
    echo "? no sessions found for this directory"
    return 1
  }

  # Derive project name from the encoded dir name
  local encoded_name="${project_dir:t}"
  local project_name="${encoded_name##*-}"  # last path component

  # 2. Find latest session
  wtf_find_latest_session "$project_dir" || {
    echo "? no sessions in index"
    return 1
  }

  # Better project name from session metadata
  if [[ -n "$WTF_PROJECT_PATH" ]]; then
    project_name="${WTF_PROJECT_PATH:t}"
  fi

  # Cache key based on encoded project dir name
  local cache_key="$encoded_name"

  local summary last_human modified git_branch

  # 3. Check cache (stores raw data, not rendered output)
  if wtf_cache_read "$WTF_SESSION_PATH" "$cache_key"; then
    project_name="$WTF_CACHED_PROJECT_NAME"
    summary="$WTF_CACHED_SUMMARY"
    last_human="$WTF_CACHED_LAST_HUMAN"
    modified="$WTF_CACHED_MODIFIED"
    git_branch="$WTF_CACHED_GIT_BRANCH"
  else
    # 4. Extract messages from session
    wtf_extract_messages "$WTF_SESSION_PATH"

    summary="$WTF_SUMMARY"
    last_human="${WTF_LAST_HUMAN:-$WTF_FIRST_PROMPT}"
    modified="$WTF_MODIFIED"
    git_branch="$WTF_GIT_BRANCH"

    # Write raw data to cache
    wtf_cache_write "$WTF_SESSION_PATH" "$cache_key" \
      "$project_name" "$summary" "$last_human" "$modified" "$git_branch"
  fi

  # 5. Compute display values (always fresh — respects TTY/NO_COLOR)
  local time_ago
  time_ago=$(wtf_time_ago "$modified")

  local git_info
  git_info=$(wtf_git_info "$git_branch")

  # 6. Format and print
  wtf_format "$project_name" "$git_info" "$time_ago" "$summary" "$last_human"
}
