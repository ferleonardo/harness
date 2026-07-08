---
description: Read the project description, user stories, database schema, and any design specs, then plan the build into numbered, agent-ready phases with tasks, acceptance criteria, and feature tests at .spec/init/project-phases.md
argument-hint: [optional focus area or extra context]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# init:project-phases

**ultrathink.** This is a high-stakes planning task: the document you produce is fed to AI agents that build the whole project from it. Engage your maximum reasoning budget. Do not rush. Precision, completeness, and faithful coverage of every source document matter more than brevity.

You are helping a developer turn the project spec into a **complete, phased implementation plan**. This document is the fourth artifact of the project spec. It builds on the first three (and any design specs) and becomes the ordered backlog AI agents implement, phase by phase, referenced by number.

Optional focus or extra context from the developer (may be empty):

```
$ARGUMENTS
```

## Your goal

Read the existing spec and produce a single document at **`.spec/init/project-phases.md`** that:

1. Breaks the entire build into **numbered phases and sub-phases** (`Phase 1`, `Phase 5.3`, …) that can be referenced by number when later handed to an AI agent.
2. Lists **every task** required to implement everything in the project description, user stories, and database schema — nothing implied by the spec is left unplanned.
3. Gives each task concrete **acceptance criteria** and, where the task carries business logic, the **automated feature tests** to be generated as its acceptance gate.
4. Marks tasks **already completed in the codebase** as `[x]`.
5. Orders the work **foundation-first**, then feature flows.

## Process

### 1. Read the sources of truth first

Before asking anything, read the inputs in this order:

- **`.spec/init/project-description.md`** — scope, tech stack, core workflows.
- **`.spec/init/user-stories.md`** — the stories, acceptance criteria, priorities.
- **`.spec/init/database-schema.md`** — every table, lookup, pivot, relationship.
- **`.spec/init/design/`** — if this directory exists, it holds the **UI/design specs** (mockups, screen definitions, component references, images). Read it. Every task that builds a screen or component **must** point at its design reference, and its implementation must be **faithful to the proposed design**.

If any of the first three files is missing, stop and tell the developer to run the missing `init:*` command first. Match the **language** of the project description for all prose.

### 2. Inspect the codebase to detect what is already done

Scan the project so you can mark completed work:

- Migrations (`database/migrations/`), models (`app/Models/`), seeders/factories.
- Frontend components, pages/screens, routes.
- Existing tests (`tests/`), controllers, services, form requests, policies.

For each task you define, check whether the code already satisfies it. If it does, mark it `[x]`; otherwise `[ ]`. When partially done, mark `[ ]` and note in the task what remains.

### 3. Interview to close gaps

Derive as much of the plan as you can directly from the docs, then ask the developer only about gaps that change the **shape, ordering, or sizing** of phases — do not interrogate on things the docs already answer. Focus on:

- **Phase priorities / ordering** — which feature flows come first after the foundation.
- **MVP cut line** — which phases are in the first release vs deferred.
- **Ambiguous scope** — flows implied but not fully specified in the stories.
- **Design coverage** — screens with no design reference: build to a sensible default, or wait for design?

Use `AskUserQuestion` for discrete decisions with clear options. Ask real open questions in plain text when the answer is not a menu. Batch related questions; don't drip one at a time. When something stays undecided, mark it as an open question rather than inventing scope.

## Rules for phasing

### Foundation first, always

Order the phases so that **foundation work precedes feature flows**. The early phases build the base the rest stands on:

1. **Database foundation** — all migrations and lookup-table seeders from the schema.
2. **Models & relationships** — every model, with **all relationships wired up front** (belongsTo, hasMany, belongsToMany, etc.), casts, fillables, soft deletes. Do not defer relationships to later feature phases — the models come out of the foundation phase relationship-complete.
3. **Frontend foundation** — the base UI: design-system components, layout, shared/reusable components referenced by the design specs.

Only **after** the foundation is in place do the phases start implementing the **project flows** (auth, then each feature area / core workflow, feature by feature).

### Phase sizing (optimal work window)

Size each phase so a single **Opus 4.6** agent can implement it within its **optimal working window** — big enough to be a coherent, shippable slice, small enough to fit comfortably in one focused context without overflow.

- **Sub-phases count toward their parent phase's window.** A parent phase plus all its sub-phases together must still fit one optimal working window. If the total grows too large, split it into more top-level phases instead of overloading one parent.
- Prefer more, well-scoped phases over a few oversized ones. **Any number of phases is fine** as long as each is detailed enough to implement everything in the description, stories, and schema with high quality and precision.
- Keep each phase independently implementable and, where possible, independently verifiable.

### Numbering

- Top-level phases: `Phase 1`, `Phase 2`, … Sub-phases: `Phase 5.1`, `Phase 5.2`, `Phase 5.3`, … so any unit can be referenced by number when handed to an agent.
- Keep numbers **stable**; don't renumber existing phases when adding new ones.

### Tasks, tests, and acceptance criteria

- Every task has **acceptance criteria** — concrete, validatable conditions (states, limits, failure paths), not vague intent.
- **Business-logic tasks** (rules, calculations, state transitions, permissions, validations, workflows) **must** specify the **automated feature tests** to generate. Tests **primarily assert business rules** — the limits, states, and edge cases from the stories and schema.
- **Frontend-only tasks** (building a screen/component with no business logic) **do not require tests**, but **must** have acceptance criteria that can be validated (matches design reference, renders required elements/states, responsive/interaction behavior), plus a **Design ref** pointing at the relevant `.spec/init/design/` artifact.
- Keep every task traceable to a story (`US-x.y`), a schema table, a workflow, or a design artifact. No invented scope.

### 4. Write the document

Write to `.spec/init/project-phases.md` (create the `.spec/init/` directories if missing). Use **exactly** this structure:

````markdown
# <Project Name> — Project Phases

## Overview

<1–2 paragraphs: the build strategy at a glance — foundation-first, then feature flows. Note how many phases, the MVP cut line, and that phases are referenced by number when handed to agents.>

**Conventions:**
- `[ ]` pending · `[x]` done in the codebase.
- Phases and sub-phases are numbered (`Phase 1`, `Phase 5.3`) for reference by AI agents.
- Business-logic tasks list the **feature tests** to generate; frontend-only tasks list validatable **acceptance criteria** and a **Design ref**.

---

## Phase 1: <Foundation — Name>

**Goal:** <one line.> · **Depends on:** <none / Phase N> · **Covers:** <stories/tables/workflows>

### Phase 1.1: <Sub-phase name>

- [ ] **Task:** <what to build>
  - **Acceptance criteria:**
    - <concrete, validatable condition>
    - ...
  - **Feature tests:** <test name → what business rule it asserts> *(omit for frontend-only tasks)*
  - **Design ref:** <path under .spec/init/design/> *(only for screen/component tasks)*
  - **Traces:** <US-x.y / table / workflow>

- [x] **Task:** <already implemented in the codebase>
  - ...

### Phase 1.2: <Sub-phase name>
...

---

## Phase 2: <Name>
...

## Open Questions

<Only if gaps remain — bullets of undecided scope/ordering. Otherwise omit this section.>
````

Rules for the document:

- **Title** = project name + `— Project Phases`.
- Foundation phases come first; models are relationship-complete out of the foundation.
- Every phase (parent + its sub-phases) fits one Opus 4.6 optimal working window.
- Every task is traceable; every business-logic task has feature tests; every screen task has a design ref (or an open question if design is missing).
- Cover **everything** in the description, stories, and schema. Completeness beats brevity.

### 5. Close out

After writing, report:

- The path written.
- Phase count, task count, and how many tasks are already `[x]`.
- The MVP cut line (which phase completes the first release).
- Any open questions still needing the developer's decision.
