---
description: Orchestrate a full roadmap phase. Designs features, imports to tracker, creates issues, then executes.
---

## User Input

```text
$ARGUMENTS
```

`$ARGUMENTS` is a phase identifier or description. If empty, ask the user which phase to start.

## Setup

1. Read `.coco/config.yaml` for project configuration.

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

**a. Check for existing spec directories** using the Glob tool for each feature: `{specs_dir}/{feature}/*`

**b. Check for existing code** using Grep and Glob tools to search the codebase for related files (do NOT delegate to subagents for this).

**c. Check for existing tracker epic:**
```bash
coco-tracker list --json
```
From the output, identify records where `type` is `"epic"`.

**d. Check issue tracker** (if configured):
Based on `issue_tracker.provider`, search for existing projects/issues.
- **github** with Projects V2: Also check `gh project list --owner {github.owner}` for existing projects matching feature names. Cross-reference with `.coco/state/gh-projects.json` if it exists.

**e. Determine scope and complexity tier** for each feature:

Scope:
- **Already complete** -- design exists, code merged, tests pass -> skip
- **Partially built** -- some code exists -> reduced design
- **Greenfield** -- nothing exists -> full design workflow

Complexity tier (determines pipeline depth):

| Tier | Signal | Pipeline |
|------|--------|----------|
| **Light** | 1-3 files/components mentioned, single user story, no internal dependencies | `design` (light mode) -> `import` (design-only) |
| **Standard** | Multi-file, multiple stories, cross-component dependencies | Full: `interview` -> `design` -> `tasks` -> `import` |

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

### 4. Execute Per-Feature Pipeline

For each feature in the approved order:

**Step A: Design (if design.md doesn't exist)**
- For **Light** tier: Use the `design` skill in light mode (minimal design, skip clarification)
- For **Standard** tier: If `discovery.md` doesn't exist in the feature's spec directory, use the `interview` skill first to gather pre-design context. Then use the `design` skill for full design (which will consume `discovery.md` as input).
- Wait for completion before proceeding

**Step B: Generate tasks (if tasks don't exist) -- Standard tier only**
- Use the `tasks` skill to generate the task list
- **Skip for Light tier** -- go directly to Step C

**Step C: Import to tracker (if epic doesn't exist)**
- For **Light** tier: Use the `import` skill in design-only mode (generates single-task epic from design)
- For **Standard** tier: Use the `import` skill for full import from tasks.md
- This includes the full import workflow with issue tracker bridge

**Step D: Verify Pre-Execution Gate**
```bash
coco-tracker epic-status {epic-id}
```
Confirm tracker tasks exist with dependencies and issue keys.

**Step E: Create feature branch**

Read `pr.branch.feature_prefix` from config (default: `feature`):

```bash
git checkout main
```
```bash
git pull
```

Create the feature branch (`{feature_prefix}` from config, default `feature`):

```bash
git checkout -b "{feature_prefix}/{feature-name}"
```
```bash
git push -u origin "{feature_prefix}/{feature-name}"
```

**Step F: Execute**
Use `/coco:loop` (autonomous) or `/coco:execute` (manual) to run the TDD execution loop for all sub-phases. Each task creates an issue branch, PR, and AI review when `pr.enabled` is true.

**Step G: Feature PR to main**

If `pr.enabled`:

After all sub-phases complete, `/coco:loop` will have already created the feature PR to main (with full-feature AI review). If running manually:

1. Create feature PR:
   ```bash
   gh pr create --base main --head "$FEATURE_BRANCH" --title "{feature-name}: {description}" --body-file - <<'EOF'
   ## Feature Summary

   {feature summary}

   ## Issue PRs Merged

   {list of issue PRs merged}

   ## Test Results

   {test results}
   EOF
   ```
2. Invoke `code-reviewer` agent for full-feature review
3. Address critical findings via review-fix loop
4. Merge after approval:
   ```bash
   gh pr merge {pr-number} --{pr.feature_merge_strategy} --delete-branch
   ```
5. Update all issues in the epic to `status_map.completed` ("Done")

If `pr.enabled` is false (backward compatible, each as a separate Bash tool call):
```bash
git checkout main
```
```bash
git pull
```
```bash
git merge "$FEATURE_BRANCH"
```
```bash
git push
```

### 5. Repeat for Next Feature

Loop back to Step 4 for the next feature in the phase.

### 6. Phase Completion

After all features are merged:

1. Update issue tracker projects to "Completed" (if configured)
   - **github** with Projects V2: Close each feature's GitHub Project via `gh project close {project_number} --owner {github.owner}`. Also close the phase-level project if one was created by `/coco:roadmap`.
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
- The user can interrupt at any point and resume with `/coco:execute`
- Session close protocol applies after each feature merge
