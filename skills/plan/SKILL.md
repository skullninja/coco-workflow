---
name: coco-plan
description: Generate a coco-workflow implementation plan (plan.md) with research, data model, and API contracts from an existing spec.md in specs/{feature}/.
---

# Coco Plan Skill

Generate an implementation plan with design artifacts from the feature specification.

## When to Use

- Creating an implementation plan as part of the coco-workflow pipeline
- Called by `/coco.phase` (Step B) or `/planning-session tactical`
- When a plan.md is needed in `specs/{feature}/` before task generation

Prerequisites: `spec.md` must exist. If missing, use the `coco-spec` skill first.

## Setup

1. Read `.coco/config.yaml` for `project.specs_dir` (default: `specs`).
2. Determine the current feature by:
   - Checking the current git branch name
   - Looking for the matching directory in `{specs_dir}/{branch-name}/`
   - Or from conversation context if a feature was recently discussed
3. Load `{specs_dir}/{feature}/spec.md` (required). If missing, instruct user to use the `coco-spec` skill first.
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
- Suggested next step: use the `coco-tasks` skill to generate the task list

## Rules

- Use absolute paths throughout
- ERROR on gate failures or unresolved clarifications
- Do NOT generate tasks.md -- that is the `coco-tasks` skill
