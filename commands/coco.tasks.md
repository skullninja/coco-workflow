---
description: Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts.
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
3. Load design documents from `{specs_dir}/{feature}/`:
   - **Required**: plan.md (tech stack, structure), spec.md (user stories with priorities)
   - **Optional**: data-model.md (entities), contracts/ (API endpoints), research.md (decisions), quickstart.md (test scenarios)
4. Load the tasks template from `.coco/templates/tasks-template.md` if it exists, otherwise use `${CLAUDE_PLUGIN_ROOT}/templates/tasks-template.md`.

## Execution

### 1. Extract Context

- From plan.md: tech stack, libraries, project structure
- From spec.md: user stories with priorities (P1, P2, P3...)
- From data-model.md (if exists): entities, map to user stories
- From contracts/ (if exists): endpoints, map to user stories
- From research.md (if exists): decisions for setup tasks

### 2. Generate Tasks

Organize tasks by user story. Every task MUST use this format:

```text
- [ ] [TaskID] [P?] [Story?] Description with file path
```

- **Checkbox**: Always `- [ ]`
- **Task ID**: Sequential (T001, T002, T003...)
- **[P]**: Include only if parallelizable (different files, no dependencies)
- **[Story]**: Required for user story phases only ([US1], [US2], etc.)
- **Description**: Clear action with exact file path

### 3. Sub-Phase Structure

- **Sub-Phase 1: Setup** - Project initialization
- **Sub-Phase 2: Foundational** - Blocking prerequisites (MUST complete before user stories)
- **Sub-Phase 3+: User Stories** - One sub-phase per story in priority order (P1, P2, P3...)
  - Each includes: goal, independent test criteria, acceptance criteria (min 3), implementation tasks
  - Tests are OPTIONAL (include only if spec requests TDD)
  - Order within story: Tests -> Models -> Services -> Endpoints -> Integration
- **Final Sub-Phase: Polish** - Cross-cutting concerns

Each sub-phase MUST have an **Acceptance Criteria** section with specific, testable outcomes.

### 4. Dependencies & Parallel Map

Generate:
- Dependency graph showing sub-phase completion order
- File ownership per sub-phase with conflict risk
- Parallel execution opportunities

### 5. Write tasks.md

Write to `{specs_dir}/{feature}/tasks.md`.

### 6. Auto-Analyze

After generating tasks.md, automatically run the analysis from `/coco.analyze` to check cross-artifact consistency. Report findings inline rather than requiring a separate command invocation.

### 7. Report

Output:
- Path to tasks.md
- Total task count and count per user story
- Parallel opportunities identified
- Independent test criteria for each story
- Suggested MVP scope (typically User Story 1)
- Analysis findings (from auto-analyze step)
- Suggested next step: `/coco.import` to load tasks into the tracker

## Rules

- Tasks must be specific enough for an LLM to complete without additional context
- Each user story must be independently implementable and testable
- No vague acceptance criteria ("works correctly", "looks good")
- Include exact file paths in every task description
