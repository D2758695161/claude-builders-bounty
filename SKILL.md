# SKILL.md — Generate Changelog from Git History

## When to Use

Use when you need to document changes in a project, when asked to "generate a changelog",
or when preparing a release. This skill creates a structured `CHANGELOG.md` from git commits.

## What It Does

Parses git commit history since the last annotated tag and auto-categorizes changes into:

- **Added** — New features
- **Fixed** — Bug fixes
- **Changed** — Changes to existing functionality
- **Removed** — Removed features
- **Security** — Security-related changes

## Usage

### Method 1: Claude Code built-in (recommended)

Place this SKILL.md in your project root. Then ask Claude Code:
```
/generate-changelog
```

### Method 2: Direct shell command

```bash
bash changelog.sh [since-tag]
```

## How It Works

1. Finds the most recent annotated git tag
2. Gets all commits between that tag and HEAD
3. Parses each commit message for conventional prefixes:
   - `feat:`, `feature:` → Added
   - `fix:`, `bugfix:` → Fixed
   - `chore:`, `refactor:`, `perf:` → Changed
   - `docs:` → Changed (documentation only)
   - `BREAKING CHANGE:` → Added (breaking change note)
4. Falls back to keyword detection if no prefix found
5. Outputs a `CHANGELOG.md` in Keep a Changelog format

## Categories Detected

| Prefix | Category |
|--------|----------|
| `feat:`, `feature:` | Added |
| `fix:`, `bugfix:` | Fixed |
| `chore:`, `refactor:`, `perf:` | Changed |
| `docs:` | Changed |
| `test:` | Changed |
| `BREAKING CHANGE:` | Added (with BREAKING NOTICE) |
| `remove:`, `deprecate:` | Removed |

## Configuration

- `CHANGELOG_FILE` — Output file (default: `CHANGELOG.md`)
- `TAG_PATTERN` — Custom tag regex (default: `^v?\d+\.\d+\.\d+`)
- `MAX_COMMITS` — Limit commits processed (default: 500)

## Tips

- Use conventional commit messages (`feat:`, `fix:`, etc.) for best results
- Annotated tags (`git tag -a v1.0.0 -m "Release v1.0.0"`) work better than lightweight tags
- The script never deletes existing CHANGELOG content — it prepends new entries
