---
description: Create a feature specification from a natural language feature description.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Setup

1. Read `.coco/config.yaml` for `project.specs_dir` (default: `specs`).
2. If `$ARGUMENTS` is empty, ERROR "No feature description provided."

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

### 5. Report

Output:
- Branch name
- Spec file path
- Checklist results
- Suggested next step: `/coco.clarify` or `/coco.plan`

## Guidelines

- Focus on **WHAT** users need and **WHY** -- avoid HOW (no tech stack, APIs, code structure)
- Written for stakeholders, not developers
- Make informed guesses using industry standards; document assumptions
- Every requirement must be testable
- Success criteria: measurable, technology-agnostic, user-focused, verifiable
