#!/usr/bin/env zsh
# wtf-codex.sh — OpenAI Codex CLI session reader

# Find the latest Codex session for a given directory.
# Sets: WTF_PROVIDER, WTF_SESSION_PATH, WTF_SUMMARY, WTF_MODIFIED,
#   WTF_GIT_BRANCH, WTF_FIRST_PROMPT, WTF_PROJECT_PATH, WTF_LAST_HUMAN
wtf_codex_find_session() {
  local target_dir="$1"
  local codex_sessions="$HOME/.codex/sessions"

  [[ -d "$codex_sessions" ]] || return 1

  local latest_file=""

  # Search recent session files (sorted by mtime, newest first)
  local session_file cwd
  for session_file in "$codex_sessions"/**/*.jsonl(N.om[1,50]); do
    cwd=$(command head -1 "$session_file" 2>/dev/null | command jq -r '.payload.cwd // empty' 2>/dev/null)
    [[ -z "$cwd" ]] && continue

    [[ -n "$WTF_DEBUG" ]] && print -u2 "  codex: $cwd"

    # Match if session cwd starts with target_dir
    if [[ "$cwd" == "$target_dir"* ]]; then
      latest_file="$session_file"
      break
    fi
  done

  [[ -z "$latest_file" ]] && return 1

  [[ -n "$WTF_DEBUG" ]] && print -u2 "  codex: matched $latest_file"

  # Extract metadata from first line
  local meta
  meta=$(command head -1 "$latest_file" 2>/dev/null)

  WTF_PROVIDER="codex"
  WTF_SESSION_PATH="$latest_file"
  WTF_PROJECT_PATH=$(print -r -- "$meta" | command jq -r '.payload.cwd // empty' 2>/dev/null)
  WTF_GIT_BRANCH=$(print -r -- "$meta" | command jq -r '.payload.git.branch // empty' 2>/dev/null)
  WTF_MODIFIED=$(print -r -- "$meta" | command jq -r '.payload.timestamp // empty' 2>/dev/null)

  # Extract last user message and last assistant message from tail
  local extracted
  extracted=$(command tail -100 "$latest_file" | command jq -rs '
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

  # LLM summarization: condense the raw last-reply into a proper one-liner.
  # Only runs when WTF_LLM is set and Ollama is reachable (wtf_llm_available
  # caches the connectivity result so it only hits the network once).
  if wtf_llm_available 2>/dev/null; then
    local _llm_ctx="User: ${WTF_LAST_HUMAN}
Assistant: ${WTF_SUMMARY}"
    local _llm_sum
    _llm_sum=$(wtf_llm_summarize "$_llm_ctx") && WTF_SUMMARY="$_llm_sum"
  fi

  # First prompt fallback
  if [[ -z "$WTF_LAST_HUMAN" ]]; then
    WTF_FIRST_PROMPT=$(command head -20 "$latest_file" | command jq -rs '
      [.[] | select(.payload.role? == "user" and .payload.type? == "message")
       | .payload.content[]? | select(.type == "input_text") | .text
       | select(startswith("<") | not)]
      | first // ""
    ' 2>/dev/null)
    WTF_LAST_HUMAN="$WTF_FIRST_PROMPT"
  fi

  # Truncate
  (( ${#WTF_LAST_HUMAN} > 120 )) && WTF_LAST_HUMAN="${WTF_LAST_HUMAN:0:120}..."
  (( ${#WTF_SUMMARY} > 120 )) && WTF_SUMMARY="${WTF_SUMMARY:0:120}..."

  # Use file mtime if no timestamp in metadata
  if [[ -z "$WTF_MODIFIED" ]]; then
    WTF_MODIFIED=$(command stat -f%m "$latest_file" 2>/dev/null)
  fi

  return 0
}
