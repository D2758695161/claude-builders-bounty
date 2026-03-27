#!/usr/bin/env bash
# =============================================================================
# PR Reviewer Agent — Claude Code-powered PR review
# Usage: review-pr.sh --pr <url> [--output <file>]
# =============================================================================
set -euo pipefail

ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr) PR_URL="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ -z "$PR_URL" ]]; then
    echo "Usage: review-pr.sh --pr <pr_url>" >&2
    exit 1
fi

# Parse owner/repo/pr_number from URL
# Supports: https://github.com/owner/repo/pull/123
#           https://github.com/owner/repo/issues/123 (comment on issue)
if [[ "$PR_URL" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    PR_NUM="${BASH_REMATCH[3]}"
else
    echo "Error: Invalid PR URL format" >&2
    exit 1
fi

API_BASE="https://api.github.com/repos/$OWNER/$REPO"

# Fetch PR info + diff
echo "Fetching PR #$PR_NUM from $OWNER/$REPO..." >&2

PR_INFO=$(curl -s -H "Accept: application/vnd.github.v3+json" \
    ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    "$API_BASE/pulls/$PR_NUM")

PR_TITLE=$(echo "$PR_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('title',''))" 2>/dev/null || echo "")
PR_BODY=$(echo "$PR_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('body','')[:2000] or '')" 2>/dev/null || echo "")
PR_AUTHOR=$(echo "$PR_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('user',{}).get('login',''))" 2>/dev/null || echo "")
BASE_BRANCH=$(echo "$PR_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('base',{}).get('ref',''))" 2>/dev/null || echo "")
HEAD_BRANCH=$(echo "$PR_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('head',{}).get('ref',''))" 2>/dev/null || echo "")

# Get diff
DIFF_URL="$API_BASE/pulls/$PR_NUM"
DIFF=$(curl -s -H "Accept: application/vnd.github.v3.diff" \
    ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    "$DIFF_URL")

DIFF_SIZE=${#DIFF}
if [[ $DIFF_SIZE -gt 100000 ]]; then
    DIFF_SUMMARY=$(echo "$DIFF" | head -c 80000)
    DIFF_NOTE="(Diff truncated - showing first 80k chars of ${DIFF_SIZE} byte diff)"
else
    DIFF_SUMMARY="$DIFF"
    DIFF_NOTE=""
fi

# Build prompt for Claude
PROMPT="You are a senior software engineer reviewing a GitHub Pull Request. Provide a thorough but concise review.

## PR Details
- Title: $PR_TITLE
- Author: @$PR_AUTHOR
- Base branch: $BASE_BRANCH → Head branch: $HEAD_BRANCH
- URL: $PR_URL

## PR Description
${PR_BODY:-No description provided}

## Diff $DIFF_NOTE
\`\`\`diff
$DIFF_SUMMARY
\`\`\`

## Review Requirements

Return a structured Markdown review with these sections:

1. **Summary** — 2-3 sentence overview of what this PR does
2. **Risk Assessment** — Identify potential issues (security, bugs, breaking changes, performance). Rate each as HIGH/MEDIUM/LOW
3. **Suggestions** — Actionable improvement recommendations (max 5)
4. **Confidence Score** — LOW/MEDIUM/HIGH with brief explanation
5. **Files Changed Summary** — Count of files changed, lines added/removed

Be critical but constructive. Focus on real issues over style preferences."

# Call Claude API
if [[ -z "$ANTHROPIC_API_KEY" ]]; then
    echo "Error: ANTHROPIC_API_KEY not set" >&2
    exit 1
fi

RESPONSE=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$(jq -n --arg prompt "$PROMPT" '{
        model: "claude-sonnet-4-20250514",
        max_tokens: 2000,
        messages: [{ role: "user", content: $prompt }]
    }')" 2>/dev/null)

# Extract text from Claude response
REVIEW=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('content', [{}])[0].get('text', 'Error parsing response'))
except:
    print('Error calling Claude API')
" 2>/dev/null || echo "Error calling Claude API")

# Output
{
    echo "## PR Review: $PR_TITLE"
    echo ""
    echo "**Repository:** $OWNER/$REPO | **PR:** #$PR_NUM | **Author:** @$PR_AUTHOR"
    echo "**Base:** $BASE_BRANCH → **Head:** $HEAD_BRANCH"
    echo ""
    echo "---"
    echo ""
    echo "$REVIEW"
} | if [[ -n "$OUTPUT" ]]; then
    tee "$OUTPUT"
else
    cat
fi
