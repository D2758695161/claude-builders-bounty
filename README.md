# Claude Code Hook: block-destructive

A `pre-tool-use` hook for [Claude Code](https://docs.anthropic.com/claude-code) that intercepts and blocks dangerous commands before they execute.

## What it blocks

| Pattern | Reason |
|---------|--------|
| `rm -rf /`, `rm -rf ~`, `rm -rf .` | Recursive force delete |
| `DROP TABLE` | Deletes a database table |
| `git push --force` | Rewrites remote history |
| `TRUNCATE TABLE` | Deletes all rows from a table |
| `DELETE FROM <table>;` (no WHERE) | Deletes all rows without filter |
| Fork bombs, `mkfs.*`, direct block device writes | System-level destruction |

## Installation

**2 commands:**

```bash
# 1. Save the hook script
mkdir -p ~/.claude/hooks
curl -fsSL https://raw.githubusercontent.com/D2758695161/claude-builders-bounty/main/pre-tool-use-block-destructive.py \
  -o ~/.claude/hooks/pre-tool-use-block-destructive.py
chmod +x ~/.claude/hooks/pre-tool-use-block-destructive.py

# 2. Register it in hooks.json
cat >> ~/.claude/hooks.json << 'EOF'
{
  "hooks": {
    "pre-tool-use": [
      {
        "name": "block-destructive",
        "path": "~/.claude/hooks/pre-tool-use-block-destructive.py"
      }
    ]
  }
}
EOF
# Note: merge the "hooks" key with your existing hooks.json content
```

Or manually:

```json
// ~/.claude/hooks.json
{
  "hooks": {
    "pre-tool-use": [
      {
        "name": "block-destructive",
        "path": "~/.claude/hooks/pre-tool-use-block-destructive.py"
      }
    ]
  }
}
```

## Blocked log

Every blocked attempt is logged to:

```
~/.claude/hooks/blocked.log
```

Format:
```
[2026-03-27T15:00:00] BLOCKED Bash in /home/user/project
  Command: rm -rf /
  Reason:  rm -rf (recursive force delete)
```

## Exit on merge

Once this PR is merged, the hook will be available at:

```
https://github.com/claude-builders-bounty/claude-builders-bounty/blob/main/pre-tool-use-block-destructive.py
```

## Requirements

- Python 3.6+
- Claude Code (any recent version with hooks support)

## Disclaimer

This hook intentionally blocks patterns that are **almost always destructive** in practice. Always review the blocked log if a legitimate command was stopped — you can temporarily remove the hook from `hooks.json` to proceed.
