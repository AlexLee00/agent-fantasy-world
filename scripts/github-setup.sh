#!/usr/bin/env bash
# ============================================================
# Agent Fantasy World — GitHub Repository Setup Script
# ============================================================
# Usage:  chmod +x scripts/github-setup.sh && ./scripts/github-setup.sh
# Prerequisites: gh CLI authenticated (gh auth login)
# ============================================================
set -euo pipefail

OWNER="AlexLee00"
REPO="agent-fantasy-world"
FULL="$OWNER/$REPO"

echo "🏰 Agent Fantasy World — GitHub Setup"
echo "======================================"

# -----------------------------------------------------------
# 1. LABELS — Sync from .github/labels.json
# -----------------------------------------------------------
echo ""
echo "📌 Step 1: Creating labels..."

for label in "bug" "documentation" "duplicate" "enhancement" "invalid" "question"; do
  gh label delete "$label" --repo "$FULL" --yes 2>/dev/null || true
done

jq -c '.[]' .github/labels.json | while read -r label; do
  name=$(echo "$label" | jq -r '.name')
  color=$(echo "$label" | jq -r '.color')
  desc=$(echo "$label" | jq -r '.description')
  gh label create "$name" --color "$color" --description "$desc" --repo "$FULL" --force
  echo "  ✅ $name"
done

# -----------------------------------------------------------
# 2. BRANCH PROTECTION — main
# -----------------------------------------------------------
echo ""
echo "🛡️  Step 2: Branch protection for 'main'..."

gh api repos/$FULL/branches/main/protection \
  --method PUT \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["CI"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOF

echo "✅ main branch protected"
echo "   • 1 reviewer required + CODEOWNERS"
echo "   • Stale reviews dismissed on new push"
echo "   • CI status checks required (strict)"
echo "   • Linear history enforced"
echo "   • Force push & deletion blocked"
echo "   • Conversation resolution required"

# -----------------------------------------------------------
# 3. BRANCH PROTECTION — develop
# -----------------------------------------------------------
echo ""
echo "🛡️  Step 3: Branch protection for 'develop'..."

gh api repos/$FULL/git/refs \
  --method POST \
  --field ref="refs/heads/develop" \
  --field sha="$(gh api repos/$FULL/git/ref/heads/main --jq '.object.sha')" \
  2>/dev/null || echo "  (develop already exists)"

gh api repos/$FULL/branches/develop/protection \
  --method PUT \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["CI"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOF

echo "✅ develop branch protected"

# -----------------------------------------------------------
# 4. REPO SETTINGS — Merge strategy & features
# -----------------------------------------------------------
echo ""
echo "⚙️  Step 4: Repository settings..."

gh api repos/$FULL \
  --method PATCH \
  --input - <<'EOF'
{
  "has_issues": true,
  "has_projects": true,
  "has_wiki": false,
  "has_discussions": true,
  "allow_squash_merge": true,
  "allow_merge_commit": false,
  "allow_rebase_merge": true,
  "squash_merge_commit_title": "PR_TITLE",
  "squash_merge_commit_message": "PR_BODY",
  "delete_branch_on_merge": true,
  "allow_auto_merge": true,
  "allow_update_branch": true
}
EOF

echo "✅ Merge strategy configured"
echo "   • Squash merge ✅ (PR title + body)"
echo "   • Merge commit ❌ disabled"
echo "   • Rebase merge ✅"
echo "   • Auto-delete branches ✅"
echo "   • Auto-merge ✅"
echo "   • Discussions ✅ | Wiki ❌"

# -----------------------------------------------------------
# 5. SECURITY — Vulnerability alerts & secret scanning
# -----------------------------------------------------------
echo ""
echo "🔐 Step 5: Security features..."

gh api repos/$FULL/vulnerability-alerts --method PUT 2>/dev/null \
  && echo "  ✅ Vulnerability alerts" || echo "  ℹ️  Already enabled"

gh api repos/$FULL/automated-security-fixes --method PUT 2>/dev/null \
  && echo "  ✅ Automated security fixes" || echo "  ℹ️  Already enabled"

gh api repos/$FULL --method PATCH --input - <<'EOF' 2>/dev/null
{
  "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" }
  }
}
EOF
echo "  ✅ Secret scanning + push protection"

echo ""
echo "======================================"
echo "🎉 Setup complete!"
echo ""
echo "Branch flow:"
echo "  feature/* → develop (squash)"
echo "  develop   → main    (squash + CODEOWNERS)"
echo "======================================"
