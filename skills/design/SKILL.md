---
name: design
description: Generate a feature design (design.md) in specs/{feature}/ with user stories, acceptance criteria, technical approach, API contracts, and research decisions.
---

# Coco Design Skill

Generate a feature design from a natural language description, combining specification (what to build) and implementation planning (how to build it) into a single artifact.

## When to Use

- Creating a feature design as part of the coco pipeline
- Called by `/coco:phase` (Step A) or `/coco:planning-session tactical`
- When a design.md is needed in `specs/{feature}/` before task generation

For single-issue fixes, use the `hotfix` skill instead.

## Setup

1. Read `.coco/config.yaml` for `project.specs_dir` (default: `specs`).
2. Determine the feature from conversation context:
   - If a feature name or description was provided in the current conversation, use it
   - If on a `feature/*` git branch, extract the feature name from the branch
   - If a spec directory was recently discussed, use that
   - If none of the above, ask the user for a feature description
3. Load `.coco/memory/constitution.md` if it exists.
4. Load the design template from `.coco/templates/design-template.md` if it exists, otherwise use `${CLAUDE_PLUGIN_ROOT}/templates/design-template.md`.
5. Load `{specs_dir}/{feature-name}/discovery.md` if it exists. When present, this discovery brief provides pre-validated user intent, scope decisions, and constraints gathered via the `interview` skill.

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
```
```bash
mkdir -p {specs_dir}/{feature-name}
```

The branch is `feature/{feature-name}` (e.g., `feature/user-auth`). The spec directory is `{specs_dir}/{feature-name}/` (without the prefix).

### 3. Generate Design Document

Fill the design template following this workflow:

**Specification phase** (WHAT and WHY):

1. Parse user description, extract key concepts (actors, actions, data, constraints). **When `discovery.md` exists**, use it as the primary source for actors, goals, scope, and constraints -- treat the discovery brief as pre-validated input.
2. For unclear aspects:
   - Make informed guesses based on context and industry standards
   - Only mark with `[NEEDS CLARIFICATION: specific question]` if the choice significantly impacts scope or UX and no reasonable default exists
   - **Maximum 3 markers total** (or **maximum 1 marker** when `discovery.md` exists, since most ambiguities should already be resolved), prioritized by: scope > security > UX > technical
3. Fill User Stories section with prioritized, independently testable user stories with BDD acceptance scenarios. **When `discovery.md` exists**, derive user stories from the User Intent and Scope sections.
4. Generate testable Functional Requirements (use reasonable defaults; document assumptions)
5. Define measurable, technology-agnostic Success Criteria
6. Identify Key Entities (if data involved)

**Technical planning phase** (HOW):

7. Fill Technical Approach section (language, dependencies, storage, testing, platform, project type, performance, constraints)
8. For each "NEEDS CLARIFICATION" in Technical Approach:
   - Research the unknown using web search or codebase exploration
   - Document findings in the Research & Decisions table (decision, rationale, alternatives)
9. Fill Project Structure section with the concrete source layout
10. Generate API Contracts section (if feature exposes APIs) -- inline endpoint contracts
11. Fill Constitution Check section from constitution (if exists)
    - Evaluate gates -- ERROR if violations are unjustified
    - Document any justified violations in the Complexity Tracking table

Write the design document to `{specs_dir}/{feature-name}/design.md`.

### 4. Generate Data Model (Conditional)

Only generate `data-model.md` if the feature involves significant data modeling (3+ entities with relationships, state transitions, or complex validation rules). Skip for UI-only features or simple CRUD.

If generated, extract from design.md Key Entities:
- Entity name, fields, relationships
- Validation rules from requirements
- State transitions if applicable

Write to `{specs_dir}/{feature-name}/data-model.md`.

### 5. Validate Design

Run inline validation against these criteria (no separate checklist file):

**Specification quality:**
- [ ] No implementation details leak into User Stories or Functional Requirements
- [ ] Focused on user value and business needs
- [ ] All mandatory sections completed
- [ ] No unresolved `[NEEDS CLARIFICATION]` markers remain (or max 3 critical ones)
- [ ] Requirements are testable and unambiguous
- [ ] Success criteria are measurable and technology-agnostic
- [ ] Edge cases identified

**Technical quality:**
- [ ] Technical Approach fields are all resolved (no remaining NEEDS CLARIFICATION)
- [ ] Project Structure matches the chosen project type
- [ ] API Contracts are complete (if applicable)
- [ ] Constitution gates pass (if constitution exists)

Fix issues (max 3 iterations). If `[NEEDS CLARIFICATION]` markers remain (max 3), present them to the user as a table with options and implications. Wait for responses, then update the design.

### 6. Clarification Pass (Optional)

After design generation, perform a structured ambiguity scan. **When `discovery.md` exists**, narrow the scan to categories NOT already covered in the discovery brief -- skip categories where the discovery brief provides clear, validated answers.

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

1. Ensure a `## Clarifications` section exists in the design (create after the overview section if missing)
2. Under `### Session YYYY-MM-DD`, append: `- Q: <question> -> A: <answer>`
3. Apply the clarification to the appropriate design section:
   - Functional -> update Functional Requirements
   - Data -> update Key Entities
   - Technical -> update Technical Approach or Research & Decisions
   - Non-functional -> add measurable criteria
   - Edge case -> add to Edge Cases
   - Terminology -> normalize across design
4. Replace any invalidated statements (don't leave contradictions)
5. Save the design file after each integration

### 7. Report

Output:
- Branch name
- Design file path
- Data model file path (if generated)
- Validation results
- Constitution compliance status (if applicable)
- Clarification summary (questions asked, sections updated) if clarification pass ran
- Suggested next step: tell the user to ask Claude to "generate the task list" (this triggers the `tasks` skill automatically -- skills are NOT slash commands, so never suggest `/coco:tasks`)

## Light Mode

When invoked for a **Light-tier** feature (1-3 files, single user story, no internal dependencies):

1. **Simplified design**: Generate a minimal design containing:
   - One-paragraph overview
   - Single user story
   - 3-5 acceptance criteria
   - No Technical Approach, API Contracts, Research & Decisions, Data Model, or Constitution Check sections
2. **Skip clarification pass** (Step 6) entirely
3. **Skip detailed validation** -- just verify the acceptance criteria are testable
4. **Suggest next step**: Tell the user to ask Claude to "import the design into the tracker" (this triggers the `import` skill automatically -- skills are NOT slash commands, so never suggest `/coco:import`)

Light mode is triggered by:
- `/coco:planning-session tactical` routing to Light tier
- `/coco:phase` classifying the feature as Light tier
- Explicit request for a "light" or "minimal" design

## Guidelines

- User Stories and Functional Requirements focus on **WHAT** users need and **WHY** -- avoid HOW (no tech stack, APIs, code structure in those sections)
- Technical Approach, API Contracts, and Project Structure focus on **HOW** -- informed by the spec sections
- Make informed guesses using industry standards; document assumptions
- Every requirement must be testable
- Success criteria: measurable, technology-agnostic, user-focused, verifiable
- Use absolute paths throughout
- ERROR on gate failures or unresolved clarifications in Technical Approach
- Do NOT generate tasks.md -- that is the `tasks` skill
- Never modify files outside the feature's spec directory
