# Tasks: [FEATURE NAME]

**Input**: Design documents from `specs/[feature-name]/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Test tasks are OPTIONAL - only include them if explicitly requested in the feature specification.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root
- **Web app**: `backend/src/`, `frontend/src/`
- **Mobile**: `api/src/`, `ios/src/` or `android/src/`
- Paths shown below assume single project - adjust based on plan.md structure

<!--
  IMPORTANT: The tasks below are SAMPLE TASKS for illustration purposes only.

  The tasks skill MUST replace these with actual tasks based on:
  - User stories from spec.md (with their priorities P1, P2, P3...)
  - Feature requirements from plan.md
  - Entities from data-model.md
  - Endpoints from contracts/

  Tasks MUST be organized by user story so each story can be:
  - Implemented independently
  - Tested independently
  - Delivered as an MVP increment

  DO NOT keep these sample tasks in the generated tasks.md file.
-->

## Sub-Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

**Acceptance Criteria:**
- [ ] Project compiles with zero errors

- [ ] T001 Create project structure per implementation plan
- [ ] T002 Initialize project with dependencies
- [ ] T003 [P] Configure linting and formatting tools

---

## Sub-Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this sub-phase is complete

**Acceptance Criteria:**
- [ ] All base models compile and can be instantiated in tests

- [ ] T004 Setup database schema and migrations framework
- [ ] T005 [P] Implement authentication/authorization framework
- [ ] T006 [P] Setup API routing and middleware structure
- [ ] T007 Create base models/entities that all stories depend on
- [ ] T008 Configure error handling and logging infrastructure

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Sub-Phase 3: User Story 1 - [Title] (Priority: P1) MVP

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

**Acceptance Criteria:**
- [ ] [Specific testable outcome 1]
- [ ] [Specific testable outcome 2]

### Tests for User Story 1 (OPTIONAL - only if tests requested)

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T010 [P] [US1] Contract test for [endpoint] in tests/contract/test_[name]
- [ ] T011 [P] [US1] Integration test for [user journey] in tests/integration/test_[name]

### Implementation for User Story 1

- [ ] T012 [P] [US1] Create [Entity1] model in src/models/[entity1]
- [ ] T013 [P] [US1] Create [Entity2] model in src/models/[entity2]
- [ ] T014 [US1] Implement [Service] in src/services/[service] (depends on T012, T013)
- [ ] T015 [US1] Implement [endpoint/feature] in src/[location]/[file]

**Checkpoint**: User Story 1 should be fully functional and testable independently

---

## Sub-Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

**Acceptance Criteria:**
- [ ] [Specific testable outcome 1]
- [ ] [Specific testable outcome 2]

### Tests for User Story 2 (OPTIONAL - only if tests requested)

- [ ] T018 [P] [US2] Contract test for [endpoint]
- [ ] T019 [P] [US2] Integration test for [user journey]

### Implementation for User Story 2

- [ ] T020 [P] [US2] Create [Entity] model in src/models/[entity]
- [ ] T021 [US2] Implement [Service] in src/services/[service]
- [ ] T022 [US2] Implement [endpoint/feature] in src/[location]/[file]

**Checkpoint**: User Stories 1 AND 2 should both work independently

---

[Add more user story sub-phases as needed, following the same pattern]

---

## Sub-Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] TXXX [P] Documentation updates
- [ ] TXXX Code cleanup and refactoring
- [ ] TXXX Performance optimization
- [ ] TXXX [P] Additional tests (if requested)
- [ ] TXXX Run quickstart.md validation

---

## Dependencies & Execution Order

### Sub-Phase Dependencies

- **Setup (Sub-Phase 1)**: No dependencies - can start immediately
- **Foundational (Sub-Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Sub-Phase 3+)**: All depend on Foundational sub-phase completion
  - User stories can proceed in parallel (if staffed) or sequentially by priority
- **Polish (Final Sub-Phase)**: Depends on all desired user stories being complete

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Models before services
- Services before endpoints
- Core implementation before integration

### Parallel Opportunities

- All tasks marked [P] can run in parallel within their sub-phase
- Once Foundational sub-phase completes, all user stories can start in parallel
- Different user stories can be worked on by different agents/team members

---

## Parallel Execution Map

### Dependency Graph

```
Sub-Phase 1: Setup ---------> Sub-Phase 2: Foundational
                                         |
                           +-------------+-------------+
                           v             v             v
                     SP 3: US1     SP 4: US2     SP 5: US3
                           |             |             |
                           +-------------+-------------+
                                         v
                                 Sub-Phase N: Polish
```

### File Ownership per Sub-Phase

| Sub-Phase | Creates/Modifies | Conflict Risk |
|-----------|-----------------|---------------|
| Setup | Project structure, config | Low (one-time) |
| Foundational | Base models, shared services | High (shared deps) |
| US1 | [US1-specific files] | Low (independent) |
| US2 | [US2-specific files] | Low (independent) |
| Polish | Cross-cutting, shared | High (touches many) |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
