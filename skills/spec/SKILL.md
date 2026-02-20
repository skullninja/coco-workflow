---
name: coco-spec
description: Generate a coco-workflow feature specification (spec.md) in specs/{feature}/ with user stories, acceptance criteria, and clarification of ambiguities.
---

# Coco Spec Skill

Generate a feature specification from a natural language description, with optional ambiguity resolution.

## When to Use

- Creating a new feature specification as part of the coco-workflow pipeline
- Called by `/coco.phase` (Step A) or `/planning-session tactical`
- When a spec.md is needed in `specs/{feature}/` before planning can begin

For single-issue fixes, use the `coco-hotfix` skill instead.

## Setup

1. Read `.coco/config.yaml` for `project.specs_dir` (default: `specs`).
2. Determine the feature from conversation context:
   - If a feature name or description was provided in the current conversation, use it
   - If on a `feature/*` git branch, extract the feature name from the branch
   - If a spec directory was recently discussed, use that
   - If none of the above, ask the user for a feature description

## Execution

### 1. Generate Feature Identity

- Analyze the description and generate a 2-4 word short name (e.g., "user-auth", "analytics-dashboard")
- Use action-noun format when possible; preserve technical terms
- Determine the feature directory: `{specs_dir}/{feature-name}/`
- If a directory with this name already exists, append a numeric suffix

### 2. Create Feature Branch & Directory

Read `pr.branch.feature_prefix` from `.coco/config.yaml` (default: `feature`).

```bash
git checkout -b {feature_prefix}/{feature-name}
mkdir -p {specs_dir}/{feature-name}/checklists
```

The branch is `feature/{feature-name}` (e.g., `feature/user-auth`). The spec directory is `{specs_dir}/{feature-name}/` (without the prefix).

### 3. Generate Specification

Load the spec template from `.coco/templates/spec-template.md` if it exists, otherwise use `${CLAUDE_PLUGIN_ROOT}/templates/spec-template.md`.

Follow this workflow:

1. Parse user description, extract key concepts (actors, actions, data, constraints)
2. For unclear aspects:
   - Make informed guesses based on context and industry standards
   - Only mark with `[NEEDS CLARIFICATION: specific question]` if the choice significantly impacts scope or UX and no reasonable default exists
   - **Maximum 3 markers total**, prioritized by: scope > security > UX > technical
3. Fill User Scenarios & Testing section with prioritized, independently testable user stories
4. Generate testable Functional Requirements (use reasonable defaults; document assumptions)
5. Define measurable, technology-agnostic Success Criteria
6. Identify Key Entities (if data involved)

Write the specification to `{specs_dir}/{feature-name}/spec.md`.

### 4. Validate Specification

Create a checklist at `{specs_dir}/{feature-name}/checklists/requirements.md`:

```markdown
# Specification Quality Checklist: [FEATURE NAME]

**Created**: [DATE] | **Feature**: [Link to spec.md]

## Content Quality
- [ ] No implementation details (languages, frameworks, APIs)
- [ ] Focused on user value and business needs
- [ ] All mandatory sections completed

## Requirement Completeness
- [ ] No [NEEDS CLARIFICATION] markers remain (or max 3 critical ones presented to user)
- [ ] Requirements are testable and unambiguous
- [ ] Success criteria are measurable and technology-agnostic
- [ ] Edge cases identified
- [ ] Scope clearly bounded
```

Run validation against each item. Fix issues (max 3 iterations).

If `[NEEDS CLARIFICATION]` markers remain (max 3), present them to the user as a table with options and implications. Wait for responses, then update the spec.

### 5. Clarification Pass (Optional)

After spec generation, perform a structured ambiguity scan. This step absorbs the logic previously in `/coco.clarify`.

**Ambiguity Scan**: Check coverage across these categories, marking each as Clear / Partial / Missing:

- **Functional Scope**: Core user goals, success criteria, explicit out-of-scope
- **Domain & Data Model**: Entities, attributes, relationships, state transitions, scale
- **Interaction & UX Flow**: Critical journeys, error/empty/loading states
- **Non-Functional Quality**: Performance, scalability, reliability, security, compliance
- **Integration**: External services/APIs, data formats, failure modes
- **Edge Cases**: Negative scenarios, rate limiting, conflict resolution
- **Constraints & Tradeoffs**: Technical constraints, rejected alternatives
- **Terminology**: Canonical terms, consistency
- **Completion Signals**: Acceptance criteria testability, Definition of Done

**If no meaningful ambiguities found**: Report "No critical ambiguities detected" and skip to Report.

**If Partial/Missing categories found**: Present up to 5 sequential clarification questions:

- **Multiple-choice**: Recommend the best option prominently with reasoning, then present all options in a table. Include "Short answer" option if appropriate.
- **Short-answer**: Provide a suggested answer with reasoning. Constrain to <=5 words.
- Accept "yes" / "recommended" / "suggested" to use your recommendation.
- Stop when: all critical ambiguities resolved, user says "done", or 5 questions asked.
- Prioritize by `Impact * Uncertainty`. Cover highest-impact unresolved categories first.

**Integrate Answers**: After each accepted answer:

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

### 6. Report

Output:
- Branch name
- Spec file path
- Checklist results
- Clarification summary (questions asked, sections updated) if clarification pass ran
- Suggested next step: use the `coco-plan` skill to generate the implementation plan

## Light Mode

When invoked for a **Light-tier** feature (1-3 files, single user story, no internal dependencies):

1. **Simplified spec**: Generate a minimal spec containing:
   - One-paragraph overview
   - Single user story
   - 3-5 acceptance criteria
   - No sub-phases, no dependency graph, no key entities section
2. **Skip clarification pass** (Step 5) entirely
3. **Skip detailed checklist** -- just verify the acceptance criteria are testable
4. **Suggest next step**: Use the `coco-import` skill in spec-only mode (skipping plan and tasks)

Light mode is triggered by:
- `/planning-session tactical` routing to Light tier
- `/coco.phase` classifying the feature as Light tier
- Explicit request for a "light" or "minimal" spec

## Guidelines

- Focus on **WHAT** users need and **WHY** -- avoid HOW (no tech stack, APIs, code structure)
- Written for stakeholders, not developers
- Make informed guesses using industry standards; document assumptions
- Every requirement must be testable
- Success criteria: measurable, technology-agnostic, user-focused, verifiable
- Never modify files except the spec and checklist
