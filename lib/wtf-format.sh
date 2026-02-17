#!/usr/bin/env zsh
# wtf-format.sh — ANSI-colored output rendering

# Detect color support
wtf_use_color() {
  [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]
}

# Convert ISO timestamp or epoch to relative time string
wtf_time_ago() {
  local ts="$1"
  [[ -z "$ts" ]] && echo "unknown" && return

  local now epoch delta

  now=$(date +%s)

  # Handle ISO 8601 timestamps
  if [[ "$ts" == *T* ]]; then
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${ts%%.*}" +%s 2>/dev/null) || {
      echo "unknown"
      return
    }
  else
    epoch="$ts"
  fi

  delta=$(( now - epoch ))

  if (( delta < 60 )); then
    echo "just now"
  elif (( delta < 3600 )); then
    echo "$(( delta / 60 ))m ago"
  elif (( delta < 86400 )); then
    echo "$(( delta / 3600 ))h ago"
  elif (( delta < 604800 )); then
    echo "$(( delta / 86400 ))d ago"
  else
    echo "$(( delta / 604800 ))w ago"
  fi
}

# Get git info: branch + unstaged count (live from CWD)
wtf_git_info() {
  local branch="$1"

  # Use live git data if in a repo
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(git branch --show-current 2>/dev/null)
    local unstaged
    unstaged=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if (( unstaged > 0 )); then
      echo "${branch}+${unstaged} unstaged"
    else
      echo "${branch}"
    fi
  elif [[ -n "$branch" ]]; then
    echo "$branch"
  fi
}

# Render the formatted output block
wtf_format() {
  local project_name="$1"
  local git_info="$2"
  local time_ago="$3"
  local summary="$4"
  local last_human="$5"
  local provider="${6:-claude}"

  local sep
  local c_reset c_dim c_bold_cyan c_dim_label c_provider

  if wtf_use_color; then
    c_reset=$'\033[0m'
    c_dim=$'\033[2m'
    c_bold_cyan=$'\033[1;36m'
    c_dim_label=$'\033[2;3m'
    c_provider=$'\033[2m'
  fi

  sep="${c_dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${c_reset}"

  # Build header line
  local header=" ${c_bold_cyan}? ${project_name}${c_reset}"

  if [[ -n "$git_info" ]]; then
    header+="  ${c_dim}·${c_reset}  ${git_info}"
  fi

  if [[ -n "$time_ago" ]]; then
    header+="  ${c_dim}·${c_reset}  ${time_ago}"
  fi

  header+="  ${c_provider}via ${provider}${c_reset}"

  # Build body
  local body=""
  if [[ -n "$summary" ]]; then
    body+=" ${summary}"
  fi
  if [[ -n "$last_human" ]]; then
    body+=$'\n'" ${c_dim_label}last asked:${c_reset} ${last_human}"
  fi

  printf '%s\n%s\n%s\n%s\n%s\n' "$sep" "$header" "$sep" "$body" "$sep"
}
