#!/usr/bin/env zsh
# wtf-extract.sh — Session finding + message extraction

# Find the latest non-sidechain session from sessions-index.json.
# Sets global vars: WTF_SESSION_ID, WTF_SESSION_PATH, WTF_SUMMARY,
#   WTF_MODIFIED, WTF_GIT_BRANCH, WTF_FIRST_PROMPT, WTF_PROJECT_PATH
wtf_find_latest_session() {
  local project_dir="$1"
  local index_file="$project_dir/sessions-index.json"

  [[ -f "$index_file" ]] || return 1

  local result
  result=$(jq -r '
    .entries
    | map(select(.isSidechain != true))
    | sort_by(.modified) | reverse
    | .[0]
    | if . == null then "NONE" else
        [.sessionId, .fullPath, (.summary // ""), .modified, (.gitBranch // ""), (.firstPrompt // ""), (.projectPath // "")] | join("\t")
      end
  ' "$index_file" 2>/dev/null)

  [[ "$result" == "NONE" || -z "$result" ]] && return 1

  # Split tab-delimited result
  WTF_SESSION_ID="${result%%	*}"; result="${result#*	}"
  WTF_SESSION_PATH="${result%%	*}"; result="${result#*	}"
  WTF_SUMMARY="${result%%	*}"; result="${result#*	}"
  WTF_MODIFIED="${result%%	*}"; result="${result#*	}"
  WTF_GIT_BRANCH="${result%%	*}"; result="${result#*	}"
  WTF_FIRST_PROMPT="${result%%	*}"; result="${result#*	}"
  WTF_PROJECT_PATH="${result}"

  # Verify session file exists on disk
  [[ -f "$WTF_SESSION_PATH" ]] || return 1

  return 0
}

# Extract last human message and last assistant text from a session JSONL.
# Sets: WTF_LAST_HUMAN, WTF_LAST_ASSISTANT, WTF_LAST_TIMESTAMP
wtf_extract_messages() {
  local session_file="$1"
  local max_chars="${2:-120}"

  [[ -f "$session_file" ]] || return 1

  # Use jq to extract last human string message and last assistant text block
  local extracted
  extracted=$(command tail -200 "$session_file" | jq -rs '
    [.[] | select(.message != null)] |
    {
      last_human: (
        [.[] | select(.message.role == "user" and (.message.content | type) == "string" and (.message.content | startswith("<") | not))]
        | last
        | .message.content // ""
      ),
      last_assistant: (
        [.[] | select(.message.role == "assistant" and (.message.content | type) == "array")]
        | last
        | .message.content
        | [.[] | select(.type == "text")] | last
        | .text // ""
      ),
      last_ts: (
        last
        | .timestamp // ""
      )
    }
    | [.last_human, .last_assistant, .last_ts] | join("\t")
  ' 2>/dev/null)

  [[ -z "$extracted" ]] && return 1

  WTF_LAST_HUMAN="${extracted%%	*}"; extracted="${extracted#*	}"
  WTF_LAST_ASSISTANT="${extracted%%	*}"; extracted="${extracted#*	}"
  WTF_LAST_TIMESTAMP="${extracted}"

  # Truncate to max_chars
  if (( ${#WTF_LAST_HUMAN} > max_chars )); then
    WTF_LAST_HUMAN="${WTF_LAST_HUMAN:0:$max_chars}..."
  fi
  if (( ${#WTF_LAST_ASSISTANT} > max_chars )); then
    WTF_LAST_ASSISTANT="${WTF_LAST_ASSISTANT:0:$max_chars}..."
  fi

  return 0
}
