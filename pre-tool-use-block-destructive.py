#!/usr/bin/env python3
"""
Claude Code pre-tool-use hook: block-destructive
Intercepts dangerous commands before they are executed.

Install:
  1. Save this script to ~/.claude/hooks/pre-tool-use-block-destructive.py
  2. Add to ~/.claude/hooks.json:
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

Usage: Claude Code automatically calls this before every tool use.
"""

import sys
import os
import re
import json
import datetime

HOOKS_DIR = os.path.dirname(os.path.abspath(__file__))
BLOCKED_LOG = os.path.join(HOOKS_DIR, "blocked.log")

# Patterns that indicate dangerous commands
DANGEROUS_PATTERNS = [
    (re.compile(r'rm\s+-rf\s+[/~\.]'), "rm -rf (recursive force delete)"),
    (re.compile(r'DROP\s+TABLE', re.IGNORECASE), "DROP TABLE (deletes database table)"),
    (re.compile(r'git\s+push\s+--force', re.IGNORECASE), "git push --force (rewrites history)"),
    (re.compile(r'TRUNCATE\s+TABLE', re.IGNORECASE), "TRUNCATE TABLE (deletes all rows)"),
    (re.compile(r'DELETE\s+FROM\s+\w+\s*;?\s*$', re.IGNORECASE), "DELETE FROM without WHERE (deletes all rows)"),
    (re.compile(r'DELETE\s+FROM\s+\w+\s+WHERE', re.IGNORECASE), None),  # Watch but don't block with WHERE
    (re.compile(r'shred\s+-u', re.IGNORECASE), "shred -u (secure file deletion)"),
    (re.compile(r':(){.*:\|.*&.*}', re.IGNORECASE), "Fork bomb detected"),
    (re.compile(r'>\s*/dev/sd[a-z]', re.IGNORECASE), "Writing directly to block device"),
    (re.compile(r'mkfs\.', re.IGNORECASE), "Filesystem format command"),
]

# Tools this hook applies to
RELEVANT_TOOLS = {"Bash", "Write", "Edit", "Notebook"}

def log_blocked(tool_name: str, command: str, reason: str, project_path: str):
    """Log every blocked attempt to blocked.log."""
    timestamp = datetime.datetime.now().isoformat()
    log_entry = (
        f"[{timestamp}] BLOCKED {tool_name} in {project_path}\n"
        f"  Command: {command}\n"
        f"  Reason:  {reason}\n"
        f"\n"
    )
    try:
        with open(BLOCKED_LOG, "a", encoding="utf-8") as f:
            f.write(log_entry)
    except OSError:
        pass  # Don't fail if we can't write the log


def check_command(command: str) -> tuple[bool, str | None]:
    """
    Check if a command matches any dangerous pattern.
    Returns (is_dangerous, reason).
    """
    if not command:
        return False, None

    for pattern, description in DANGEROUS_PATTERNS:
        if pattern.search(command):
            if description:  # None means watch-only
                return True, description
    return False, None


def main():
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            sys.exit(0)
        payload = json.loads(raw)
    except (json.JSONDecodeError, OSError):
        sys.exit(0)  # Ignore malformed input

    tool_name = payload.get("tool_name", "")
    tool_input = payload.get("tool_input", {})

    if tool_name not in RELEVANT_TOOLS:
        sys.exit(0)  # Only check relevant tools

    # Extract the command/content to check
    if tool_name == "Bash":
        command = tool_input.get("command", "")
    elif tool_name in ("Write", "Edit"):
        command = tool_input.get("content", "") + tool_input.get("oldstring", "") + tool_input.get("newstring", "")
    else:
        command = str(tool_input)

    is_dangerous, reason = check_command(command)
    if not is_dangerous:
        sys.exit(0)  # Allow

    # Get project path for logging
    project_path = os.environ.get("CLAUDE_PROJECT_PATH", os.getcwd())

    # Log the blocked attempt
    log_blocked(tool_name, command[:500], reason, project_path)

    # Output block response
    response = {
        "block": True,
        "reason": (
            f"❌ Command blocked by pre-tool-use hook (block-destructive):\n"
            f"   {reason}\n"
            f"   If this is a false positive, you can:\n"
            f"   1. Rewrite the command more safely, or\n"
            f"   2. Temporarily disable this hook by removing it from hooks.json"
        )
    }

    print(json.dumps(response, indent=2))
    sys.exit(1)  # Non-zero = block


if __name__ == "__main__":
    main()
