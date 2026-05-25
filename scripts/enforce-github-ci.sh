#!/usr/bin/env bash
# Apply required CI/CD status checks on the default branch (idempotent).
set -euo pipefail

REPO="${GITHUB_REPOSITORY:-chrsappiah-cloud/Agedcare-shared}"
BRANCH="${1:-main}"

CONTEXTS=(
  "SwiftLint"
  "Cloudflare Worker Syntax"
  "Build & Unit Tests"
  "Analyze Swift"
)

checks_json="$(printf '%s\n' "${CONTEXTS[@]}" | jq -R '{context: .}' | jq -s '.')"

payload="$(jq -n \
  --argjson checks "$checks_json" \
  '{
    required_status_checks: {strict: true, checks: $checks},
    enforce_admins: true,
    required_pull_request_reviews: {
      required_approving_review_count: 1,
      dismiss_stale_reviews: true
    },
    restrictions: null,
    required_linear_history: true,
    allow_force_pushes: false,
    allow_deletions: false,
    block_creations: false,
    required_conversation_resolution: true
  }')"

echo "Enforcing branch protection on $REPO:$BRANCH"
echo "$payload" | gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/branches/$BRANCH/protection" \
  --input -

echo "Branch protection updated. Required checks:"
printf '  - %s\n' "${CONTEXTS[@]}"
