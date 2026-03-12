#!/usr/bin/env bash
# ABOUTME: Discovers open PRs where the current GitHub user has an outstanding
# ABOUTME: review request. Uses gh pr list (GraphQL) instead of the search API for reliability.
# ABOUTME: Supports --detailed (metadata JSON) and --classify (adds review tier + mention detection).

set -euo pipefail

DETAILED=false
CLASSIFY=false
REPO=""
ME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --detailed) DETAILED=true; shift ;;
    --classify) CLASSIFY=true; DETAILED=true; shift ;;
    --repo) REPO="$2"; shift 2 ;;
    --user) ME="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Auto-detect repo if not provided
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
  if [ -z "$REPO" ]; then
    echo "ERROR: Could not determine repository. Pass --repo owner/name or run from within a git repo." >&2
    exit 1
  fi
fi

# Auto-detect user if not provided
if [ -z "$ME" ]; then
  ME=$(gh api user --jq '.login' 2>/dev/null || echo "")
  if [ -z "$ME" ]; then
    echo "ERROR: Could not determine GitHub user. Pass --user <login> or check gh auth status." >&2
    exit 1
  fi
fi

# Fetch all open PRs with review request metadata in a single GraphQL call.
# Filter client-side for PRs where the user has an outstanding review request.
# The reviewRequests field is the source of truth: GitHub removes users when they
# submit a review and re-adds them when the author re-requests review. Team requests
# are excluded because teams don't have a .login field matching a username.
ALL_PRS=$(gh pr list --repo "$REPO" --state open --limit 200 \
  --json number,title,isDraft,reviewRequests,author,createdAt,updatedAt,labels,additions,deletions,changedFiles,baseRefName,headRefName,body 2>/dev/null || echo "[]")

if [ "$DETAILED" = false ]; then
  # Simple mode: output matching PR numbers, one per line
  echo "$ALL_PRS" | jq -r --arg me "$ME" '
    [.[] | select(.isDraft == false) | select(.reviewRequests | map(select(.login == $me)) | length > 0)]
    | sort_by(.number)
    | .[].number
  '
else
  # Detailed mode: output JSON array with metadata for priority assessment,
  # normalized to the field names the SKILL.md report expects
  FILTERED=$(echo "$ALL_PRS" | jq --arg me "$ME" '
    [.[] | select(.isDraft == false) | select(.reviewRequests | map(select(.login == $me)) | length > 0)]
    | sort_by(.number)
    | [.[] | {
        number: .number,
        title: .title,
        author: .author.login,
        created_at: .createdAt,
        updated_at: .updatedAt,
        labels: [.labels[].name],
        additions: .additions,
        deletions: .deletions,
        changed_files: .changedFiles,
        base_branch: .baseRefName,
        head_branch: .headRefName,
        body: ((.body // "") | if length > 500 then .[:500] + "..." else . end)
      }]
  ')

  if [ "$CLASSIFY" = false ]; then
    echo "$FILTERED"
    exit 0
  fi

  # --classify mode: enrich each PR with review_tier, mentions_me, security_relevant
  SENSITIVE_PATTERNS='auth/|crypto/|keychain/|Token|Password|Secret|security/|credential'
  PR_COUNT=$(echo "$FILTERED" | jq 'length')

  # Process PRs in parallel for batches > 5, sequentially otherwise
  TEMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TEMP_DIR"' EXIT

  classify_pr() {
    local idx="$1"
    local pr_json="$2"
    local number
    number=$(echo "$pr_json" | jq -r '.number')
    local changed_files additions deletions body
    changed_files=$(echo "$pr_json" | jq -r '.changed_files')
    additions=$(echo "$pr_json" | jq -r '.additions')
    deletions=$(echo "$pr_json" | jq -r '.deletions')
    body=$(echo "$pr_json" | jq -r '.body // ""')

    # Fetch changed file list
    local file_list
    file_list=$(gh pr diff "$number" --repo "$REPO" --name-only 2>/dev/null || echo "")

    # Check security relevance
    local security_relevant=false
    if echo "$file_list" | grep -qiE "$SENSITIVE_PATTERNS"; then
      security_relevant=true
    fi

    # Determine review tier
    local review_tier="standard"
    local total_lines=$((additions + deletions))
    if [ "$changed_files" -le 3 ] && [ "$total_lines" -lt 30 ] && [ "$security_relevant" = false ]; then
      review_tier="rubber-stamp"
    fi

    # Check for @mentions in PR body
    local mentions_me=false
    local mention_context=""
    if echo "$body" | grep -qiF "@${ME}"; then
      mentions_me=true
      mention_context=$(echo "$body" | grep -iF "@${ME}" | head -1 | cut -c1-200)
    fi

    # Also check PR comments for @mentions
    if [ "$mentions_me" = false ]; then
      local comment_mention
      comment_mention=$(gh pr view "$number" --repo "$REPO" --json comments \
        --jq ".comments[].body" 2>/dev/null | grep -iF "@${ME}" | head -1 | cut -c1-200 || echo "")
      if [ -n "$comment_mention" ]; then
        mentions_me=true
        mention_context="$comment_mention"
      fi
    fi

    # Write enriched JSON to temp file
    echo "$pr_json" | jq \
      --arg tier "$review_tier" \
      --argjson mentions "$mentions_me" \
      --arg mention_ctx "$mention_context" \
      --argjson security "$security_relevant" \
      '. + {
        review_tier: $tier,
        mentions_me: $mentions,
        mention_context: (if $mention_ctx == "" then null else $mention_ctx end),
        security_relevant: $security
      }' > "$TEMP_DIR/$idx.json"
  }

  for i in $(seq 0 $((PR_COUNT - 1))); do
    PR_JSON=$(echo "$FILTERED" | jq ".[$i]")
    if [ "$PR_COUNT" -gt 5 ]; then
      classify_pr "$i" "$PR_JSON" &
    else
      classify_pr "$i" "$PR_JSON"
    fi
  done

  wait

  # Reassemble results in order
  RESULT="["
  for i in $(seq 0 $((PR_COUNT - 1))); do
    if [ "$i" -gt 0 ]; then
      RESULT="${RESULT},"
    fi
    RESULT="${RESULT}$(cat "$TEMP_DIR/$i.json")"
  done
  RESULT="${RESULT}]"

  echo "$RESULT" | jq '.'
fi
