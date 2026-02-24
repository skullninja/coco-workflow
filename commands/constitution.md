---
description: Create or update the project constitution defining non-negotiable development principles.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Create or update the project constitution at `.coco/memory/constitution.md`. The constitution defines non-negotiable principles that govern specification, planning, and task generation.

## Setup

1. Check if `.coco/memory/constitution.md` exists.
   - If yes: load it for amendment
   - If no: load the template from `.coco/templates/constitution-template.md` if it exists, otherwise use `${CLAUDE_PLUGIN_ROOT}/templates/constitution-template.md`

## Execution

### 1. Collect Principles

If user input provides principles, use them. Otherwise:
- Infer from existing repo context (README, docs, CLAUDE.md, existing config)
- Ask the user interactively about their project's core principles using categories:
  - Technology choices (language, framework, platform APIs)
  - Testing requirements (TDD, coverage thresholds)
  - Performance requirements (benchmarks, latency targets)
  - Architecture patterns (data layer, service layer)
  - Code quality standards
  - Security/accessibility requirements
- The user might need fewer or more principles than the template provides. Respect their choice.

### 2. Draft Constitution

Replace all placeholder tokens with concrete text:
- Each principle: name, non-negotiable rules (MUST/SHOULD), rationale
- Governance: amendment procedure, versioning, compliance review
- Definition of Done criteria aligned with principles
- Version following semantic versioning:
  - MAJOR: Principle removals or redefinitions
  - MINOR: New principle added or materially expanded
  - PATCH: Clarifications, wording fixes

### 3. Consistency Propagation

Check that dependent files align with the new constitution:
- `.coco/templates/design-template.md` or `${CLAUDE_PLUGIN_ROOT}/templates/design-template.md` -- Constitution Check section + scope alignment
- `.coco/templates/tasks-template.md` or `${CLAUDE_PLUGIN_ROOT}/templates/tasks-template.md` -- task categorization

Note: Only modify files in `.coco/templates/` (project overrides). Never modify plugin root templates.

### 4. Write Constitution

Write to `.coco/memory/constitution.md`.

Prepend a Sync Impact Report as an HTML comment:
```html
<!--
Sync Impact Report:
Version: old -> new
Principles Defined: [list]
Templates Status: [check/pending per template]
Follow-up TODOs: [if any]
-->
```

### 5. Report

Output:
- New version and bump rationale
- Files flagged for manual follow-up
- Suggested commit message

## Rules

- No remaining unexplained bracket tokens
- Dates in ISO format (YYYY-MM-DD)
- Principles must be declarative, testable, and use MUST/SHOULD language
- If critical info is unknown, insert `TODO(<field>): explanation` and flag in report
