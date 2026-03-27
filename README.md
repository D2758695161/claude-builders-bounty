# SKILL: Generate Changelog from Git History

Generates a structured `CHANGELOG.md` from a project's git commit history.

## Quick Start (3 steps)

```bash
# 1. Save the script
curl -fsSL https://raw.githubusercontent.com/D2758695161/claude-builders-bounty/main/changelog.sh -o changelog.sh
chmod +x changelog.sh

# 2. Make sure your project has annotated tags
git tag -a v1.0.0 -m "Release v1.0.0"

# 3. Run
./changelog.sh
```

## Alternative: Use as Claude Code SKILL

1. Save `SKILL.md` and `changelog.sh` in your project root
2. Ask: `/generate-changelog`
3. Done — `CHANGELOG.md` is updated

## Features

- Auto-categorizes commits into Added / Fixed / Changed / Removed / Security
- Supports conventional commit prefixes: `feat:`, `fix:`, `chore:`, `refactor:`, etc.
- Detects `BREAKING CHANGE:` and marks them appropriately
- Falls back to keyword analysis for non-standard commit messages
- Prepends new entries to existing `CHANGELOG.md` (never overwrites history)
- Works on any language — detects English and Chinese keywords

## Requirements

- Git
- Bash 4+
- standard POSIX tools (`grep`, `awk`, `sed`)

## Sample Output

```markdown
## [v1.2.0] - 2026-03-27

### Added
- feat: add user authentication
- new endpoint for listing transactions

### Fixed
- fix: resolve memory leak in cache
- hotfix: prevent nil pointer in parser

### Changed
- refactor: migrate to new database driver
- docs: update API documentation
```

## Cl

oses claude-builders-bounty#1
