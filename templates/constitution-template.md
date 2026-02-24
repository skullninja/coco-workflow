# Project Constitution

<!--
  This constitution defines the non-negotiable principles for your project.
  Use /coco:constitution to customize it for your project.

  Instructions:
  - Replace the example principles below with your project's actual principles
  - Each principle should have a clear rationale
  - Keep the governance section as-is (it's generic)
  - Aim for 3-6 core principles (too many dilutes focus)
-->

## Core Principles

### I. [First Principle Name]

**MUST** [describe the non-negotiable requirement]:
- [Specific rule or guideline]
- [Specific rule or guideline]
- [Specific rule or guideline]

**Rationale**: [Why this principle matters for the project]

---

### II. [Second Principle Name]

**MUST** [describe the non-negotiable requirement]:
- [Specific rule or guideline]
- [Specific rule or guideline]

**Rationale**: [Why this principle matters for the project]

---

### III. [Third Principle Name]

**MUST** [describe the non-negotiable requirement]:
- [Specific rule or guideline]
- [Specific rule or guideline]

**Rationale**: [Why this principle matters for the project]

---

<!--
  Common principle categories to consider:

  - Technology choices (language version, framework, platform APIs)
  - Testing requirements (TDD, coverage thresholds, testing pyramid)
  - Performance requirements (benchmarks, latency targets, memory limits)
  - Architecture patterns (data layer, service layer, dependency rules)
  - Code quality (linting, formatting, documentation standards)
  - Security requirements (auth, input validation, data handling)
  - Accessibility requirements (WCAG level, screen reader support)
  - Deployment practices (CI/CD, environment management, rollback)
-->

## Development Workflow

### Definition of Done

A feature is **DONE** when all criteria are met:

1. Code written and compiles without errors
2. Tests written and passing (per testing principle)
3. Code coverage meets threshold (if defined)
4. No new warnings or errors
5. Documentation updated (if user-facing)

**Customize this list based on your project's principles above.**

### Code Review Requirements

**Every pull request MUST**:
- Pass all tests
- Meet code coverage threshold (if defined)
- Pass linting checks (if configured)
- Verify constitution compliance

## Governance

### Constitution Authority

This constitution supersedes all other development practices. When conflicts arise, constitution principles take precedence.

### Amendment Process

**Amendments require**:
1. Documented rationale for change
2. Impact analysis on existing code and workflows
3. Update to affected templates
4. Migration plan for existing features (if breaking)
5. Version bump following semantic versioning

### Compliance Review

**Constitution compliance MUST be verified**:
- At design creation (design.md Constitution Check section)
- At code review (PR checklist)

### Versioning Policy

**Semantic versioning for constitution**:
- **MAJOR**: Backward incompatible governance/principle removals or redefinitions
- **MINOR**: New principle/section added or materially expanded guidance
- **PATCH**: Clarifications, wording, typo fixes, non-semantic refinements

**Version**: 0.1.0 | **Ratified**: [DATE] | **Last Amended**: [DATE]
