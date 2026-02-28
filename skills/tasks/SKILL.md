---
name: tasks
description: Generate a dependency-ordered task list (tasks.md) with sub-phases and cross-artifact consistency analysis from design.md in specs/{feature}/.
---

# Coco Tasks Skill

Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts, then run cross-artifact consistency analysis.

## When to Use

- Generating a task list as part of the coco pipeline
- Called by `/coco:phase` (Step B) or `/planning-session tactical`
- When a tasks.md is needed in `specs/{feature}/` before tracker import

Prerequisites: `design.md` must exist. If missing, use the `design` skill first.

**Legacy fallback**: If `design.md` doesn't exist, check for `spec.md` + `plan.md` as legacy artifacts and load both.

## Setup

1. Read `.coco/config.yaml` for `project.specs_dir` (default: `specs`).
2. Determine the current feature by:
   - Checking the current git branch name
   - Looking for the matching directory in `{specs_dir}/{branch-name}/`
   - Or from conversation context if a feature was recently discussed
3. Load design documents from `{specs_dir}/{feature}/`:
   - **Required**: design.md (user stories, tech stack, structure, API contracts, research decisions)
   - **Optional**: data-model.md (entities, if generated separately)
   - **Legacy fallback**: If `design.md` doesn't exist, load `spec.md` + `plan.md` + `data-model.md` + `contracts/` + `research.md` as legacy artifacts
4. Load the tasks template from `.coco/templates/tasks-template.md` if it exists, otherwise use `${CLAUDE_PLUGIN_ROOT}/templates/tasks-template.md`.

## Execution

### 1. Extract Context

- From design.md: tech stack, libraries, project structure, user stories with priorities (P1, P2, P3...), API contracts, research decisions
- From data-model.md (if exists): entities, map to user stories

**Legacy mode** (if loading spec.md + plan.md instead):
- From plan.md: tech stack, libraries, project structure
- From spec.md: user stories with priorities
- From data-model.md, contracts/, research.md (if exist): entities, endpoints, decisions

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
  - Tests are OPTIONAL (include only if design requests TDD)
  - Order within story: Tests -> Models -> Services -> Endpoints -> Integration
- **Final Sub-Phase: Polish** - Cross-cutting concerns

Each sub-phase MUST have an **Acceptance Criteria** section with specific, testable outcomes.

### 4. Dependencies, Parallel Map & File Ownership

Generate:
- Dependency graph showing sub-phase completion order
- File ownership per sub-phase with conflict risk
- Parallel execution opportunities

**File Ownership (`owns_files`) Annotations:**

If `design.md` contains file-level implementation details (in the Project Structure or Technical Approach sections), extract file ownership per sub-phase. For each user story sub-phase, identify the files/directories it exclusively modifies:

```markdown
### Sub-Phase 3: User Authentication
**owns_files**: `src/auth/**`, `tests/auth/**`
```

These annotations are consumed by the `import` skill to populate task metadata, enabling worktree-based parallel execution. Only include `owns_files` when file paths are determinable from the design -- omit for sub-phases with unclear file boundaries.

### 5. Write tasks.md

Write to `{specs_dir}/{feature}/tasks.md`.

### 6. Cross-Artifact Consistency Analysis

After generating tasks.md, automatically run the full consistency analysis. This replaces what was previously the `/coco:analyze` command.

**STRICTLY READ-ONLY**: Do not modify any files during analysis. Output findings inline.

Load from `{specs_dir}/{feature}/`:
- design.md (required; or spec.md + plan.md in legacy mode)
- tasks.md (just generated)
- data-model.md (if exists)
- `.coco/memory/constitution.md` if it exists

#### Detection Passes (limit 50 findings total)

**A. Duplication Detection**
- Near-duplicate requirements across artifacts
- Mark lower-quality phrasing for consolidation

**B. Ambiguity Detection**
- Vague adjectives (fast, scalable, secure, intuitive, robust) lacking measurable criteria
- Unresolved placeholders (TODO, ???, `<placeholder>`)

**C. Underspecification**
- Requirements with verbs but missing object or measurable outcome
- User stories missing acceptance criteria alignment
- Tasks referencing files or components not defined in design

**D. Constitution Alignment**
- Any requirement or plan element conflicting with a constitution MUST principle
- Missing mandated sections or quality gates
- Constitution conflicts are automatically CRITICAL severity

**E. Coverage Gaps**
- Requirements with zero associated tasks
- Tasks with no mapped requirement/story
- Non-functional requirements not reflected in tasks

**F. Inconsistency**
- Terminology drift (same concept named differently across files)
- Data entities in data-model.md but absent in design (or vice versa)
- Task ordering contradictions
- Conflicting requirements

#### Severity Assignment

- **CRITICAL**: Constitution violation, missing core artifact, requirement with zero coverage blocking baseline
- **HIGH**: Duplicate/conflicting requirement, ambiguous security/performance attribute, untestable criterion
- **MEDIUM**: Terminology drift, missing non-functional task coverage, underspecified edge case
- **LOW**: Style/wording improvements, minor redundancy

#### Analysis Output

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

After the report, ask the user: "Would you like me to suggest concrete remediation edits for the top N issues?"

### 7. Report

Output:
- Path to tasks.md
- Total task count and count per user story
- Parallel opportunities identified
- Independent test criteria for each story
- Suggested MVP scope (typically User Story 1)
- Analysis findings (from consistency analysis step)
- Suggested next step: tell the user to ask Claude to "import tasks into the tracker" (this triggers the `import` skill automatically -- skills are NOT slash commands, so never suggest `/coco:import`)

## Rules

- Tasks must be specific enough for an LLM to complete without additional context
- Each user story must be independently implementable and testable
- No vague acceptance criteria ("works correctly", "looks good")
- Include exact file paths in every task description
- Never hallucinate missing sections in the analysis
- Prioritize constitution violations (always CRITICAL)
- Report zero analysis issues gracefully with coverage statistics
