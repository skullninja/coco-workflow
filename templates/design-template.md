# Feature Design: [FEATURE NAME]

**Feature Branch**: `[feature-name]`
**Created**: [DATE]
**Status**: Draft
**Input**: User description: "$ARGUMENTS"

## User Stories *(mandatory)*

<!--
  User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement
  just ONE of them, you should still have a viable MVP that delivers value.

  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
-->

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

- What happens when [boundary condition]?
- How does system handle [error scenario]?

## Functional Requirements *(mandatory)*

- **FR-001**: System MUST [specific capability]
- **FR-002**: System MUST [specific capability]
- **FR-003**: Users MUST be able to [key interaction]

*Mark unclear requirements:*

- **FR-00N**: System MUST [NEEDS CLARIFICATION: detail not specified]

### Key Entities *(include if feature involves data)*

- **[Entity 1]**: [What it represents, key attributes without implementation]
- **[Entity 2]**: [What it represents, relationships to other entities]

## Technical Approach

<!--
  Replace with the technical details for the project.
-->

**Language/Version**: [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION]
**Primary Dependencies**: [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION]
**Storage**: [if applicable, e.g., PostgreSQL, CoreData, files or N/A]
**Testing**: [e.g., pytest, XCTest, cargo test or NEEDS CLARIFICATION]
**Target Platform**: [e.g., Linux server, iOS 15+, WASM or NEEDS CLARIFICATION]
**Project Type**: [single/web/mobile - determines source structure]
**Performance Goals**: [domain-specific or NEEDS CLARIFICATION]
**Constraints**: [domain-specific or NEEDS CLARIFICATION]

### Project Structure

<!--
  Replace the placeholder tree below with the concrete layout for this feature.
  Delete unused options and expand the chosen structure with real paths.
-->

```text
# Option 1: Single project (DEFAULT)
src/
  models/
  services/
  cli/
  lib/

tests/
  contract/
  integration/
  unit/

# Option 2: Web application
backend/
  src/
    models/
    services/
    api/
  tests/

frontend/
  src/
    components/
    pages/
    services/
  tests/

# Option 3: Mobile + API
api/
  [same as backend above]

ios/ or android/
  [platform-specific structure]
```

**Structure Decision**: [Document the selected structure and reference the real directories]

## API Contracts *(include if feature exposes APIs)*

<!--
  Document each endpoint or service interface inline.
  Replace this section with actual endpoint contracts.
-->

### `[METHOD] /api/[resource]`

**Purpose**: [What this endpoint does]
**Request**: [Body/params schema]
**Response**: [Response schema]
**Errors**: [Error codes and meanings]

## Research & Decisions

<!--
  Document resolved NEEDS CLARIFICATION items here.
  If no research was needed, remove this section.
-->

| Topic | Decision | Rationale | Alternatives Considered |
|-------|----------|-----------|------------------------|
| [e.g., Auth approach] | [chosen approach] | [why] | [what else was evaluated] |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: [Measurable metric, e.g., "Users can complete task in under 2 minutes"]
- **SC-002**: [Measurable metric, e.g., "System handles expected load without degradation"]
- **SC-003**: [User satisfaction metric, e.g., "90% of users complete primary task on first attempt"]

## Constitution Check

*GATE: Must pass before implementation. Re-check after design completion.*

[Gates determined based on constitution file at `.coco/memory/constitution.md`]

### Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., extra dependency] | [current need] | [why simpler approach insufficient] |
