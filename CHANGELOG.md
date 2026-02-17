# Changelog

All notable changes to wtf.terminal are documented here.

## [0.3.0] - 2026-02-17

### Added
- **Terminal feature module** (`lib/wtf-terminal.sh`) with auto-detection for iTerm2, Ghostty, and generic terminals
- **Tab title** — automatically set to `? project · branch · provider` (iTerm2 + Ghostty)
- **Tab color** — color-coded by session age: green (<1h), blue (<24h), amber (<7d), red (>7d) (iTerm2)
- **Badge** — persistent text overlay showing session summary or branch (iTerm2)
- **User variables** — push session data to iTerm2 status bar (`wtfProject`, `wtfBranch`, `wtfProvider`, `wtfTimeAgo`, `wtfSummary`)
- **Progress bar** — indeterminate spinner during provider scan (iTerm2 + Ghostty)
- **Desktop notifications** via `wtfctx notify` (iTerm2 + Ghostty)
- **Subcommand CLI** — `wtfctx` now supports: `title`, `color`, `badge`, `notify`, `progress`, `clear`, `info`, `help`
- `WTF_VERSION` variable

### Fixed
- Duplicate `local newest` declaration in `wtf-extract.sh`
- `WTF_SESSION_ID` not set in index-less fallback path

## [0.2.0] - 2026-02-17

### Added
- **Codex CLI** session reader (`lib/wtf-codex.sh`)
- **OpenCode** session reader via SQLite (`lib/wtf-opencode.sh`)
- Best-of-N provider pattern — compares timestamps across all providers, shows the most recent
- `--debug` flag for troubleshooting
- `?` alias for `wtfctx`

### Fixed
- Raw data leak from aliased `head`/`tail` commands
- Stdout leak from Codex reader's `local` declaration inside loop
- `cwd=` prefix leak from variable capture
- Claude project directory encoding (`.` was not converted to `-`)
- Index-less fallback for projects without `sessions-index.json`

## [0.1.0] - 2026-02-17

### Added
- Initial release
- Claude Code session reader (`lib/wtf-extract.sh`)
- Project root resolution via git (`lib/wtf-resolve.sh`)
- ANSI-formatted output with relative timestamps (`lib/wtf-format.sh`)
- Installer and uninstaller scripts
- README
