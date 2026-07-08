---
description: Read the project description and user stories, then derive a suggested database schema in DBML at .spec/init/database-schema.md
argument-hint: [optional focus area or extra context]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# init:database-schema

You are helping a developer turn a **project description** and its **user stories** into a **suggested database schema** written in **DBML** (Database Markup Language). This document is the third artifact of the project spec. It builds directly on the first two and becomes the reference the team uses to write migrations and models.

Optional focus or extra context from the developer (may be empty):

```
$ARGUMENTS
```

## Your goal

Read the existing project description and user stories, then produce a single document at **`.spec/init/database-schema.md`** that:

1. Models every **entity** implied by the core concepts and stories as a DBML `Table`.
2. Defines **columns** with concrete types, nullability, defaults, and uniqueness.
3. Declares **relationships** (foreign keys) and the **lookup tables** that back every categorical field.
4. Follows **Laravel 13 conventions** and the DB best practices below.

## Process

### 1. Read the source of truth first

Before asking anything, read **`.spec/init/project-description.md`** and **`.spec/init/user-stories.md`**. These are the inputs to this command.

- If either file is missing, stop and tell the developer to run `init:project-description` and/or `init:user-stories` first.
- Extract: the core concepts (the nouns → tables), the workflows and stories (the fields, states, and relationships), the user types (auth/roles), and any limits or numbers stated (→ column constraints).
- Also scan any other files already under `.spec/` for schema decisions already made, and inspect the project for an existing schema (`database/migrations/`, `composer.json` for the Laravel version, existing models) so you extend rather than contradict what's there.

Match the **language** of the project description for prose and comments (keep table/column identifiers in English, snake_case).

### 2. Interview to close gaps

Derive as much of the schema as you can directly from the docs, then find what's undefined. Ask the developer only about gaps that change the shape of the schema — do not interrogate on things the docs already answer. Focus on:

- **Cardinality** — one-to-many vs many-to-many; where a pivot table is needed.
- **Ownership & tenancy** — who owns a record; whether data is scoped per user/team/tenant.
- **Soft deletes vs hard deletes** — which entities need `deleted_at`.
- **Categorical fields** — every status/type/category/priority/role → which values seed the lookup table.
- **Uniqueness & required fields** — which columns are `unique`, which are `not null`.

Use `AskUserQuestion` for discrete decisions with clear options. Ask real open questions in plain text when the answer is not a menu. Batch related questions; don't drip one at a time. When something stays undecided, mark it as an open question rather than inventing a column.

### 3. Write the document

Write to `.spec/init/database-schema.md` (create the `.spec/init/` directories if missing). The file is Markdown that wraps a single DBML code block plus supporting notes. Use **exactly** this structure:

````markdown
# <Project Name> — Database Schema

## Overview

<1–2 paragraphs: the data model at a glance — the main entities and how they connect. Bold the key entities. Note the conventions in force (Laravel 13, lookup tables for enums, soft deletes where used).>

## Schema (DBML)

```dbml
// Lookup tables first, then domain tables, then pivots.

Table statuses {
  id bigint [pk, increment]
  name varchar [not null]
  slug varchar [unique, not null]
  description text [null]
  is_active boolean [not null, default: true]
  created_at timestamp
  updated_at timestamp
}

Table users {
  id bigint [pk, increment]
  name varchar [not null]
  email varchar [unique, not null]
  avatar_path varchar [null]
  status_id bigint [ref: > statuses.id, not null]
  created_at timestamp
  updated_at timestamp
  deleted_at timestamp [null]
}

// ... one Table per entity, one Table per lookup, pivots for many-to-many
```

## Relationships

<Bullet list summarizing each relationship in plain language: "A **user** has many **projects**", "A **project** belongs to one **status**", "**users** and **roles** are many-to-many via **role_user**". One line per relationship.>

## Lookup Table Seeds

<For each lookup table, list the initial rows that should be seeded (the values that would otherwise be enum cases). Table name → the concrete values.>

## Notes & Conventions

<Bullets calling out: tables using soft deletes, pivots, indexes worth adding, any denormalization, and anything traceable to a specific user story or limit.>
````

Rules for the document:

- **Title** = project name + `— Database Schema`.
- The DBML must be valid: every `ref` points at a real `table.column`; every foreign key column exists on its table.
- Keep every table traceable to a core concept, workflow, or story. No invented entities — if you need one to make a relationship work, note why.
- If gaps remain unresolved, add a short `## Open Questions` section at the end. Otherwise omit it.

## Guidelines for Laravel DB (mandatory)

### Naming & conventions

- Table names **plural, snake_case** (`projects`, `project_attachments`). Pivot names are the two singular table names **alphabetically ordered, snake_case** (`role_user`, not `user_role`).
- Every table has `id bigint [pk, increment]` unless it's a pivot with a composite key.
- Foreign keys are `<singular>_id` (`user_id`, `status_id`) typed `bigint`.
- Include `created_at` and `updated_at timestamp` on domain tables. Add `deleted_at timestamp [null]` where the entity uses soft deletes.

### Enums & Lookup Tables

- **Do not use enum DB fields or string-based enum columns.**
- For any field that represents a set of predefined values (status, type, category, priority, role, level, etc.), **always create a lookup/auxiliary table** with a foreign key relationship.
  - Instead of a `status` string/enum column, create a `statuses` table (`id`, `name`, …) and reference it as `status_id` (foreign key).
  - The lookup table includes `id`, `name`, and optionally `slug`, `description`, `is_active`, and timestamps as needed.
  - Applies to **all** categorical/enumerable fields: statuses, types, categories, priorities, levels, domain roles, etc.

### File / Image Uploads

- Store the file path as a **string column** directly in the table (e.g. `avatar_path`, `document_path`, `attachment_path`).
- Use a descriptive `_path` suffix to signal it holds a file path.
- If a record can have **multiple** files, create a related table (e.g. `project_attachments`) with a `file_path` string column and a foreign key to the parent.

### 4. Close out

After writing, report:

- The path written.
- A count of tables broken down as: domain tables, lookup tables, pivots.
- Any open questions still needing the developer's decision.
