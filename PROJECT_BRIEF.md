
# PROJECT BRIEF — Trip Expense Ledger

> This file is the source of truth for *why this project exists*. If any
> other document, any plan, or any code contradicts this file, this file
> wins. Read this first, every session, before touching anything else.

## The problem, stated precisely

Two people went on a 4-day trip. They paid mostly via UPI, sometimes in
cash. When the trip ended, they tried to reconstruct who paid what from
memory and transaction history. They could recover most UPI payments by
checking bank history. They could recover almost none of the cash
payments. They ended up building a manual Excel sheet after the fact,
and it was already difficult for 2 people over 4 days.

**The failure was not "we lacked an expense tracker."** The failure was
that reconstruction from memory is inherently lossy, and the loss grows
with trip length and group size. Any solution that captures expenses
*after* the trip is already too late — the system has to capture at the
moment of payment, not reconstruct afterward.

## What this product actually is

A **real-time, shared trip ledger** — not a personal finance tracker,
not a general-purpose expense tracker, not a bookkeeping app. Every
payment, the instant it happens, becomes visible to the whole group.
Settlement math is the easy, solved part; it is not the point of this
product. The point is closing the gap between "money moved" and
"everyone in the group knows about it" to as close to zero as possible.

## Non-goals — things this product explicitly does NOT do

Do not add these without a deliberate, written decision to change scope:

- Personal budgeting, spending analytics, or monthly finance dashboards
- Categorization/tagging for its own sake (categories are not the goal —
  fast, low-friction capture is)
- Multi-currency support (v1 is single-currency, INR)
- Payment settlement integration / actual money movement via the app
  (UPI deep-links to "pay now" are a nice-to-have convenience, never a
  requirement)
- A general-purpose Splitwise clone with every feature Splitwise has

## The three non-negotiable design principles

1. **Capture at source beats reconstruction after.** Every design
   decision should be evaluated against: does this make it more likely
   someone logs a payment within seconds of making it, or does it add
   friction that pushes logging to "later" (which becomes "never" or
   "wrong")?
2. **Speed beats structure at the point of capture.** Reason fields,
   category pickers, and split editors must never block or slow down
   the initial log. Structure and correction can happen later, in a
   calmer moment; capture cannot wait.
3. **Correctness lives in the data model, not in the user's head.**
   Users should never have to remember "who really funded this" or "did
   I already settle this with him" — the schema tracks it so nobody has
   to.

## Who this is for, initially

Groups of friends/family on a multi-day trip in India, predominantly
using UPI with some cash, on Android primarily (iOS gets a
manual-entry-only experience — see ARCHITECTURE.md for why this is a
hard platform constraint, not a choice).

## The single test every feature must pass

> "Would this have helped Pavan and his friend avoid the Excel sheet
> after their Goa trip?"

If a proposed feature doesn't clearly answer yes, it does not belong in
the current milestone. Refer to ROADMAP.md before adding scop
