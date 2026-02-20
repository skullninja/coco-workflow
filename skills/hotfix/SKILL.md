---
name: coco-hotfix
description: Single-issue workflow for quick fixes and small changes that don't need full epic tracking. Creates a branch, implements the fix, commits with issue tracking, and closes.
---

# Coco Hotfix Skill

Lightweight workflow for single-issue fixes and small changes that don't warrant full epic tracking.

## When to Use

- Bug fixes that affect a single area
- Small enhancements (< 1 day of work)
- Quick changes where dependency tracking isn't needed
- Any work that maps to a single issue tracker entry

For multi-session features with dependencies, use the `coco-execute` skill instead.

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

### 6. Update Issue Tracker

**If "linear"**:
- Update state to `status_map.completed` (default: "In Review")
- Add implementation summary to issue description
- Post comment with details

**If "github"**:
- Add comment with fix details
- Close issue

**If "none"**: Skip

### 7. Report

Output:
- Branch name
- Issue key (if created)
- Commit hash
- Files changed
- Suggested next step (push, create PR, merge)
