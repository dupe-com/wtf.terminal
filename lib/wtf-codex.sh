#!/usr/bin/env zsh
# wtf-codex.sh — OpenAI Codex CLI session reader

# Find the latest Codex session for a given directory.
# Sets: WTF_PROVIDER, WTF_SESSION_PATH, WTF_SUMMARY, WTF_MODIFIED,
#   WTF_GIT_BRANCH, WTF_FIRST_PROMPT, WTF_PROJECT_PATH, WTF_LAST_HUMAN
wtf_codex_find_session() {
  local target_dir="$1"
  local codex_sessions="$HOME/.codex/sessions"

  [[ -d "$codex_sessions" ]] || return 1

  # Find the most recent session file whose cwd matches target_dir
  local latest_file=""
  local latest_ts=0

  # Search recent session dirs (last 30 days worth)
  local session_file
  for session_file in "$codex_sessions"/**/*.jsonl(N.om[1,50]); do
    # Read session_meta (first line) to check cwd
    local meta
    meta=$(head -1 "$session_file" 2>/dev/null)
    [[ -z "$meta" ]] && continue

    local cwd
    cwd=$(echo "$meta" | jq -r '.payload.cwd // empty' 2>/dev/null)
    [[ -z "$cwd" ]] && continue

    # Match if session cwd starts with target_dir
    if [[ "$cwd" == "$target_dir"* ]]; then
      latest_file="$session_file"
      break  # Already sorted by mtime, first match is newest
    fi
  done

  [[ -z "$latest_file" ]] && return 1

  # Extract metadata from session_meta line
  local meta
  meta=$(head -1 "$latest_file")

  WTF_PROVIDER="codex"
  WTF_SESSION_PATH="$latest_file"
  WTF_PROJECT_PATH=$(echo "$meta" | jq -r '.payload.cwd // empty' 2>/dev/null)
  WTF_GIT_BRANCH=$(echo "$meta" | jq -r '.payload.git.branch // empty' 2>/dev/null)
  WTF_MODIFIED=$(echo "$meta" | jq -r '.payload.timestamp // empty' 2>/dev/null)

  # Extract first user prompt (skip system/instructions messages)
  WTF_FIRST_PROMPT=$(jq -rs '
    [.[] | select(.payload.role? == "user" and .payload.type? == "message")]
    | first
    | .payload.content[]
    | select(.type == "input_text")
    | .text // empty
  ' "$latest_file" 2>/dev/null | head -1)

  # Extract last user message and summary from tail
  local extracted
  extracted=$(tail -100 "$latest_file" | jq -rs '
    {
      last_human: (
        [.[] | select(.payload.role? == "user" and .payload.type? == "message")
         | .payload.content[]? | select(.type == "input_text") | .text
         | select(startswith("<") | not)]
        | last // ""
      ),
      last_assistant: (
        [.[] | select(.payload.role? == "assistant" and .payload.type? == "message")
         | .payload.content[]? | select(.type == "output_text") | .text]
        | last // ""
      )
    }
    | [.last_human, .last_assistant] | join("\t")
  ' 2>/dev/null)

  WTF_LAST_HUMAN="${extracted%%	*}"
  WTF_SUMMARY="${extracted#*	}"

  # Truncate
  (( ${#WTF_LAST_HUMAN} > 120 )) && WTF_LAST_HUMAN="${WTF_LAST_HUMAN:0:120}..."
  (( ${#WTF_SUMMARY} > 120 )) && WTF_SUMMARY="${WTF_SUMMARY:0:120}..."

  # Use file mtime if no timestamp in metadata
  if [[ -z "$WTF_MODIFIED" ]]; then
    WTF_MODIFIED=$(stat -f%m "$latest_file" 2>/dev/null)
  fi

  return 0
}
