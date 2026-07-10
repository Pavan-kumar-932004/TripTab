---
trigger: always_on
---

# Workspace Rules — Trip Expense Ledger

> These are always-loaded, passive instructions. Follow them on every
> task in this workspace without needing to be reminded. If a request
> conflicts with a rule here, flag the conflict explicitly rather than
> silently picking one side.

## Before doing anything

1. Read `PROJECT_BRIEF.md`, `docs/ARCHITECTURE.md`,
   `docs/DATA_MODEL.md`, `docs/DECISIONS_AND_GOTCHAS.md`, and
   `docs/ROADMAP.md` if you have not already read them in this session.
2. Check `docs/ROADMAP.md` for which phase is currently active. Do not
   implement a later phase's scope while an earlier phase is
   incomplete, even if it seems easy to do while you're already in the
   relevant code.

## Non-negotiable technical rules

- **Money is always `bigint` minor units (paise).** Never `numeric`,
  `decimal`, `float`, or `double` for any monetary value, anywhere.
- **Every new table gets Row-Level Security policies in the same
  migration that creates it.** No table ships without RLS.
- **Migration files are structured in three phases in this order**:
  all `CREATE TABLE` statements, then all triggers, then all RLS
  policies. Never interleave.
- **Primary keys are client-generated UUIDs**, never server
  auto-increment integers, for any table involved in offline sync.
- **`reason` fields are always optional.** Never add a required-field
  validation on a reason/description field anywhere in the capture
  flow.
- **Default split is "everyone," never a mandatory per-expense
  member-picker.** The one-tap default path must remain one tap.
- **`funded_by_user` and `funded_by_cash_pool` are mutually
  exclusive** on any expense-like row — enforce with a `CHECK`
  constraint, not just application logic.
- **Soft delete only** (`deleted_at`), never a hard `DELETE` on
  `expenses`, `transfers`, or `cash_pools`.
- **Before changing or removing anything described in
  `docs/DECISIONS_AND_GOTCHAS.md`, re-read the relevant entry.** These
  were real bugs, not arbitrary choices — a "simplification" that
  removes one of these is very likely reintroducing the bug it fixed.

## Code conventions

- Dart/Flutter: standard Dart style, one widget/class per file for
  anything non-trivial, Riverpod providers colocated with the feature
  that owns them
- SQL: `snake_case`, plural table names, `<table>_id` foreign key
  naming convention, comments on any non-obvious constraint
- Every new migration is a new numbered file
  (`000N_description.sql`) — never edit a previously-applied migration
  file in place

## When you finish a significant piece of work

- Update `docs/ROADMAP.md` checkboxes to reflect actual state
- If you hit a new gotcha, bug, or non-obvious design decision, add it
  to `docs/DECISIONS_AND_GOTCHAS.md` with the same level of concrete
  detail as the existing entries (a worked example with real numbers
  where relevant, not just an abstract description)
- Do not rely solely on automatic Knowledge Item extraction to
  preserve this — write it into the file explicitly
