---
description: Identify underspecified areas in the current feature spec by asking up to 5 targeted clarification questions and encoding answers back into the spec.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Detect and reduce ambiguity or missing decision points in the active feature specification. This should run BEFORE `/coco.plan`.

## Setup

1. Read `.coco/config.yaml` for `project.specs_dir` (default: `specs`).
2. Determine the current feature by:
   - Checking the current git branch name
   - Looking for the matching directory in `{specs_dir}/{branch-name}/`
   - Or use `$ARGUMENTS` if it specifies a feature name
3. Load `{specs_dir}/{feature}/spec.md`. If missing, instruct user to run `/coco.spec` first.

## Execution

### 1. Ambiguity Scan

Perform a structured coverage scan across these categories, marking each as Clear / Partial / Missing:

- **Functional Scope**: Core user goals, success criteria, explicit out-of-scope
- **Domain & Data Model**: Entities, attributes, relationships, state transitions, scale
- **Interaction & UX Flow**: Critical journeys, error/empty/loading states
- **Non-Functional Quality**: Performance, scalability, reliability, security, compliance
- **Integration**: External services/APIs, data formats, failure modes
- **Edge Cases**: Negative scenarios, rate limiting, conflict resolution
- **Constraints & Tradeoffs**: Technical constraints, rejected alternatives
- **Terminology**: Canonical terms, consistency
- **Completion Signals**: Acceptance criteria testability, Definition of Done

For each Partial/Missing category, generate a candidate question unless clarification wouldn't materially change implementation.

### 2. Sequential Questioning (max 5 questions)

Present EXACTLY ONE question at a time:

- **Multiple-choice**: Recommend the best option prominently with reasoning, then present all options in a table. Include "Short answer" option if appropriate.
- **Short-answer**: Provide a suggested answer with reasoning. Constrain to <=5 words.
- Accept "yes" / "recommended" / "suggested" to use your recommendation.
- Stop when: all critical ambiguities resolved, user says "done", or 5 questions asked.

Prioritize by `Impact * Uncertainty`. Cover highest-impact unresolved categories first.

### 3. Integrate Answers

After each accepted answer:

1. Ensure a `## Clarifications` section exists in the spec (create after the overview section if missing)
2. Under `### Session YYYY-MM-DD`, append: `- Q: <question> -> A: <answer>`
3. Apply the clarification to the appropriate spec section:
   - Functional -> update Functional Requirements
   - Data -> update Key Entities
   - Non-functional -> add measurable criteria
   - Edge case -> add to Edge Cases
   - Terminology -> normalize across spec
4. Replace any invalidated statements (don't leave contradictions)
5. Save the spec file after each integration

### 4. Report

Output:
- Number of questions asked & answered
- Path to updated spec
- Sections touched
- Coverage summary table (Resolved / Deferred / Clear / Outstanding per category)
- Suggested next command (`/coco.plan` or another `/coco.clarify`)

## Rules

- If no meaningful ambiguities found, report "No critical ambiguities detected" and suggest proceeding
- Never exceed 5 total questions
- Respect user early termination signals
- Never modify files except the spec (this is a clarification tool, not a rewrite tool)
