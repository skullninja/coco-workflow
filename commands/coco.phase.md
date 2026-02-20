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

Look for a roadmap or feature list. Check these locations:
- Project README or docs for a roadmap section
- `$ARGUMENTS` for a description of features to implement
- Existing spec directories in `{specs_dir}/`

Extract all features for the phase.

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

**e. Determine scope** for each feature:
- **Already complete** -- spec exists, code merged, tests pass -> skip
- **Partially built** -- some code exists -> reduced spec
- **Greenfield** -- nothing exists -> full spec workflow

### 3. Present Phase Plan

Before doing anything, present the audit results:

```
Phase: {PHASE_NAME}
============================

| # | Feature | Existing Code | Scope | Proposed Order |
|---|---------|---------------|-------|----------------|
| 1 | {name}  | {summary}     | {type}| {order}        |

Proposed execution order: {rationale}

Proceed?
```

Wait for user confirmation using AskUserQuestion.

### 4. Execute Per-Spec Pipeline

For each spec in the approved order:

**Step A: Interview/Specify (if spec doesn't exist)**
- Use `/interview` or `/coco.spec` to create the specification
- Wait for completion before proceeding

**Step B: Plan (if plan doesn't exist)**
- Use `/coco.plan` to generate the implementation plan

**Step C: Generate tasks (if tasks don't exist)**
- Use `/coco.tasks` to generate the task list

**Step D: Import to tracker (if epic doesn't exist)**
- Use `/coco.import` to create tracker epic, tasks, dependencies, and issues
- This includes the full import workflow with issue tracker bridge

**Step E: Verify Pre-Execution Gate**
```bash
coco_tracker epic-status {epic-id}
```
Confirm tracker tasks exist with dependencies and issue keys.

**Step F: Create feature branch**
```bash
git checkout main && git pull
git checkout -b {feature-name}
```

**Step G: Execute**
Use `/coco.execute` to run the TDD execution loop for all sub-phases.

**Step H: Merge to main**
After all sub-phases complete:
```bash
git checkout main && git pull && git merge {branch-name} && git push
```

### 5. Repeat for Next Spec

Loop back to Step 4 for the next feature in the phase.

### 6. Phase Completion

After all features are merged:

1. Update issue tracker projects to "Completed" (if configured)
2. Verify all tracker epics are closed
3. Run full test suite to confirm no regressions
4. Report phase summary:

```
Phase Complete
==================
Specs delivered: {count}
Tests: {total passing}
Commits: {count}
```

## Notes

- Each feature in the phase is self-contained -- if one fails, others can proceed
- The user can interrupt at any point and resume with `/coco.execute`
- Session close protocol applies after each feature merge
