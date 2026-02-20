---
description: Orchestrate a full roadmap phase. Plans specs, imports to tracker, creates issues, then executes.
---

## User Input

```text
$ARGUMENTS
```

`$ARGUMENTS` is a phase identifier or description. If empty, ask the user which phase to start.

## Setup

1. Read `.coco/config.yaml` for project configuration.
2. Source `${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh`.

## Execution

### 1. Identify Specs for the Phase

Read `discovery.roadmap_dir` from config (default: `docs/roadmap`).

**Structured roadmap lookup** (preferred):
1. Glob `{roadmap_dir}/*.md` for roadmap files
2. If `$ARGUMENTS` matches a phase name or number in a roadmap file (e.g., "Phase 1: Foundation"):
   - Parse the phase table to get the feature list with slugs, priority order, and scores
   - Extract cross-feature dependencies from the phase section
3. If `$ARGUMENTS` is a release name (e.g., "v1.0"):
   - Open `{roadmap_dir}/{release}.md` and ask the user which phase to execute

**Fallback** (no roadmap files found):
- Search project README or docs for a roadmap section
- Use `$ARGUMENTS` as a description of features to implement
- Check existing spec directories in `{specs_dir}/`

Extract all features for the phase. When sourced from a roadmap, preserve the priority order and scores for reporting.

### 2. Audit Existing State

For each feature:

**a. Check for existing spec directory:**
```bash
ls {specs_dir}/{feature}/ 2>/dev/null
```

**b. Check for existing code** -- search codebase for related files.

**c. Check for existing tracker epic:**
```bash
coco_tracker list --json | jq 'select(.type == "epic")'
```

**d. Check issue tracker** (if configured):
Based on `issue_tracker.provider`, search for existing projects/issues.

**e. Determine scope and complexity tier** for each feature:

Scope:
- **Already complete** -- spec exists, code merged, tests pass -> skip
- **Partially built** -- some code exists -> reduced spec
- **Greenfield** -- nothing exists -> full spec workflow

Complexity tier (determines pipeline depth):

| Tier | Signal | Pipeline |
|------|--------|----------|
| **Light** | 1-3 files/components mentioned, single user story, no internal dependencies | `coco-spec` (light mode) -> `coco-import` (spec-only) |
| **Standard** | Multi-file, multiple stories, cross-component dependencies | Full: `coco-spec` -> `coco-plan` -> `coco-tasks` -> `coco-import` |

Classify based on: number of files/components mentioned in the roadmap, feature description complexity, and whether the feature has internal dependencies.

### 3. Present Phase Plan

Before doing anything, present the audit results:

```
Phase: {PHASE_NAME}
============================

| # | Feature | Existing Code | Scope | Tier | Proposed Order |
|---|---------|---------------|-------|------|----------------|
| 1 | {name}  | {summary}     | {type}| {Light/Standard} | {order} |

Proposed execution order: {rationale}

Proceed?
```

Wait for user confirmation using AskUserQuestion.

### 4. Execute Per-Spec Pipeline

For each spec in the approved order:

**Step A: Interview/Specify (if spec doesn't exist)**
- For **Light** tier: Use the `coco-spec` skill in light mode (minimal spec, skip clarification)
- For **Standard** tier: Use `/interview` or the `coco-spec` skill for full specification
- Wait for completion before proceeding

**Step B: Plan (if plan doesn't exist) -- Standard tier only**
- Use the `coco-plan` skill to generate the implementation plan
- **Skip for Light tier** -- go directly to Step D

**Step C: Generate tasks (if tasks don't exist) -- Standard tier only**
- Use the `coco-tasks` skill to generate the task list
- **Skip for Light tier** -- go directly to Step D

**Step D: Import to tracker (if epic doesn't exist)**
- For **Light** tier: Use the `coco-import` skill in spec-only mode (generates single-task epic from spec)
- For **Standard** tier: Use the `coco-import` skill for full import from tasks.md
- This includes the full import workflow with issue tracker bridge

**Step E: Verify Pre-Execution Gate**
```bash
coco_tracker epic-status {epic-id}
```
Confirm tracker tasks exist with dependencies and issue keys.

**Step F: Create feature branch**

Read `pr.branch.feature_prefix` from config (default: `feature`):

```bash
git checkout main && git pull
FEATURE_BRANCH="{feature_prefix}/{feature-name}"
git checkout -b "$FEATURE_BRANCH"
git push -u origin "$FEATURE_BRANCH"
```

**Step G: Execute**
Use `/coco.loop` (autonomous) or `/coco.execute` (manual) to run the TDD execution loop for all sub-phases. Each task creates an issue branch, PR, and AI review when `pr.enabled` is true.

**Step H: Feature PR to main**

If `pr.enabled`:

After all sub-phases complete, `/coco.loop` will have already created the feature PR to main (with full-feature AI review). If running manually:

1. Create feature PR:
   ```bash
   gh pr create --base main --head "$FEATURE_BRANCH" \
     --title "{feature-name}: {description}" \
     --body "{feature summary, list of issue PRs merged, test results}"
   ```
2. Invoke `code-reviewer` agent for full-feature review
3. Address critical findings via review-fix loop
4. Merge after approval:
   ```bash
   gh pr merge {pr-number} --{pr.feature_merge_strategy} --delete-branch
   ```
5. Update all issues in the epic to `status_map.completed` ("Done")

If `pr.enabled` is false (backward compatible):
```bash
git checkout main && git pull && git merge "$FEATURE_BRANCH" && git push
```

### 5. Repeat for Next Spec

Loop back to Step 4 for the next feature in the phase.

### 6. Phase Completion

After all features are merged:

1. Update issue tracker projects to "Completed" (if configured)
2. Verify all tracker epics are closed
3. Run full test suite to confirm no regressions
4. **Update roadmap** (if phase was sourced from a roadmap file):
   - Set the phase `**Status**` to `Complete`
   - Update each feature row's `Status` column to `Complete`
   - Update each feature row's `Spec` column to `specs/{slug}/`
   - Append to the roadmap Change Log: `{date} | Phase N complete | All features merged`
5. Report phase summary:

```
Phase Complete
==================
Specs delivered: {count}
Tests: {total passing}
Commits: {count}
Roadmap updated: {roadmap file path} (if applicable)
```

## Notes

- Each feature in the phase is self-contained -- if one fails, others can proceed
- The user can interrupt at any point and resume with `/coco.execute`
- Session close protocol applies after each feature merge
