
# DATA MODEL

> Read PROJECT_BRIEF.md and ARCHITECTURE.md first. The canonical,
> executable schema lives at `db/migrations/0001_init.sql` — this
> document explains *why* it's shaped that way. If the two ever
> disagree, the `.sql` file is what actually runs; update this doc to
> match it, and flag the discrepancy rather than silently trusting
> whichever one you read first.

## The one mental model to hold onto

Every table answers one of two questions:

1. **"What was spent, and who's responsible for sharing it?"** —
   `expenses`, `expense_participants`, `cash_pools`
2. **"What money physically already moved between two specific
   people?"** — `transfers`

Settlement is just the arithmetic difference between those two
categories, computed fresh at read time. Nothing else in this schema
matters more than keeping that distinction clean.

## users

One row per person who has ever used the app, independent of any trip.
`id` is set equal to `auth.uid()` deliberately — not a separately
generated UUID — so RLS policies can compare `auth.uid()` directly
against row ownership without an extra join.

`upi_vpa` and `phone_number` exist specifically to support the
member-vs-merchant disambiguation described in
DECISIONS_AND_GOTCHAS.md — without these, the app cannot tell a
reimbursement to a group member apart from a genuine shared expense.

## trips

The container and **security boundary** for a single trip's data.
Nearly every RLS policy in the schema ultimately reduces to "is this
`trip_id` one the requesting user belongs to."

`status` (`draft → active → settled`) drives the UI state machine
directly — this is the "start trip / end trip" timer the user
controls. `deleted_at` means a trip is archived, never destroyed —
consistent with the transparency principle in the brief.

## trip_members

Pure join table resolving the many-to-many between `users` and
`trips`. Composite primary key (`trip_id`, `user_id`) — the pairing is
what's unique, not a separate surrogate ID.

This table is more load-bearing than it looks: it is the backbone of
the entire RLS model. If a membership row is wrong, it doesn't just
break a UI list — it changes who can read financial data across the
whole app.

## cash_pools

**Internal name only — never shown in the UI.** The user-facing label
is always "cash given" or equivalent; the word "pool," "advance," or
"float" must never appear in a screen a user sees.

Exists to solve the "gave A ₹500, he spent it in pieces on tickets,
food, and water" scenario. `remaining_minor` decrements every time an
`expenses` row references this pool as its funder (`funded_by_cash_pool`).
`status` lifecycle: `open` → `fully_spent` (hit zero via expenses) or
`returned` (leftover handed back) → `closed`.

## expenses

The core transaction record. The field that matters most in the entire
schema:

**`funded_by_user` and `funded_by_cash_pool` are mutually exclusive**
(enforced by a `CHECK` constraint) and represent *whose money it
actually was* — as distinct from `logged_by`, which is just *who did
the data entry*. Get this wrong in the UI (default it to "my own
money" when it should be an open cash pool) and the settlement math
silently misattributes debt. This is the single most important
correctness rule in the whole application. See the worked example
(₹500 → tickets, food, water bottles) in DECISIONS_AND_GOTCHAS.md.

Other fields and their reasoning:

- `reason` is nullable. It must **never** block capture — see the
  "reason is optional" rule in DECISIONS_AND_GOTCHAS.md.
- `payment_at` vs `entry_at` are two separate timestamps, always both
  captured. This pair is what makes "logged promptly" vs "reconstructed
  later" a visible, queryable fact instead of a vague impression —
  it is the concrete embodiment of the transparency goal in the brief.
- `source` (`manual` / `upi_auto` / `sms_auto`) records how the row was
  created, needed even in a manual-only MVP so later phases don't
  require a schema migration to add auto-capture.
- `amount_minor` is a `bigint`, **never** `numeric`/decimal/float.
  Splitting ₹100 three ways as decimals produces 33.33 × 3 = 99.99 — a
  paisa silently vanishes. Store integer paise and resolve remainders
  explicitly at split-calculation time.

## expense_participants

The resolved split — who owes how much of a given expense. A separate
table, not a column on `expenses`, because one expense can have 1 to N
participants (one-to-many, cannot fit in a single row).

`share_minor` always stores the **resolved absolute amount**, never a
raw percentage or share count. The math (equal / exact / percentage)
is resolved once at write time; every read path, including settlement,
can just sum this column with no re-derivation.

## transfers

Direct person-to-person money movement that is **not** a shared
expense: settling a debt, handing over cash, or returning leftover
cash. This table specifically exists to prevent the
"reimbursement gets logged as a new shared expense and gets
double-counted" bug — see DECISIONS_AND_GOTCHAS.md.

`type` (`settlement` / `cash_given` / `cash_returned`) is the field
that distinguishes these three cases; without it, all three look like
identical rows and the settlement math cannot tell them apart.

## edit_history

Lightweight dispute-proofing, deliberately **not** a full audit-log
feature with a dedicated UI in v1. Generic `entity_type` + `entity_id`
covers edits to `expenses`, `transfers`, and `cash_pools` in one table,
since the shape of "what changed, by whom, when, old vs new" is
identical across all three. No hard foreign key on `entity_id`
deliberately, since it must reference rows across three different
tables.

## Row-Level Security — mandatory on every table, no exceptions

Every table must have `ENABLE ROW LEVEL SECURITY` and explicit
policies scoped to trip membership before it ships. See
`db/migrations/0001_init.sql` for the canonical policy set. **RLS
policies must be added in the same migration that creates a new
table** — never as an afterthought in a later migration. An earlier
draft of this schema shipped with zero RLS; treat that as a concrete
example of the failure mode to avoid, not a hypothetical risk.

## Money convention, repeated because it matters

All monetary columns end in `_minor` and are `bigint`. If you ever see
or write a `numeric`, `decimal`, `float`, or `double` column for money
anywhere in this schema, that is a bug — stop and fix it before
proceeding, do not work around it.
