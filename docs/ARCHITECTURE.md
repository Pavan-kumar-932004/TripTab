
# ARCHITECTURE

> Read PROJECT_BRIEF.md first. This document describes *how* the system
> is built to serve that brief. If an implementation detail here seems
> to conflict with the brief, the brief wins — flag the conflict, don't
> silently resolve it in code.

## Stack

- **Client**: Flutter + Dart, state management via Riverpod
- **Local storage**: Drift (typed SQLite) — this is the source of truth
  on-device, not a cache
- **Backend**: Supabase (Postgres + Realtime + Auth)
- **Sync transport**: Supabase Realtime, scoped per `trip_id`

## The one architectural decision everything else depends on

**Offline-first, not offline-tolerant.** The app must be fully usable
with zero network connectivity, indefinitely. Sync is something that
happens *to* the local data when connectivity permits, not something
the user waits for. Every write path must complete successfully with
the device in airplane mode. This is not an edge case for this product —
trips regularly happen in hills, forests, villages, and trains with
patchy or absent signal, and that is the exact condition under which
users most need capture to keep working.

## Platform constraint you must not try to engineer around

**iOS has no equivalent to Android's `NotificationListenerService`.**
There is no API, public or private-but-tolerated, that lets a
third-party app read another app's notification content on iOS. This
is a hard Apple platform restriction, not a permissions issue that can
be solved with the right entitlement. iOS gets manual entry only
(in-app quick-add, and to the extent possible, a Siri Shortcut or
widget with a text field approximating the Android notification
quick-add). Do not scope work assuming this will be solved later — it
will not be, on this platform.

## Real-time payment capture (Android)

- Mechanism: `NotificationListenerService`, granted via a manual
  Settings toggle (Settings → Apps → Special App Access → Notification
  Access) — **not** a Play Store runtime permission dialog.
- **Do not use `READ_SMS`/`RECEIVE_SMS`.** Since Google's 2019 Play
  Store policy change, SMS permissions are restricted to apps whose
  core function is SMS/calling. An expense app requesting this category
  will be rejected or pulled. `NotificationListenerService` is not
  covered by that restriction and is why every surviving
  notification-based expense app in India uses it instead of SMS.
- The listener receives *every* system notification once granted —
  Android does not let you subscribe to only specific source apps at
  the OS level. Gating to "only during an active trip" is an
  **app-level** concern: check `trip.status == 'active'` inside
  `onNotificationPosted()` and no-op immediately if false. The
  permission stays granted at all times; the app just does nothing with
  it outside an active trip window.
- Parsing is per-bank/per-app regex against notification text
  (`EXTRA_TITLE`, `EXTRA_TEXT`, `EXTRA_BIG_TEXT`). This will need
  ongoing maintenance as banks change message formats — budget for this
  as an ongoing cost, not a one-time build.
- **Known India-specific failure mode**: MIUI (Xiaomi), ColorOS (Oppo),
  and FuntouchOS (Vivo) aggressively kill background services and
  notification listeners unless the user manually whitelists the app in
  vendor-specific battery settings. Build an explicit onboarding flow
  that detects OEM and walks the user through whitelisting — do not
  assume the standard Android permission grant is sufficient on these
  devices.
- Users who disable notifications for their banking app, or who
  disable this feature by preference, must have a **fully equivalent**
  manual entry path — not a degraded fallback. See "Notification-panel
  quick-add" below.

## Notification-panel quick-add (the manual-entry core, both platforms)

- Android: persistent/ongoing notification (foreground service, same
  pattern as a music-player control) with a `RemoteInput` inline text
  field — the same mechanism WhatsApp uses for "reply from
  notification." User types e.g. `100 bus ticket` and submits without
  opening the app.
- Parse dumb-simple: first number in the string is the amount,
  remainder is the (optional) reason. Do not attempt NLP or
  categorization at this step — the user typed it explicitly, trust it
  as-is.
- iOS: in-app quick-add screen as the primary path; a Siri Shortcut or
  home-screen widget with a text field as a secondary convenience,
  understanding it will not be as fast as the Android notification
  panel.
- This path must work with zero network — it writes straight to the
  local Drift database and the local outbox, exactly like every other
  write path.

## Sync engine

### Why not "sync current state, last-write-wins"

Money data cannot tolerate silent data loss. If two group members are
both offline in the same remote area and both log expenses
independently, a naive "sync current state" model risks one person's
writes silently overwriting or dropping the other's. Treat every
expense/transfer/cash-pool creation as an **independent, immutable
event**, not a mutable row being replicated.

### The mechanism

1. Every new row (`expenses`, `expense_participants`, `transfers`,
   `cash_pools`) gets a **client-generated UUID** at creation time, on
   the local device — never a server-assigned auto-increment ID. This
   is what allows two fully offline devices to create rows
   independently with zero collision risk.
2. The write lands in the local Drift database **and** a local
   `sync_outbox` queue in the same local transaction. The UI updates
   immediately (optimistic) — it never waits on network.
3. A background sync worker wakes on connectivity and pushes queued
   outbox rows to Supabase using `INSERT ... ON CONFLICT (id) DO NOTHING`. This makes the push **idempotent** — safe to retry after a
   dropped connection without creating duplicates.
4. Because additions are independent (no two devices ever try to
   mutate the *same* row concurrently in the common case), merging is
   effectively a set union — this is the same core property that makes
   CRDTs (conflict-free replicated data types) work, though no CRDT
   library is required; it falls out naturally from modeling writes as
   append-only events with client-side UUIDs.
5. **Edits and deletes are the one case that needs explicit handling.**
   Model deletes as a soft `deleted_at` timestamp, never a hard
   `DELETE`. Model edits as an update guarded by `updated_at`
   comparison (last-writer-wins for the *displayed* value only) — but
   every edit must also write a row to `edit_history` with the old and
   new value, so nothing is silently lost even when one edit "wins"
   over a concurrent one. See DECISIONS_AND_GOTCHAS.md — this specific
   case (two people editing the same expense while both offline) is
   flagged there as not fully resolved and needs a decision before it's
   built.
6. Supabase Realtime, subscribed per active `trip_id` (not globally),
   pushes new/changed rows to every other device in that trip as soon
   as they're online. Devices that were offline pull missed events on
   next reconnect regardless.

### What Supabase gives you for free, and what it does not

Supabase Realtime handles **transport** — it will tell other devices a
row changed. It does **not** give you conflict-resolution logic for
free. The idempotent-upsert and edit-history behavior above must be
built explicitly in the client sync engine; do not assume subscribing
to a Postgres table's changes solves correctness on its own.

## Settlement computation

Settlement is a **read-only, on-demand aggregation** — never a stored
running balance. Computing it fresh from the immutable event tables
avoids race conditions that a mutable "running total" column would
introduce under concurrent offline writes. At settle time:

```
net_balance(user) =
    SUM(expense_participants.share_minor where user_id = user)   -- owed
  - SUM(expenses.amount_minor where funded_by resolves to user)  -- funded
  - SUM(transfers where type = 'settlement' and involves user)   -- already settled
```

Feed the resulting net balances into a standard debt-minimization
(min-cash-flow) algorithm to produce the smallest number of final
payments. This part is commodity — do not over-invest engineering time
here; it is well-understood and not a differentiator.

## Security: Row-Level Security is mandatory, not optional

Supabase clients talk **directly** to Postgres using an anon key that
is extractable from the app binary. Without RLS, that key grants read
and write access to every row in every table for every user. Every
table must have RLS enabled with policies scoped to trip membership
before it ships, with no exceptions. See DATA_MODEL.md for the
specific policy shape per table, and DECISIONS_AND_GOTCHAS.md for why
this was flagged as a serious gap in an earlier draft.

## Dataflow summary (single expense, end to end)

```
User action (notification quick-add or in-app)
  → Local Drift write (instant, synchronous) + sync_outbox insert
  → Background sync worker (waits for connectivity)
  → Supabase Postgres, UPSERT on client UUID, ON CONFLICT DO NOTHING
  → Supabase Realtime broadcast, filtered by trip_id
  → Other devices: receive event → merge into local Drift → UI updates
  → (later, on demand) Settlement query aggregates all events → net
    balances → debt-minimization → final settle-up numbers
```
