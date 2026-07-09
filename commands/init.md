---
description: Show the status of the init spec chain (.spec/init/*) — present, absent, or stale — and point at the next init:* command to run. Diagnostic only; writes nothing.
allowed-tools: Read, Bash, Glob, Grep
---

# init

You are the router for the init spec chain. You inspect the state of the artifacts, report it, and point the developer at the next command to run. You never write or edit any artifact — all authoring lives in the `init:*` commands.

## The chain

| # | Artifact | Produced by | Inputs (stamped on line 3) |
|---|---|---|---|
| 1 | `.spec/init/project-description.md` | `/init:project-description` | — (head of chain, no stamp) |
| 2 | `.spec/init/user-stories.md` | `/init:user-stories` | project-description.md |
| 3 | `.spec/init/database-schema.md` | `/init:database-schema` | project-description.md, user-stories.md |
| 4 | `.spec/init/project-phases.md` | `/init:project-phases` | project-description.md, user-stories.md, database-schema.md |
| — | `.spec/init/design/` | developer (manual) | — |

`.spec/init/design/` is always a **manual artifact**: the developer creates and populates it; no `init:*` command writes there. Its absence is never an error. `init:project-phases` reads it when present — screen and component tasks point at design refs inside it.

## Flow

### 1 — Presence

```bash
for f in project-description user-stories database-schema project-phases; do
  test -f ".spec/init/$f.md" && echo "present: $f.md" || echo "absent: $f.md"
done
test -d .spec/init/design && echo "present: design/" || echo "absent: design/"
```

### 2 — Freshness

Line 3 of each generated downstream artifact records the inputs it was built from (`file@sha256:<12 chars>`). Recompute and compare:

```bash
# prints nothing when the whole chain is fresh; any output = an input changed after that artifact was generated
for doc in user-stories database-schema project-phases; do
  [ -f ".spec/init/$doc.md" ] || continue
  for pair in $(sed -n '3p' ".spec/init/$doc.md" | grep -oE '[a-z0-9.-]+\.md@sha256:[0-9a-f]{12}'); do
    [ "$(sha256sum ".spec/init/${pair%%@*}" | cut -c1-12)" = "${pair##*:}" ] \
      || echo "stale: $doc.md predates current ${pair%%@*}"
  done
done
```

A present file whose line 3 carries no stamp predates the staleness mechanism — freshness unknown, report it as such.

### 3 — Report

Emit one table:

| Artifact | Status |
|---|---|
| `.spec/init/project-description.md` | `present` / `absent` |
| `.spec/init/user-stories.md` | `present` / `absent` / `stale (<input> changed)` / `present (no stamp)` |
| `.spec/init/database-schema.md` | same |
| `.spec/init/project-phases.md` | same |
| `.spec/init/design/` | `present (manual)` / `absent (optional)` |

After the table, quote any `stale:` lines from step 2 verbatim.

### 4 — Next step

Recommend exactly one action — first rule that matches wins:

1. **An artifact is absent** → run the command of the first absent artifact in chain order (1 → 4). Earlier artifacts must exist before later ones make sense.
2. **An artifact is stale** → re-run the command of the first stale artifact in chain order. Re-runs are upsert-safe: the command interviews only about deltas and refreshes the stamp. Note that regenerating it may in turn mark artifacts downstream of it stale — re-check with `/init` afterwards.
3. **All present and fresh** → `Chain complete and fresh — nothing to do.` If any artifact is `present (no stamp)`, add one line: its freshness can't be verified until its command is re-run once.

## Rules

- **Diagnostic only** — never Write or Edit; this command produces no artifact and changes no file.
- **Never block, never nag** — staleness is a warning and a recommendation, not an error. The developer decides.
- **Thin router** — no template or interview content in this file; the `init:*` commands own all of it.
- **No git writes** — never stage, commit, or reset.
