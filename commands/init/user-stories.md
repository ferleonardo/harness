---
description: Read the project description and derive structured, testable user stories at .spec/init/user-stories.md
argument-hint: [optional focus area or extra context]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# init:user-stories

You are helping a developer turn a **project description** into a set of **clear, testable user stories**. This document is the second artifact of the project spec. It builds directly on the project description and becomes the backlog the team plans and builds from.

Optional focus or extra context from the developer (may be empty):

```
$ARGUMENTS
```

## Your goal

Read the existing project description and produce a single document at **`.spec/init/user-stories.md`** that:

1. Identifies every **user type** (persona) the system serves.
2. Groups functionality into **feature areas**.
3. Writes **user stories** in the `As a / I want to / So that` form, each with concrete **acceptance criteria** and an **expected result**.
4. Assigns a **priority** to each story and tracks status in an appendix table.

## Process

### 1. Read the source of truth first

Before asking anything, read **`.spec/init/project-description.md`**. This is the input to this command.

- If the file is missing, stop and tell the developer to run `init:project-description` first.
- Extract from it: the user types, core concepts, core workflows, tech stack constraints, and the MVP boundary.
- Also scan any other files already under `.spec/` for decisions already made.

Match the **language** of the project description (write the stories in the same language the developer used).

### 2. Interview to close gaps

Derive as many stories as you can directly from the description, then find what's undefined. Ask the developer only about gaps that change the shape or scope of the stories — do not interrogate on things the description already answers. Focus on:

- **Persona boundaries** — who can do what; overlaps and permissions.
- **MVP vs deferred** — which stories are in the first version; what is explicitly out.
- **Priority** — which flows are must-have (High) vs nice-to-have (Medium/Low).
- **Acceptance edge cases** — limits, states, failure paths that make a story testable.
- **Missing flows** — anything implied by the concepts/workflows but not yet a story.

Use `AskUserQuestion` for discrete decisions with clear options (e.g. priority, in/out of MVP). Ask real open questions in plain text when the answer is not a menu. Batch related questions; don't drip one at a time. When something stays undecided, mark it as an open question rather than inventing an answer.

### 3. Write the document

Write to `.spec/init/user-stories.md` (create the `.spec/init/` directories if missing). Use **exactly** this structure:

```markdown
# <Project Name> — User Stories

## Overview

<1–2 paragraphs: what the product is and who it serves. Then a bullet list of user types.>

**User Types:**
- **<Persona>** - <one-line definition>
- ...

---

## 1. <Feature Area>

### US-1.1: <Short Story Title>
**As a** <persona>
**I want to** <capability>
**So that** <benefit>

**Acceptance Criteria:**
- [ ] <specific, testable condition>
- [ ] <specific, testable condition>
- [ ] ...

**Expected Result:** <the end state when the story is done>

---

### US-1.2: <Short Story Title>
...

## 2. <Feature Area>
...

## Appendix: User Story Status

| ID | Story | Priority | Status |
|----|-------|----------|--------|
| US-1.1 | <title> | High/Medium/Low | Pending |
| ... | ... | ... | ... |
```

Rules for the document:

- **Title** = project name + `— User Stories`.
- Number feature areas (`## 1.`, `## 2.` …) and stories within them (`US-1.1`, `US-1.2` …). Keep IDs stable.
- Every story uses the full `As a / I want to / So that` triple, an **Acceptance Criteria** checkbox list, and an **Expected Result** line.
- Acceptance criteria must be **concrete and testable** — state limits, states, and failure paths (e.g. "reset link valid for 60 minutes", "image max size 5MB"), not vague intent.
- Cover every user type and every core workflow from the project description. No invented features — keep each story traceable to the description or a developer decision.
- The **appendix table** lists every story with its priority and status (`Pending` by default). Order roughly by priority.
- If gaps remain unresolved, add a short `## Open Questions` section before the appendix. Otherwise omit it.

### 4. Close out

After writing, report:

- The path written.
- The count of stories and how many are High priority.
- Any open questions still needing the developer's decision.
