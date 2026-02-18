#!/usr/bin/env zsh
# wtf-llm.sh — Optional LLM summarization via a local Ollama instance.
#
# Opt-in: set WTF_LLM=1 (or any non-empty value) to enable.
# Configure:
#   WTF_LLM_HOST   — Ollama base URL  (default: http://localhost:11434)
#   WTF_LLM_MODEL  — model to use     (default: llama3.2)
#   WTF_LLM_TIMEOUT — curl timeout s  (default: 8)
#
# Used by wtf-codex.sh (always) and wtf.sh Claude path (no-index fallback only).

# Check WTF_LLM is set and Ollama is reachable. Returns 0 if ready.
# Result is cached in _WTF_LLM_READY for the lifetime of the shell invocation.
# Reads WTF_LLM_HOST at call time so runtime overrides work.
wtf_llm_available() {
  local host="${WTF_LLM_HOST:-http://localhost:11434}"

  # Already checked this invocation (cache is per-host)
  if [[ -n "$_WTF_LLM_READY_HOST" && "$_WTF_LLM_READY_HOST" == "$host" ]]; then
    return $_WTF_LLM_READY
  fi

  # Opt-in gate
  if [[ -z "$WTF_LLM" ]]; then
    _WTF_LLM_READY=1; _WTF_LLM_READY_HOST="$host"
    return 1
  fi

  # curl required
  if ! command -v curl &>/dev/null; then
    [[ -n "$WTF_DEBUG" ]] && print -u2 "  llm: curl not found"
    _WTF_LLM_READY=1; _WTF_LLM_READY_HOST="$host"
    return 1
  fi

  # Quick liveness ping — /api/version is the lightest Ollama endpoint
  if curl -sf --max-time 1 "${host}/api/version" &>/dev/null; then
    [[ -n "$WTF_DEBUG" ]] && print -u2 "  llm: ollama reachable at ${host}"
    _WTF_LLM_READY=0; _WTF_LLM_READY_HOST="$host"
    return 0
  else
    [[ -n "$WTF_DEBUG" ]] && print -u2 "  llm: ollama not reachable at ${host}"
    _WTF_LLM_READY=1; _WTF_LLM_READY_HOST="$host"
    return 1
  fi
}

# Summarize a session context into one short sentence.
# Usage: summary=$(wtf_llm_summarize "$context_text")
# Prints summary to stdout. Returns 0 on success, 1 on failure.
# Reads WTF_LLM_HOST / WTF_LLM_MODEL / WTF_LLM_TIMEOUT at call time.
wtf_llm_summarize() {
  local context="$1"
  [[ -z "$context" ]] && return 1

  local host="${WTF_LLM_HOST:-http://localhost:11434}"
  local model="${WTF_LLM_MODEL:-llama3.2:1b}"
  local timeout="${WTF_LLM_TIMEOUT:-15}"

  local prompt="Summarize in one short sentence (max 80 characters) what this developer was working on. Be specific and technical. Output only the summary sentence, no preamble or explanation.

Session:
${context:0:2000}"

  # Build JSON payload using jq so escaping is handled correctly
  local payload
  payload=$(command jq -cn \
    --arg model "$model" \
    --arg prompt "$prompt" \
    '{
      model: $model,
      prompt: $prompt,
      stream: false,
      options: { temperature: 0.2, num_predict: 80 }
    }') || return 1

  [[ -n "$WTF_DEBUG" ]] && print -u2 "  llm: calling ${host}/api/generate model=${model}"

  local response
  response=$(curl -sf --max-time "$timeout" \
    "${host}/api/generate" \
    -H 'Content-Type: application/json' \
    -d "$payload" 2>/dev/null) || return 1

  local summary
  summary=$(printf '%s' "$response" | command jq -r '.response // empty' 2>/dev/null)
  [[ -z "$summary" ]] && return 1

  # Trim leading/trailing whitespace
  summary="${summary#"${summary%%[! $'\t'$'\n']*}"}"
  summary="${summary%"${summary##*[! $'\t'$'\n']}"}"

  [[ -n "$WTF_DEBUG" ]] && print -u2 "  llm: summary='${summary}'"

  printf '%s' "$summary"
}
