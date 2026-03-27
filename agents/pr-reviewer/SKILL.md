# PR Reviewer Agent

An autonomous agent that reviews GitHub PRs using Claude and returns structured Markdown review comments.

## Usage

```bash
# Via CLI
claude-review --pr https://github.com/owner/repo/pull/123

# Or with GitHub Action
- uses: ./pr-reviewer-agent
  with:
    pr_url: ${{ github.event.pull_request.html_url }}
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

## What it does

1. Fetches the PR diff via GitHub API
2. Extracts: changed files, line counts, PR description
3. Sends diff + context to Claude API (claude-sonnet-4-20250514)
4. Returns structured Markdown review

## Output format

```markdown
## PR Review: [PR Title]

**Repository:** owner/repo | **PR:** #123 | **Author:** @username

---

### Summary
[2-3 sentence summary of what changed]

---

### Risks
- **[HIGH/MEDIUM/LOW]** Description of potential risk
- ...

---

### Suggestions
1. ...
2. ...

---

### Confidence Score
**Medium** — [reason]

---

### Files Changed
| File | Changes |
|------|---------|
| src/app.ts | +15 -3 |
| tests/app.test.ts | +42 -0 |
```

## Requirements

- `GITHUB_TOKEN` env var (for private repos) or public repo
- `ANTHROPIC_API_KEY` env var
- Node.js 18+ (for CLI) or just Bash (for GitHub Action)

## Implementation

- `review-pr.sh` — Bash CLI script (calls GitHub API + Claude API)
- `.github/workflows/pr-reviewer.yml` — GitHub Action
- `CLAUDE.md` — Agent instructions for Claude
