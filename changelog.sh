#!/usr/bin/env bash
# changelog.sh — Generate a structured CHANGELOG.md from git history
# Usage: bash changelog.sh [since-tag]
# If no tag provided, uses the most recent annotated tag

set -euo pipefail

CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"
TAG_PATTERN="${TAG_PATTERN:-^v?[0-9]+\.[0-9]+\.[0-9]+}"
SINCE="${1:-}"

# Find the most recent annotated tag if not provided
if [[ -z "$SINCE" ]]; then
  # Get the most recent tag that matches the pattern
  SINCE=$(git tag --list "$TAG_PATTERN" --sort=-v:refname 2>/dev/null | head -n 1)
  if [[ -z "$SINCE" ]]; then
    # Fall back to first commit if no tags exist
    SINCE=$(git rev-list --max-parents=0 HEAD 2>/dev/null | head -n 1)
    echo "No tags found. Processing all commits from the beginning." >&2
  else
    echo "Generating changelog since tag: $SINCE" >&2
  fi
fi

# Collect commits
if ! git log "$SINCE..HEAD" --no-merges --format="%s%n%b|||" 2>/dev/null | grep -v "^$" > /tmp/cl_commits.txt; then
  echo "No commits found between $SINCE and HEAD." >&2
  exit 0
fi

# Initialize categorized buckets
declare -A CATEGORIES=(
  ["Added"]=""
  ["Fixed"]=""
  ["Changed"]=""
  ["Removed"]=""
  ["Security"]=""
)

# Process each commit
while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip merge commits and empty lines
  [[ -z "$line" || "$line" =~ ^Merge ]] && continue

  # Categorize by prefix
  LOWER=$(echo "$line" | tr '[:upper:]' '[:lower:]')

  if   [[ "$LOWER" =~ ^(feat|feature|新增|新功能)[:\ ] ]]; then
    CATEGORIES["Added"]+="- $line\n"
  elif [[ "$LOWER" =~ ^(fix|bugfix|修复|bug|hotfix)[:\ ] ]]; then
    CATEGORIES["Fixed"]+="- $line\n"
  elif [[ "$LOWER" =~ ^(chore|refactor|perf|重构|优化)[:\ ] ]]; then
    CATEGORIES["Changed"]+="- $line\n"
  elif [[ "$LOWER" =~ ^(docs|文档)[:\ ] ]]; then
    CATEGORIES["Changed"]+="- $line\n"
  elif [[ "$LOWER" =~ ^(test|测试)[:\ ] ]]; then
    CATEGORIES["Changed"]+="- $line\n"
  elif [[ "$LOWER" =~ ^(remove|removed|删除|remove)[:\ ] ]]; then
    CATEGORIES["Removed"]+="- $line\n"
  elif [[ "$LOWER" =~ ^(deprecat|deprecated|弃用)[:\ ] ]]; then
    CATEGORIES["Removed"]+="- $line\n"
  elif [[ "$LOWER" =~ security|安全 ]]; then
    CATEGORIES["Security"]+="- $line\n"
  elif [[ "$LOWER" =~ breaking ]]; then
    CATEGORIES["Added"]+="- $line ⚠️ BREAKING\n"
  else
    # Fallback: use first word as category hint
    FIRST_WORD=$(echo "$line" | awk '{print $1}' | tr -d ':')
    CATEGORIES["Changed"]+="- $line\n"
  fi
done < /tmp/cl_commits.txt

# Build the changelog
TODAY=$(date +"%Y-%m-%d")
NEXT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "Unreleased")

NEW_CONTENT="## [$NEXT_TAG] - $TODAY\n\n"

for cat in "Added" "Fixed" "Changed" "Removed" "Security"; do
  if [[ -n "${CATEGORIES[$cat]}" ]]; then
    NEW_CONTENT+="### $cat\n"
    NEW_CONTENT+="${CATEGORIES[$cat]}"
    NEW_CONTENT+="\n"
  fi
done

NEW_CONTENT="${NEW_CONTENT%$'\n'}"

# Prepend to existing CHANGELOG.md or create new
if [[ -f "$CHANGELOG_FILE" ]]; then
  # Find the last H2 line and insert after it
  if grep -q "^## \[" "$CHANGELOG_FILE"; then
    # Insert after the first H2 section
    TMP=$(mktemp)
    awk "/^## \[/ && !inserted { print; getline; print; inserted=1; next } { print }" "$CHANGELOG_FILE" > "$TMP" || true
    echo -e "$NEW_CONTENT\n$(cat "$TMP")" > "$CHANGELOG_FILE"
    rm -f "$TMP"
  else
    echo -e "$NEW_CONTENT\n\n$(cat "$CHANGELOG_FILE")" > "$CHANGELOG_FILE"
  fi
else
  echo -e "# Changelog\n\n$NEW_CONTENT" > "$CHANGELOG_FILE"
fi

echo "✅ Generated $CHANGELOG_FILE"
echo ""
echo "Sections added:"
for cat in "Added" "Fixed" "Changed" "Removed" "Security"; do
  if [[ -n "${CATEGORIES[$cat]}" ]]; then
    echo "  $cat: $(echo -e "${CATEGORIES[$cat]}" | grep -c "^-" || echo 0) entries"
  fi
done
