
# ROADMAP

> Read PROJECT_BRIEF.md first. Every phase below is gated on the one
> before it actually working, not just being coded. Do not begin a
> later phase's work inside the same session as an earlier phase
> unless the earlier phase's milestone checklist is fully checked.

## Phase 0 — Foundation

- [x] Repo scaffold: Flutter project, Riverpod, Drift configured
- [ ] Supabase project created, `db/migrations/0001_init.sql` applied
- [ ] Verify RLS actually works: create two test accounts, confirm
  account B cannot read account A's trip data via direct query —
  do not just review the policy SQL by eye, attempt to break it
- [x] Local Drift schema mirrors the Supabase schema 1:1

**Exit criteria**: a second engineer (or a fresh agent session) can
clone the repo, run migrations, and confirm the RLS isolation test
passes, without asking you anything.

## Phase 1 — Manual-only MVP

- [ ] Create trip, invite members (via `trip_members`)
- [ ] Start/end trip timer (`trips.status` transitions)
- [ ] Persistent notification quick-add with `RemoteInput` (Android)
- [ ] In-app quick-add screen (iOS, and as Android fallback)
- [ ] Reason field optional everywhere — verify by testing the flow
  with reason left blank, not just checking the schema allows null
- [ ] Default-to-everyone split with one-tap override to specific
  members
- [ ] Shared chronological timeline as the primary screen (not a
  balance-sheet view)
- [ ] Local writes are instant and fully functional in airplane mode

**Exit criteria**: two people can run a real trip end-to-end using only
this phase, with the device offline for stretches, and every expense
they logged is present and correctly attributed afterward.

**This phase alone must solve the original problem.** If it doesn't,
do not proceed to Phase 2 — fix Phase 1 first.

## Phase 2 — Sync

- [ ] `sync_outbox` local table, populated in the same transaction as
  every write
- [ ] Background sync worker, idempotent UPSERT on client UUID
- [ ] Supabase Realtime subscription scoped per active `trip_id`
- [ ] Test: two devices, both offline, both log expenses independently,
  then reconnect — confirm both sets of expenses appear on both
  devices with no duplicates and no loss
- [ ] Edit/delete handling: soft delete via `deleted_at`, edits write
  to `edit_history`

**Exit criteria**: the two-offline-devices test above passes reliably,
repeated at least 5 times with different orderings of who reconnects
first.

## Phase 3 — Settlement

- [ ] Net-balance aggregation query (read-only, computed on demand —
  never a stored running total)
- [ ] Debt-minimization algorithm producing the smallest set of final
  payments
- [ ] Settle-up screen
- [ ] Cash-pool (`funded_by_cash_pool`) correctly folds into the net
  balance — test against the worked ₹500 example in
  DECISIONS_AND_GOTCHAS.md, confirm the numbers match exactly

**Exit criteria**: the worked example in DECISIONS_AND_GOTCHAS.md
(₹500 → tickets/food/water, 4-person group) produces the exact
predicted final settlement numbers when run through the actual app.

## Phase 4 — Android auto-capture (do not start before Phase 1–3 are validated with real usage)

- [ ] `NotificationListenerService` implementation, gated by
  app-level `trip.status == 'active'` check
- [ ] Per-bank/per-app notification parsing (start with the 3-4 most
  common apps/banks in your initial user base, not all of them)
- [ ] Member-vs-merchant VPA/phone lookup and disambiguation
- [ ] Live-prompt vs silent-capture-queue mode, per-device toggle
- [ ] OEM battery-whitelist onboarding flow for MIUI/ColorOS/FuntouchOS
- [ ] Manual entry remains fully functional and equally fast for users
  who keep this feature off

**Why this phase is explicitly last, in writing**: this is the
product's real long-term differentiator, but also its highest-risk,
highest-maintenance component (parsing breaks silently when banks
change formats, Play Store policy scrutiny is real, OEM fragmentation
is real). Validate that people actually adopt and stick with the
manual-capture habit from Phases 1-3 before investing here. If nobody
uses the manual quick-add reliably, auto-capture will not save the
product — the discipline problem is upstream of the automation
problem.

## Explicitly out of scope until a written decision changes this

- Multi-currency support
- Personal budgeting/analytics/spending dashboards
- In-app payment settlement / actual money transfer
- Full audit-log UI (the `edit_history` table exists; a screen to
  browse it does not, and isn't needed yet)
- iOS notification-based auto-capture (not possible — see
  ARCHITECTURE.md)
