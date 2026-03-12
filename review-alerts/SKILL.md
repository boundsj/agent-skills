---
name: review-alerts
description: |
  Check for pending PR reviews and show a prioritized summary report.
  Use when user says "review alerts", "check my reviews", "any PRs to review",
  "pending reviews", "what PRs need my review", or "review status".
  Report-only skill: summarizes pending reviews but never starts a code review.
  Requires explicit repo and user parameters - does NOT auto-detect.
---

# Review Alerts

Show a prioritized summary of PRs waiting for the caller's review. Never starts an actual review.

## Prerequisites

This skill expects:
- `gh` CLI installed and authenticated
- `jq` available on `PATH`

## Step 1: Validate Inputs

This skill requires two parameters: **repo** (GitHub `owner/name`) and **user** (GitHub login).

If either is missing, ask the user:

```text
I need two things to check your reviews:
- **repo**: GitHub repository (e.g., `owner/repo`)
- **user**: Your GitHub username (e.g., `octocat`)

Which repo and user should I check?
```

And stop until the user provides them. Do NOT auto-detect from git context or `gh api user`.

## Step 2: Discover PRs

Run the bundled discovery script with explicit flags:

```bash
PR_JSON=$("<skill-dir>/find-my-reviews.sh" --detailed --repo "$REPO" --user "$USER")
```

Where `<skill-dir>` is the directory containing this `SKILL.md` file.

If the script returns an empty array (`[]`), respond with:

```text
Nothing to review right now. Enjoy your day!
```

And stop.

## Step 3: Assess Priority and Review Complexity

### Priority

For each PR in the JSON, assign a priority level:

**High** (any of):
- Label contains: urgent, hotfix, blocking, critical, P0, P1, high-priority, expedite
- Base branch matches: `release/*`, `hotfix/*`, `production`
- Age 7+ days

**Medium** (any of):
- Age 3-7 days
- Moderate size with activity

**Low**:
- Created less than 3 days ago, no urgency signals

Sort: High first, then Medium, then Low. Within same priority, oldest first.

### Review Complexity

For each PR, assess review complexity:

**Low**: changed_files <= 3 AND (additions + deletions) < 50 AND no security-sensitive paths
**High**: changed_files > 15 OR (additions + deletions) > 500 OR touches auth/crypto/security paths
**Medium**: everything else

Security-sensitive path patterns: `auth/`, `crypto/`, `keychain/`, `Token`, `Password`, `Secret`, `security/`, `credential`

## Step 4: Format the Report as ASCII Table

Generate a description for each PR: first sentence of the PR body, or "No description" if empty. Truncate to ~60 characters.

Use box-drawing characters for the table. The table IS the output - no per-PR detail sections.

```text
## Pending Reviews

You have **N** PR(s) waiting for your review.

┌───┬─────────────────────────┬──────────┬──────┬────────────────┬──────────┬──────────────────────────────────┬────────────┐
│ # │ PR                      │ Author   │ Age  │ Size           │ Priority │ Description                      │ Complexity │
├───┼─────────────────────────┼──────────┼──────┼────────────────┼──────────┼──────────────────────────────────┼────────────┤
│ 1 │ #123 - Fix auth flow    │ @alice   │ 5d   │ +45 -12 (3f)   │ High     │ Fixes OAuth redirect loop        │ Medium     │
│ 2 │ #456 - Add dark mode    │ @bob     │ 2d   │ +200 -50 (8f)  │ Low      │ Dark mode support for settings   │ Medium     │
└───┴─────────────────────────┴──────────┴──────┴────────────────┴──────────┴──────────────────────────────────┴────────────┘
```

**Rules:**
- Age format: "<1d", "1d", "5d", "1w", "2w" etc.
- Size format: `+N -N (Xf)` where f = files
- PR column: `#number - Title` (truncate title to fit ~25 chars). Include the full GitHub link as a markdown link.
- Description: first sentence of PR body, truncated to ~60 chars. "No description" if empty.
- Complexity column: Low, Medium, or High

## Step 5: Review History Bar Chart

Fetch the user's review activity for the last 5 days using the GitHub search API:

```bash
# For each of the last 5 days, count PRs reviewed
gh api "search/issues?q=repo:$REPO+type:pr+reviewed-by:$USER+updated:YYYY-MM-DD..YYYY-MM-DD" --jq '.total_count'
```

Render a horizontal bar chart using block characters. Each block represents 1 review:

```text
Reviews completed (last 5 days):

Mar 12  ████████████  6
Mar 11  ██████████    5
Mar 10  ████          2
Mar 09                0
Mar 08  ██████        3
                      ─────
                      Total: 16
```

Use `█` (full block) characters. If a day has 0 reviews, show no blocks and just the `0`.
Right-align the count numbers. Show the total at the bottom.

If the API call fails or returns errors, skip the chart silently - it's supplementary.

## Step 6: Stop

After outputting the report and chart, STOP. Do not create worktrees, do not start reviewing code, do not spawn subagents. This skill is report-only.
