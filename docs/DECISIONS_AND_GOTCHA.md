
# DECISIONS AND GOTCHAS

> This is the single most important file for preventing regressions.
> Every item here was a real bug or design mistake identified and
> fixed during design. If a future change appears to "simplify" or
> "clean up" something described here, treat that as a red flag, not
> an improvement — re-read the reasoning before changing it.

---

## 1. Default split is "everyone," one tap to override — never the reverse

**The bug this prevents**: if the confirm/quick-add flow just asks
"add to group?" with a typed reason and nothing else, every expense
silently splits across the whole group by default. This is wrong the
first time three of five people go out for drinks and the other two
don't — the ₹1,200 bar tab gets split across all five, and you're back
to an argument at settle-time.

**The fix**: the confirm prompt's default action is a single tap:
"₹1,200 → [Trip] → split with all N members." Only tapping "edit
split" expands into a member picker. Do not make split-selection a
mandatory step on the fast path — most expenses (hotel, cab, groceries)
really are all-in, and the rare exception should take the slow path,
not corrupt the default.

---

## 2. Direct payments between group members must not become shared expenses

**The bug**: if you reimburse a friend ₹1,000 via UPI for something he
fronted, and the notification listener treats every outgoing UPI debit
as "add to group?", you'll log a *second* ₹1,000 shared expense on top
of the original cost he already logged. The group ledger then thinks
this transaction should be split across everyone, when it was actually
a private settlement between two people. Balances will not reconcile.

**The fix**: maintain a lookup of each group member's known
`upi_vpa`/`phone_number` (collected at trip-join time). Before
prompting on a captured UPI debit, check the payee identifier against
this lookup:

- Matches a group member → prompt as a **settlement/transfer**
  ("mark as settling your balance with [name]?"), write to `transfers`,
  never to `expenses`.
- No match → treat as a normal merchant payment, prompt as a shared
  expense.

Parsing will not always cleanly resolve a payee (masked account
numbers, unfamiliar bank formats). Do not rely on silent
auto-detection alone — provide a manual override toggle ("is this a
payment to a group member instead of a shared expense?") defaulting to
"no," so a missed auto-match degrades to one tap, not a corrupted
ledger.

---

## 3. The cash-pool / advance problem — worked example, keep these numbers

**Scenario**: Pavan gives A ₹500. A spends ₹100 on snacks, then the
remaining ₹400 on tickets (₹150), food (₹150), and water (₹100), in a
4-person group (Pavan, A, B, C).

**Why this breaks a naive model**: if A logs these expenses as
"paid by me," the ledger credits A for fronting ₹500 of his own money.
It was actually Pavan's money. Skipping this distinction produces a
wrong settlement number, not just an ugly one.

**The correct handling**:

- Creating the handoff: one `cash_pools` row
  (`from_user=Pavan, held_by_user=A, amount=500, remaining=500`).
  This does **not** touch the group ledger balance by itself.
- Each expense A logs picks `funded_by_cash_pool` = this pool, **not**
  `funded_by_user = A`. `remaining_minor` decrements: 500 → 400 → 250 →
  100 → 0.
- Result: all four expenses are attributed to Pavan as funder. Split
  4 ways at ₹125/person each: A, B, and C each owe Pavan ₹125. Pavan
  owes nothing further — his own ₹125 share nets out automatically
  inside the settlement aggregation, since it's computed as a net
  balance, not a separate self-debt.
- If the pool doesn't fully deplete (say only ₹350 got spent), the
  leftover ₹150 is a private matter between Pavan and A — mark the pool
  `returned`, no group-ledger entry needed at all. It was never the
  group's money.

**UI naming reminder**: none of the above is exposed to the user as
"cash pool," "advance," or "float." The button says "Give cash." The
funded-by picker, when relevant, should read naturally (e.g. "Pavan's
cash" as a quick-select option), not "Advance #3."

**Deliberately deferred to a later phase**: using someone's cash-pool
money to settle a *personal* debt (rather than pay for a new shared
expense) is a real but rarer case. Handle it in v1 as a free-text note
on the transfer, not a fully modeled flow — do not build dedicated UI
for this until usage data shows it's common enough to justify it.

---

## 4. Reason field must never block capture

**The bug**: requiring a non-empty reason before an expense can be
logged means that under real trip conditions (rain, a bus leaving,
hands full) people skip logging entirely rather than type something.
This directly reintroduces the reconstruction-after-the-fact failure
the whole product exists to prevent.

**The fix**: `reason` is nullable at the schema level and optional at
every UI entry point, always. Auto-captured expenses can default to
the merchant name; manual entries can be submitted with amount only.
Reason can always be added or edited later from the timeline view.

---

## 5. Notification confirmation should not default to interrupting every time

**The bug**: prompting on every single captured payment (coffee, fuel,
parking, tea, lunch, snacks — a normal day easily produces 8-10) causes
notification fatigue, and users will disable the permission entirely
to make it stop — which puts them right back to manual-only, but now
with a bad taste about the feature.

**The fix**: support two per-device, per-user modes (not group-wide —
different people in the same trip can run different modes with no
coordination problem):

- **Live-prompt**: immediate confirm popup per capture.
- **Silent-capture**: the listener still captures and parses instantly
  (accuracy/freshness is unaffected), but queues into an in-app review
  list instead of interrupting. User batch-confirms/edits/dismisses
  later.

Be honest with the user (and yourself) about the tradeoff: silent mode
reintroduces a smaller version of the original problem if the queue is
left unreviewed for a long stretch. A badge/notification count on
unreviewed items is a reasonable mitigation, not a full fix.

---

## 6. Android permission gating is app-level, not OS-level

`NotificationListenerService`, once granted, receives every system
notification — Android provides no way to subscribe to only specific
source apps. "Only active during a trip" must be implemented as an
app-level check (`if trip.status != 'active': return` inside
`onNotificationPosted()`), not assumed to be handled by the permission
system itself. Do not build UI copy that implies the permission itself
is being toggled on/off per trip — it isn't; the app's use of it is.

---

## 7. OEM battery management will silently break capture on common Indian devices

MIUI (Xiaomi), ColorOS (Oppo), and FuntouchOS (Vivo) — all common in
the target market — aggressively kill background services and
notification listeners unless the user manually whitelists the app.
This is not an edge case to discover in a bug report; build an explicit
onboarding step that detects the OEM and walks the user through
whitelisting before relying on auto-capture for that device.

---

## 8. Row-Level Security must ship with every table, from the first migration

An earlier schema draft had zero RLS policies. Since Supabase clients
talk directly to Postgres with an extractable anon key, this means any
authenticated user could read or write any other trip's financial
data, including phone numbers and UPI IDs. Every table gets RLS
policies in the *same* migration that creates it. See DATA_MODEL.md
and `db/migrations/0001_init.sql` for the canonical pattern.

---

## 9. Migration files must be ordered: tables, then triggers, then RLS policies

A concrete bug hit during development: a policy on `users` referenced
`trip_members`, but `trip_members` was created later in the same file,
causing `relation "trip_members" does not exist`. Structure every
migration in three phases in this exact order — all `CREATE TABLE`
statements, then all triggers, then all RLS policies — so no policy or
trigger can reference an object that doesn't exist yet.

---

## 10. Concurrent edits to the same row — not yet resolved, flag before building

The sync engine cleanly handles concurrent **additions** (two offline
devices creating independent rows never conflict). It does **not** yet
have a fully specified answer for two devices editing the **same**
expense while both offline. Current stopgap: last-writer-wins on the
displayed value by `updated_at`, with the losing edit preserved in
`edit_history`. This is a reasonable v1 stopgap, not a final answer —
if this becomes a real pain point in usage, revisit before extending
it further.
