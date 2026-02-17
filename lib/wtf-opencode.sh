#!/usr/bin/env zsh
# wtf-opencode.sh — OpenCode session reader

# Find the latest OpenCode session for a given directory.
# Sets: WTF_PROVIDER, WTF_SESSION_PATH, WTF_SUMMARY, WTF_MODIFIED,
#   WTF_GIT_BRANCH, WTF_FIRST_PROMPT, WTF_PROJECT_PATH, WTF_LAST_HUMAN
wtf_opencode_find_session() {
  local target_dir="$1"
  local db="$HOME/.local/share/opencode/opencode.db"

  [[ -f "$db" ]] || return 1
  command -v sqlite3 &>/dev/null || return 1

  # Find latest session matching this directory
  local result
  result=$(sqlite3 "$db" "
    SELECT s.id, s.title, s.directory, s.time_updated
    FROM session s
    WHERE s.directory LIKE '${target_dir}%'
      AND s.time_archived IS NULL
    ORDER BY s.time_updated DESC
    LIMIT 1;
  " 2>/dev/null)

  [[ -z "$result" ]] && return 1

  local session_id title directory time_updated
  session_id="${result%%|*}"; result="${result#*|}"
  title="${result%%|*}"; result="${result#*|}"
  directory="${result%%|*}"; result="${result#*|}"
  time_updated="${result}"

  WTF_PROVIDER="opencode"
  WTF_SESSION_PATH="$db:$session_id"
  WTF_PROJECT_PATH="$directory"
  WTF_SUMMARY="$title"
  WTF_GIT_BRANCH=""

  # Convert epoch ms to ISO for time_ago
  local epoch_s=$(( time_updated / 1000 ))
  WTF_MODIFIED="$epoch_s"

  # Get last user text from parts table
  WTF_LAST_HUMAN=$(sqlite3 "$db" "
    SELECT json_extract(p.data, '$.text')
    FROM part p
    JOIN message m ON p.message_id = m.id
    WHERE m.session_id = '$session_id'
      AND json_extract(m.data, '$.role') = 'user'
      AND json_extract(p.data, '$.type') = 'text'
      AND json_extract(p.data, '$.synthetic') IS NULL
    ORDER BY p.rowid DESC
    LIMIT 1;
  " 2>/dev/null)

  # First prompt fallback
  if [[ -z "$WTF_LAST_HUMAN" ]]; then
    WTF_LAST_HUMAN=$(sqlite3 "$db" "
      SELECT json_extract(p.data, '$.text')
      FROM part p
      JOIN message m ON p.message_id = m.id
      WHERE m.session_id = '$session_id'
        AND json_extract(m.data, '$.role') = 'user'
        AND json_extract(p.data, '$.type') = 'text'
      ORDER BY p.rowid ASC
      LIMIT 1;
    " 2>/dev/null)
  fi
  WTF_FIRST_PROMPT="$WTF_LAST_HUMAN"

  # Truncate
  (( ${#WTF_LAST_HUMAN} > 120 )) && WTF_LAST_HUMAN="${WTF_LAST_HUMAN:0:120}..."

  return 0
}
