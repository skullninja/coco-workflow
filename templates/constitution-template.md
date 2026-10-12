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

<!--
  Every principle needs a **Bounds** line as well as a MUST and a Rationale.

  A principle shaped only as MUST + Rationale can require and can never limit,
  so principles accumulate as one-directional ratchets. That is not theoretical:
  a principle reading "cover the states, not just the happy path: [six states]
  each need a case" is an unbounded multiplier -- N states x M behaviours, no
  ceiling -- and combined with a verification gate it produced a suite with more
  test code than product code. Its author's reaction on being shown the
  arithmetic was that the density "was not the intent." The document produced an
  outcome nobody chose, because its form had nowhere to say "and this much is
  too much."

  Bounds is where the cost goes. "Test-first for domain logic, bounded by the
  per-feature count in each design's Test Strategy." "Adversarial review for
  algorithmic paths, one round for UI, none for docs." A principle whose Bounds
  line reads "none" is a deliberate choice; a principle with no Bounds line is
  an oversight.
-->


### I. [First Principle Name]

**MUST** [describe the non-negotiable requirement]:
- [Specific rule or guideline]
- [Specific rule or guideline]
- [Specific rule or guideline]

**Bounds**: [What too much of this looks like, and what it is willing to pay]

**Rationale**: [Why this principle matters for the project]

---

### II. [Second Principle Name]

**MUST** [describe the non-negotiable requirement]:
- [Specific rule or guideline]
- [Specific rule or guideline]

**Bounds**: [What too much of this looks like, and what it is willing to pay]

**Rationale**: [Why this principle matters for the project]

---

### III. [Third Principle Name]

**MUST** [describe the non-negotiable requirement]:
- [Specific rule or guideline]
- [Specific rule or guideline]

**Bounds**: [What too much of this looks like, and what it is willing to pay]

**Rationale**: [Why this principle matters for the project]

---

<!--
  Common principle categories to consider:

  - Technology choices (language version, framework, platform APIs)
  - Testing requirements (TDD, coverage thresholds, testing pyramid)

    A testing principle should bind in BOTH directions, or it only ever
    ratchets the suite upward. For example:

      ### N. Tests Defend Behavior

      Every test MUST defend a named failure mode of a stated requirement.
      Tests that assert implementation detail, restate a mock, or duplicate
      coverage already provided at a cheaper level MUST be deleted rather
      than maintained. Deleting a test that defends nothing is not a
      reduction in quality -- it is a reduction in cost.

      Rationale: an unjustified test is not free. It costs review time, CI
      time, and blocks every future refactor that would otherwise be safe.

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
2. Tests written and passing (per testing principle and the feature's Test Strategy)
3. Code coverage meets threshold (if defined), and no test was added solely to reach it
4. No new warnings or errors
5. Documentation updated (if user-facing)

**Customize this list based on your project's principles above.**

### Code Review Requirements

**Every pull request MUST**:
- Pass all tests
- Meet code coverage threshold (if defined)
- Add no test that does not defend a named failure mode
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
