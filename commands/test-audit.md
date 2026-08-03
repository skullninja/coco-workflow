---
description: Audit the test suite for low-value tests. Scores every test against the test value rubric and reports Keep / Keep-rewrite / Consolidate / Delete / Escalate recommendations.
---

## User Input

```text
$ARGUMENTS
```

`$ARGUMENTS` can contain:
- A path scope (e.g. `tests/auth` or `src/`) -- limits the audit to that subtree. Default: the whole repo.
- `--summary` -- print the report to the terminal only, do not write a file.

## Setup

1. Read `.coco/config.yaml` for:
   - `testing.test_audit_report_dir` (default: `docs/test-audit`)
   - `testing.test_audit_exclude` -- path globs to skip
   - `testing.test_command` -- context only; this command never runs the suite
   - `project.specs_dir` (default: `specs`)

2. Load the test value rubric, resolving in order:
   - `.coco/templates/test-value-rubric.md` (project override)
   - `${CLAUDE_PLUGIN_ROOT}/templates/test-value-rubric.md` (default)

3. Get the current date for the report filename:
   ```bash
   date -u +%Y-%m-%d
   ```

## Execution

### 1. Inventory the suite

Find test files by convention, honoring the scope argument and `test_audit_exclude`:

```bash
git ls-files
```

Filter the output for test paths -- `test_*`, `*_test.*`, `*.test.*`, `*.spec.*`, `tests/**`, `spec/**`, `__tests__/**` -- and drop anything matching an exclude glob. Use `git ls-files` rather than `find` so untracked scratch files and build artifacts never enter the audit.

Report the count before proceeding. If it is zero, follow Edge Cases.

### 2. Load the stated intent

For each feature directory under `{specs_dir}/`, read the `## Test Strategy` section of `design.md` if present. Collect the FRs marked `Test? = yes`, the levels chosen, and everything listed under **Not worth testing**.

This is *evidence*, not authority. Designs are written before implementation and are never rewritten afterward, so a stale "not worth testing" note penalizes a test's behavioral anchoring but never by itself justifies deleting it. Record which designs were found -- the report states what the audit had to work with.

### 3. Score

**If the inventory is 40 files or fewer**: score inline, reading each test file and enough of the code under test to answer "what defect would ship without this?"

**If larger**: dispatch `test-auditor` agents via the Task tool, one per module or top-level test directory, up to 4 at a time. Send all agent calls for a batch in a **single message** (multiple tool calls) so they run concurrently. Each agent receives its file list, the repo root, and the relevant design paths.

Either way, follow the rubric's verdicts exactly: Keep, Keep-rewrite, Consolidate, Delete, Escalate.

Before proposing any deletion, check for regression origin:

```bash
git log -S'{test name}' --format=%s --max-count=3 -- {file}
```

A test introduced by a commit that fixed a bug is `Escalate`, never `Delete`.

### 4. Cluster redundancy globally

**This pass must run over the whole inventory at once, never per module.** The duplicate of `tests/auth/test_login.py::test_rejects_bad_password` almost always lives in `tests/integration/`, not beside it. Sharded clustering reports "no duplicates found" every time and is worse than not running.

Group tests by the failure mode they defend. Within each group of two or more:
- Keep the one at the cheapest level that catches the failure
- Mark the rest `Consolidate`, naming the survivor
- Where the same happy path is defended at unit, integration, and e2e level, say so explicitly -- that is one test's value at three tests' cost

### 5. Assign finding IDs

Number every actionable finding `TA-1`, `TA-2`, ... in severity order: Delete, then Consolidate, then Keep-rewrite, then Escalate. `Keep` verdicts get no ID -- they are not actions.

### 6. Render the report

```markdown
# Test Audit -- {date}

**Scope**: {path or "whole repo"}
**Test files**: {n} ({m} excluded by config)
**Tests reviewed**: {count}
**Designs found**: {k} of {total} features had a Test Strategy

## Summary

| Verdict | Count |
|---------|-------|
| Keep | {n} |
| Keep-rewrite | {n} |
| Consolidate | {n} |
| Delete | {n} |
| Escalate | {n} |

## Findings

| ID | Verdict | Test | Location | Defends | Evidence |
|----|---------|------|----------|---------|----------|
| TA-1 | Delete | {name} | `{file}:{line}` | nothing | {quoted assertion} |
| TA-2 | Consolidate | {name} | `{file}:{line}` | {failure mode} | duplicate of `{file}:{line}` |

## Redundancy clusters

**{failure mode}** -- defended {n} times:
- `{file}:{line}` ({level}) -- KEEP, cheapest level
- `{file}:{line}` ({level}) -- consolidate into the above

## Escalations

Tests that cannot be adjudicated from code alone. Do not delete without a human decision.

- `{file}:{line}` -- {reason: sole defender of X | introduced by bugfix {commit subject}}

## Next steps

Act on findings through the hotfix workflow -- ask Claude to "fix TA-1 and TA-4".
Each fix branches, applies the change, and opens a PR whose body cites the finding IDs
it resolves. Code review reads those IDs and skips re-litigating the removed coverage.
```

### 7. Write and report

Unless `--summary` was passed, write the report to `{test_audit_report_dir}/{date}.md`. Create the directory if needed.

Print to the terminal: the summary table, the top 5 findings by severity, and the report path.

Close with the actionable next step: the user asks Claude to "fix TA-N" in natural language, which routes to the `hotfix` skill. Never suggest `/coco:hotfix` -- hotfix is a skill, not a slash command.

### Edge Cases

- **No test files found**: Output "No test files found in {scope}. Nothing to audit." and exit.
- **No `.coco/config.yaml`**: Use defaults throughout. Do not require coco initialization to audit a suite.
- **No `specs/` directory or no Test Strategy sections**: Proceed. Note in the report that no stated intent was available, and score on the rubric alone. Do not infer a strategy and grade against it.
- **Not a git repository**: Skip the regression-origin check and mark every deletion candidate `Escalate` instead -- without git history you cannot tell a tautology from a regression test.
- **Scope argument matches nothing**: Output "Scope {arg} matched no test files." and exit.
- **A `test-auditor` agent fails**: Report which scope went unaudited in the report's coverage line. Never silently drop a slice.

## Rules

- **STRICTLY READ-ONLY except the report file.** Never delete, edit, or move a test. Never write to the tracker. Never create branches, epics, or issues.
- Never run the test suite. This audit reads code; it does not execute it.
- Never propose deleting a test that was not read in full.
- Quote the failing assertion on every Delete finding. An unquoted Delete is not actionable.
- Report a healthy suite honestly. "34 tests, no findings" is a valid result -- do not manufacture findings to justify the run.
- State what was not covered. If agents failed or files were unreadable, the coverage line says so. A silent gap reads as a clean bill of health.
- Do not propose new tests. Coverage gaps are the planning pipeline's job, not the audit's.
