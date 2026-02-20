---
description: Perform a non-destructive cross-artifact consistency and quality analysis across spec.md, plan.md, and tasks.md.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Identify inconsistencies, duplications, ambiguities, and underspecified items across the three core artifacts (`spec.md`, `plan.md`, `tasks.md`) before implementation. This command should run after `/coco.tasks` has produced a complete `tasks.md`.

**STRICTLY READ-ONLY**: Do not modify any files. Output a structured analysis report.

## Setup

1. Read `.coco/config.yaml` for `project.specs_dir` (default: `specs`).
2. Determine the current feature by:
   - Checking the current git branch name
   - Looking for the matching directory in `{specs_dir}/{branch-name}/`
   - Or use `$ARGUMENTS` if it specifies a feature name
3. Load from `{specs_dir}/{feature}/`:
   - spec.md (required)
   - plan.md (required)
   - tasks.md (required -- if missing, instruct user to run `/coco.tasks`)
4. Load `.coco/memory/constitution.md` if it exists.

## Detection Passes

Limit to 50 findings total.

### A. Duplication Detection
- Near-duplicate requirements across artifacts
- Mark lower-quality phrasing for consolidation

### B. Ambiguity Detection
- Vague adjectives (fast, scalable, secure, intuitive, robust) lacking measurable criteria
- Unresolved placeholders (TODO, ???, `<placeholder>`)

### C. Underspecification
- Requirements with verbs but missing object or measurable outcome
- User stories missing acceptance criteria alignment
- Tasks referencing files or components not defined in spec/plan

### D. Constitution Alignment
- Any requirement or plan element conflicting with a constitution MUST principle
- Missing mandated sections or quality gates
- Constitution conflicts are automatically CRITICAL severity

### E. Coverage Gaps
- Requirements with zero associated tasks
- Tasks with no mapped requirement/story
- Non-functional requirements not reflected in tasks

### F. Inconsistency
- Terminology drift (same concept named differently across files)
- Data entities in plan but absent in spec (or vice versa)
- Task ordering contradictions
- Conflicting requirements

## Severity Assignment

- **CRITICAL**: Constitution violation, missing core artifact, requirement with zero coverage blocking baseline
- **HIGH**: Duplicate/conflicting requirement, ambiguous security/performance attribute, untestable criterion
- **MEDIUM**: Terminology drift, missing non-functional task coverage, underspecified edge case
- **LOW**: Style/wording improvements, minor redundancy

## Output Format

```markdown
## Specification Analysis Report

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| A1 | ... | ... | ... | ... | ... |

**Coverage Summary:**
| Requirement Key | Has Task? | Task IDs | Notes |

**Metrics:**
- Total Requirements / Total Tasks / Coverage %
- Ambiguity Count / Duplication Count / Critical Issues Count

**Next Actions:**
- [Prioritized recommendations based on severity]
```

## Rules

- NEVER modify files
- NEVER hallucinate missing sections
- Prioritize constitution violations (always CRITICAL)
- Report zero issues gracefully with coverage statistics
- After report, ask user: "Would you like me to suggest concrete remediation edits for the top N issues?"
