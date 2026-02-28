---
name: hotfix
description: Single-issue workflow for quick fixes and small changes that don't need full epic tracking. Creates a branch, implements the fix, commits with issue tracking, and closes.
---

# Coco Hotfix Skill

Lightweight workflow for single-issue fixes and small changes that don't warrant full epic tracking.

## When to Use

- Bug fixes that affect a single area
- Small enhancements (< 1 day of work)
- Quick changes where dependency tracking isn't needed
- Any work that maps to a single issue tracker entry

For multi-session features with dependencies, use the `execute` skill instead.

## Workflow

### 1. Setup

Read `.coco/config.yaml` for issue tracker configuration.

If `$ARGUMENTS` contains an issue key/ID, load it. Otherwise, create a new issue:

**If "linear"**:
```
Use: mcp__plugin_linear_linear__create_issue
Parameters:
  title: "{fix description}"
  team: {from config}
  labels: {from config}
  state: "In Progress"
```

**If "github"**:
```bash
gh issue create --title "{fix description}" --label {labels}
```

If `github.use_projects` is true: check `.coco/state/gh-projects.json` for an active feature project. If one exists, add the issue to it and set status to "In Progress":
```bash
gh project item-add {project_number} --owner {github.owner} --url {issue_url}
gh project item-edit \
  --project-id {project_id} \
  --id {item_id} \
  --field-id {status_field_id} \
  --single-select-option-id {status_options["In Progress"]}
```

**If "none"**: Skip issue creation.

### 2. Create Branch

```bash
git checkout -b fix/{short-name}
```

### 3. Implement Fix

- Understand the issue (read related code, reproduce if bug)
- Write tests if appropriate (especially for bugs -- reproduce the bug in a test first)
- Implement the fix
- Run test suite to verify no regressions

### 4. Pre-Commit Validation

Check `pre_commit.ui_patterns` from config against staged files. If matches found and pre-commit-tester agent is configured, invoke it.

### 5. Commit

```bash
git add {specific-files}
git commit -m "$(cat <<'EOF'
{fix description}. Completes {issue_key}

{What was wrong and how it was fixed}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### 6. Create PR and Review

Read `pr` config from `.coco/config.yaml`.

**If `pr.enabled`:**

```bash
git push -u origin fix/{short-name}

gh pr create \
  --base main \
  --head fix/{short-name} \
  --title "{issue_key}: {fix description}" \
  --body-file - <<'EOF'
## Fix Summary

{What was wrong and how it was fixed}

Resolves {issue_key}

## Test Results

{test output summary}
EOF
```

If `github.use_projects` is true and the issue was added to a project, add the PR to the project board:

```bash
PR_URL=$(gh pr view --json url -q .url)
gh project item-add {project_number} --owner {github.owner} --url "$PR_URL"
```

If `pr.review.enabled`:
- Invoke `code-reviewer` agent on the PR
- If CHANGES REQUESTED: fix critical findings, push, re-review (same loop as `/coco:execute`)
- After approval: merge PR

```bash
gh pr merge {pr-number} --{pr.issue_merge_strategy} --delete-branch
```

**If `pr.enabled` is false:**
- Push branch and suggest creating a PR manually

### 7. Update Issue Tracker

**Triggered by PR merge (or by commit if PRs disabled).** This is when the issue resolves.

**If "linear"**:
- Update state to `status_map.completed` (default: "Done")
- Add implementation summary to issue description
- Post comment with details

**If "github"**:
- Add comment with fix details
- `Closes #N` in PR body auto-closes the issue (if using PRs)
- If `github.use_projects` is true and the issue was added to a project: set status to "Done":
  ```bash
  gh project item-edit \
    --project-id {project_id} \
    --id {item_id} \
    --field-id {status_field_id} \
    --single-select-option-id {status_options["Done"]}
  ```

**If "none"**: Skip

### 8. Report

Output:
- Branch name
- Issue key (if created)
- PR number (if created)
- Commit hash
- Files changed
