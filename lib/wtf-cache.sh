#!/usr/bin/env zsh
# wtf-cache.sh — mtime-based cache read/write
# Caches raw data (not rendered output) so color is always computed at display time.

WTF_CACHE_DIR="$HOME/.cache/wtf-terminal"

# Read cache. Returns 0 (hit) if cached mtime matches current file mtime.
# Sets WTF_CACHED_* variables on hit.
wtf_cache_read() {
  local session_file="$1"
  local cache_key="$2"
  local cache_file="$WTF_CACHE_DIR/${cache_key}.cache"

  [[ -f "$cache_file" ]] || return 1
  [[ -f "$session_file" ]] || return 1

  local cached_mtime current_mtime
  cached_mtime=$(head -1 "$cache_file")
  current_mtime=$(stat -f%m "$session_file" 2>/dev/null)

  [[ "$cached_mtime" == "$current_mtime" ]] || return 1

  # Cache hit — read tab-delimited data fields from line 2
  local data
  data=$(sed -n '2p' "$cache_file")

  WTF_CACHED_PROJECT_NAME="${data%%	*}"; data="${data#*	}"
  WTF_CACHED_SUMMARY="${data%%	*}"; data="${data#*	}"
  WTF_CACHED_LAST_HUMAN="${data%%	*}"; data="${data#*	}"
  WTF_CACHED_MODIFIED="${data%%	*}"; data="${data#*	}"
  WTF_CACHED_GIT_BRANCH="${data}"

  return 0
}

# Write raw data to cache with current mtime.
wtf_cache_write() {
  local session_file="$1"
  local cache_key="$2"
  local project_name="$3"
  local summary="$4"
  local last_human="$5"
  local modified="$6"
  local git_branch="$7"

  mkdir -p "$WTF_CACHE_DIR"

  local mtime
  mtime=$(stat -f%m "$session_file" 2>/dev/null) || return 1

  printf '%s\n%s\t%s\t%s\t%s\t%s\n' \
    "$mtime" "$project_name" "$summary" "$last_human" "$modified" "$git_branch" \
    > "$WTF_CACHE_DIR/${cache_key}.cache"
}
