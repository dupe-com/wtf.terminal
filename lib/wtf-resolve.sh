#!/usr/bin/env zsh
# wtf-resolve.sh — CWD → Claude project dir resolution

# Walk up from $PWD to /, encode each path, check for sessions-index.json.
# Returns the Claude project dir (deepest match) or exits 1.
wtf_resolve_project_dir() {
  local dir="${1:-$PWD}"
  local claude_base="$HOME/.claude/projects"

  while [[ "$dir" != "/" ]]; do
    # Encode: /Users/ramin/Work/foo → -Users-ramin-Work-foo
    local encoded="${dir//\//-}"
    local index_file="$claude_base/$encoded/sessions-index.json"

    if [[ -f "$index_file" ]]; then
      echo "$claude_base/$encoded"
      return 0
    fi

    dir="${dir:h}"  # zsh: parent directory
  done

  return 1
}
