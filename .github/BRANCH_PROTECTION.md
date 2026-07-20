# Branch Protection Rules

This document describes the branch protection rules for `develop → staging → main` and
the `gh` CLI commands to apply them. Run each command once after creating the `staging` branch.

## Workflow overview

| Branch | Who can PR | Required checks | Review |
|---|---|---|---|
| `develop` | Anyone | Vercel build + `Frontend Lint` | None |
| `staging` | Only from `develop` | `Check source branch` + `E2E Tests` | None |
| `main` | Only from `staging` | `Check source branch` | 1 approval (admin-bypassable) |

## Setup commands

### Step 1 — create the staging branch (if it doesn't exist yet)

```bash
git checkout develop && git checkout -b staging
git push -u origin staging
```

### Step 2 — apply branch protection rules via gh CLI

```bash
# develop — require Vercel check + lint; no review needed
gh api repos/publius-projects/powers-monorepo/branches/develop/protection \
  --method PUT \
  --field enforce_admins=false \
  --field "required_status_checks[strict]=false" \
  --field "required_status_checks[contexts][]=Frontend Lint" \
  --field "required_status_checks[contexts][]=Vercel – powers" \
  --field required_pull_request_reviews=null \
  --field restrictions=null

# staging — source branch check + e2e; no review needed
gh api repos/publius-projects/powers-monorepo/branches/staging/protection \
  --method PUT \
  --field enforce_admins=false \
  --field "required_status_checks[strict]=true" \
  --field "required_status_checks[contexts][]=Check source branch" \
  --field "required_status_checks[contexts][]=E2E Tests" \
  --field required_pull_request_reviews=null \
  --field restrictions=null

# main — source branch check + 1 reviewer; admins can bypass (overwritable)
gh api repos/publius-projects/powers-monorepo/branches/main/protection \
  --method PUT \
  --field enforce_admins=false \
  --field "required_status_checks[strict]=true" \
  --field "required_status_checks[contexts][]=Check source branch" \
  --field "required_pull_request_reviews[required_approving_review_count]=1" \
  --field "required_pull_request_reviews[require_code_owner_reviews]=true" \
  --field "required_pull_request_reviews[dismiss_stale_reviews]=false" \
  --field restrictions=null
```

### Step 3 — find the Vercel check name

The `<vercel-check-name>` placeholder above needs to be the exact string Vercel posts
as a GitHub check. To find it:

1. Open any existing PR to `develop` on GitHub
2. Scroll to the merge checklist — the Vercel check name appears there (e.g. `"Vercel – powers-monorepo"`)
3. Replace `<vercel-check-name>` in the develop command above and re-run it

## Notes

- `enforce_admins=false` means repository admins can merge without satisfying the rules
  (the "overwritable" requirement for `main`). Set to `true` to enforce for everyone.
- The `Check source branch` job in `ci-staging.yml` / `ci-main.yml` only enforces the
  source-branch restriction on real PRs — manual `workflow_dispatch` triggers skip the check.
- Solidity tests no longer run in CI (the `solidity-tests` job was removed from
  `ci-staging.yml`); run them locally with `cd solidity && forge test`.
