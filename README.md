# wtf.terminal

Context recall for terminal sessions. Type `?` to remember what you were doing.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ? my-project  ·  feature/auth+3 unstaged  ·  4m ago  via claude
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Adding OAuth2 login flow to user service
 last asked: can you add the refresh token rotation logic...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Developers lose context constantly when switching between terminal tabs. wtf.terminal reads session files from your AI coding tools and gives you a quick summary — no API calls, no latency.

## Supported Tools

- **Claude Code** — reads from `~/.claude/projects/`
- **OpenAI Codex CLI** — reads from `~/.codex/sessions/`
- **OpenCode** — reads from `~/.local/share/opencode/opencode.db`

Automatically picks the most recent session across all installed tools.

## Install

```sh
curl -sSL https://raw.githubusercontent.com/dupe-com/wtf.terminal/main/install.sh | bash
```

Requires `jq` and `git`. If you don't have `jq`:

```sh
brew install jq
```

Then restart your terminal or `source ~/.zshrc`.

## Usage

```sh
?              # Show context for current directory
wtfctx         # Same thing, no alias needed
```

`cd` into any project directory where you've used an AI coding tool and type `?`.

## What it shows

- **Project name** — from your git root directory
- **Git branch** + unstaged file count (live from your repo)
- **Time since last session** — relative ("4m ago", "2h ago")
- **Session summary** — what you were working on
- **Last question** — the last thing you asked
- **Provider** — which tool the session came from

## How it works

1. Finds your git root directory
2. Checks Claude Code, Codex, and OpenCode for sessions matching that directory
3. Picks the most recently modified session across all providers
4. Extracts the summary and last human message
5. Renders a formatted output block with ANSI colors

Pure zsh + jq + sqlite3 (ships with macOS). No Node, no Python, no build step.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `WTF_INSTALL_DIR` | `~/.wtf-terminal` | Where the tool is installed |
| `NO_COLOR` | unset | Set to disable colored output |

## Uninstall

```sh
~/.wtf-terminal/uninstall.sh
```

## License

MIT
