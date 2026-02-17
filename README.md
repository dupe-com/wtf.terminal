# wtf.terminal

Context recall for terminal sessions. Type `?` to remember what you were doing.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ? my-project  ·  feature/auth+3 unstaged  ·  4m ago
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Adding OAuth2 login flow to user service
 last asked: can you add the refresh token rotation logic...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Developers lose context constantly when switching between terminal tabs. wtf.terminal reads your [Claude Code](https://docs.anthropic.com/en/docs/claude-code) session files from disk and gives you a quick summary — no API calls, no latency.

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
?          # Show context for current directory
```

That's it. `cd` into any project directory where you've used Claude Code, type `?`.

## What it shows

- **Project name** — derived from your working directory
- **Git branch** + unstaged file count (live from your repo)
- **Time since last session** — relative ("4m ago", "2h ago")
- **Session summary** — from Claude Code's session index
- **Last question** — the last thing you asked Claude

## How it works

1. Walks up from `$PWD` to find a matching Claude Code project in `~/.claude/projects/`
2. Reads the `sessions-index.json` to find the latest non-sidechain session
3. Tails the session JSONL file to extract the last human/assistant messages
4. Renders a formatted output block with ANSI colors (respects `NO_COLOR` and piped output)
5. Caches results by file mtime — repeat calls are instant

Pure zsh + jq. No Node, no Python, no build step. Runs in ~30ms.

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
