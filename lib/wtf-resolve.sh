#!/usr/bin/env zsh
# wtf-resolve.sh — CWD → project directory resolution

# Find the project root for the current directory.
# Uses git root if available, otherwise exact CWD.
# Sets WTF_PROJECT_ROOT.
wtf_resolve_project_root() {
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null)

  if [[ -n "$git_root" ]]; then
    WTF_PROJECT_ROOT="$git_root"
    return 0
  fi

  # Non-git fallback: use CWD
  WTF_PROJECT_ROOT="$PWD"
  return 0
}

# Check if Claude Code has sessions for a given directory.
# Returns the Claude project dir path or exits 1.
wtf_resolve_claude() {
  local target_dir="$1"
  local claude_base="$HOME/.claude/projects"
  # Claude Code encodes: / → -, . → -
  local encoded="${target_dir//\//-}"
  encoded="${encoded//./-}"
  local index_file="$claude_base/$encoded/sessions-index.json"

  if [[ -f "$index_file" ]]; then
    echo "$claude_base/$encoded"
    return 0
  fi

  # Fallback: project dir exists with .jsonl files but no index yet
  local project_dir="$claude_base/$encoded"
  if [[ -d "$project_dir" ]] && command ls "$project_dir"/*.jsonl &>/dev/null; then
    echo "$project_dir"
    return 0
  fi

  return 1
}
