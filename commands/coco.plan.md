---
description: Execute the implementation planning workflow to generate design artifacts from the feature specification.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Setup

1. Read `.coco/config.yaml` for `project.specs_dir` (default: `specs`).
2. Determine the current feature by:
   - Checking the current git branch name
   - Looking for the matching directory in `{specs_dir}/{branch-name}/`
   - Or use `$ARGUMENTS` if it specifies a feature name
3. Load `{specs_dir}/{feature}/spec.md` (required). If missing, instruct user to run `/coco.spec` first.
4. Load `.coco/memory/constitution.md` if it exists.
5. Load the plan template from `.coco/templates/plan-template.md` if it exists, otherwise use `${CLAUDE_PLUGIN_ROOT}/templates/plan-template.md`.
6. Copy the template to `{specs_dir}/{feature}/plan.md` if it doesn't exist yet.

## Execution

### 1. Fill Plan Template

- Fill Technical Context section (mark unknowns as "NEEDS CLARIFICATION")
- Fill Constitution Check section from constitution (if exists)
- Evaluate gates -- ERROR if violations are unjustified

### 2. Phase 0: Research

For each "NEEDS CLARIFICATION" in Technical Context:
1. Research the unknown using web search or codebase exploration
2. Document findings in `{specs_dir}/{feature}/research.md`:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

### 3. Phase 1: Design & Contracts

**Prerequisites**: research.md complete

1. Extract entities from spec -> `{specs_dir}/{feature}/data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. Generate API contracts from functional requirements:
   - For each user action -> endpoint
   - Use standard REST/GraphQL patterns
   - Output to `{specs_dir}/{feature}/contracts/`

3. Generate quickstart.md with test scenarios and usage examples

**Output**: data-model.md, contracts/*, quickstart.md

### 4. Re-evaluate Constitution Check

If constitution exists, re-check post-design. Document any violations in the Complexity Tracking table with justification.

### 5. Report

Output:
- Branch name
- Plan file path
- List of generated artifacts
- Constitution compliance status
- Suggested next step: `/coco.tasks`

## Rules

- Use absolute paths throughout
- ERROR on gate failures or unresolved clarifications
- Do NOT generate tasks.md -- that is `/coco.tasks`
