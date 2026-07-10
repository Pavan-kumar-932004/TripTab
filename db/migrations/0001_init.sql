-- ============================================================
-- TRIP EXPENSE APP — PRODUCTION SCHEMA (Supabase / Postgres)
-- Migration: 0001_init.sql
--
-- Structured in three phases, in this order, deliberately:
--   PHASE 1 — all tables (so no policy/trigger references
--             something that doesn't exist yet)
--   PHASE 2 — triggers
--   PHASE 3 — row level security (enable + policies)
-- ============================================================

create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- PHASE 1: TABLES
-- ------------------------------------------------------------

create table users (
    id              uuid primary key,
    name            text not null,
    email           text unique,
    avatar_url      text,
    upi_vpa         text,
    phone_number    text,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create table trips (
    id              uuid primary key,
    title           text not null,
    currency        text not null default 'INR',
    created_by      uuid not null references users(id),
    started_at      timestamptz,
    ended_at        timestamptz,
    status          text not null default 'draft'
                    check (status in ('draft','active','settled')),
    deleted_at      timestamptz,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create table trip_members (
    trip_id         uuid not null references trips(id),
    user_id         uuid not null references users(id),
    joined_at       timestamptz not null default now(),
    role            text not null default 'member'
                    check (role in ('owner','member')),
    primary key (trip_id, user_id)
);

create table cash_pools (
    id                  uuid primary key,
    trip_id             uuid not null references trips(id),
    from_user           uuid not null references users(id),
    held_by_user        uuid not null references users(id),
    amount_minor        bigint not null check (amount_minor > 0),
    remaining_minor     bigint not null,
    status              text not null default 'open'
                        check (status in ('open','fully_spent','returned','closed')),
    deleted_at          timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    closed_at           timestamptz
);

create table expenses (
    id                  uuid primary key,
    trip_id             uuid not null references trips(id),
    logged_by           uuid not null references users(id),
    funded_by_user      uuid references users(id),
    funded_by_cash_pool uuid references cash_pools(id),
    amount_minor        bigint not null check (amount_minor > 0),
    reason              text,
    split_type          text not null default 'equal'
                        check (split_type in ('equal','exact','percentage')),
    source              text not null default 'manual'
                        check (source in ('manual','upi_auto','sms_auto')),
    payment_at          timestamptz not null,
    entry_at            timestamptz not null default now(),
    photo_url           text,
    origin_device_id    text not null,
    deleted_at          timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    check (
        (funded_by_user is not null)::int + (funded_by_cash_pool is not null)::int <= 1
    )
);

create table expense_participants (
    expense_id      uuid not null references expenses(id),
    user_id         uuid not null references users(id),
    share_minor     bigint not null,
    primary key (expense_id, user_id)
);

create table transfers (
    id                  uuid primary key,
    trip_id             uuid not null references trips(id),
    from_user           uuid not null references users(id),
    to_user             uuid not null references users(id),
    amount_minor        bigint not null check (amount_minor > 0),
    type                text not null
                        check (type in ('settlement','cash_given','cash_returned')),
    related_pool_id     uuid references cash_pools(id),
    status              text not null default 'pending'
                        check (status in ('pending','settled')),
    source              text not null default 'manual'
                        check (source in ('manual','upi_auto')),
    payment_at          timestamptz not null,
    entry_at            timestamptz not null default now(),
    origin_device_id    text not null,
    deleted_at          timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

create table edit_history (
    id              uuid primary key,
    entity_type     text not null check (entity_type in ('expense','transfer','cash_pool')),
    entity_id       uuid not null,
    edited_by       uuid not null references users(id),
    edited_at       timestamptz not null default now(),
    old_value       jsonb not null,
    new_value       jsonb not null
);

-- indexes
create index idx_expenses_trip       on expenses(trip_id) where deleted_at is null;
create index idx_expenses_entry_time on expenses(trip_id, entry_at);
create index idx_participants_user   on expense_participants(user_id);
create index idx_transfers_trip      on transfers(trip_id) where deleted_at is null;
create index idx_cash_pools_trip     on cash_pools(trip_id);


-- ------------------------------------------------------------
-- PHASE 2: TRIGGERS
-- ------------------------------------------------------------

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_users_updated_at      before update on users      for each row execute function set_updated_at();
create trigger trg_trips_updated_at      before update on trips      for each row execute function set_updated_at();
create trigger trg_cash_pools_updated_at before update on cash_pools for each row execute function set_updated_at();
create trigger trg_expenses_updated_at   before update on expenses   for each row execute function set_updated_at();
create trigger trg_transfers_updated_at  before update on transfers  for each row execute function set_updated_at();


-- ------------------------------------------------------------
-- PHASE 3: ROW LEVEL SECURITY
-- ------------------------------------------------------------

alter table users               enable row level security;
alter table trips               enable row level security;
alter table trip_members        enable row level security;
alter table cash_pools          enable row level security;
alter table expenses            enable row level security;
alter table expense_participants enable row level security;
alter table transfers           enable row level security;
alter table edit_history        enable row level security;

-- USERS
create policy "users can read profiles in their shared trips"
on users for select
using (
    id = auth.uid()
    or id in (
        select tm2.user_id from trip_members tm1
        join trip_members tm2 on tm1.trip_id = tm2.trip_id
        where tm1.user_id = auth.uid()
    )
);

create policy "users can update only their own profile"
on users for update
using (id = auth.uid());

-- TRIPS
create policy "members can read their trips"
on trips for select
using (
    id in (select trip_id from trip_members where user_id = auth.uid())
    and deleted_at is null
);

create policy "creator can update trip"
on trips for update
using (created_by = auth.uid());

-- TRIP_MEMBERS
create policy "members can see their own trip's roster"
on trip_members for select
using (
    trip_id in (select trip_id from trip_members where user_id = auth.uid())
);

create policy "owner can add members"
on trip_members for insert
with check (
    trip_id in (select trip_id from trip_members where user_id = auth.uid() and role = 'owner')
    or trip_id in (select id from trips where created_by = auth.uid())
);

-- CASH_POOLS
create policy "trip members can read cash pools"
on cash_pools for select
using (trip_id in (select trip_id from trip_members where user_id = auth.uid()));

create policy "trip members can create cash pools they fund"
on cash_pools for insert
with check (
    from_user = auth.uid()
    and trip_id in (select trip_id from trip_members where user_id = auth.uid())
);

-- EXPENSES
create policy "trip members can read expenses"
on expenses for select
using (
    trip_id in (select trip_id from trip_members where user_id = auth.uid())
    and deleted_at is null
);

create policy "trip members can insert expenses"
on expenses for insert
with check (
    trip_id in (select trip_id from trip_members where user_id = auth.uid())
    and logged_by = auth.uid()
);

create policy "logger can update their own expense entry"
on expenses for update
using (logged_by = auth.uid());

-- EXPENSE_PARTICIPANTS
create policy "trip members can read splits"
on expense_participants for select
using (
    expense_id in (
        select e.id from expenses e
        join trip_members tm on tm.trip_id = e.trip_id
        where tm.user_id = auth.uid()
    )
);

-- TRANSFERS
create policy "trip members can read transfers"
on transfers for select
using (
    trip_id in (select trip_id from trip_members where user_id = auth.uid())
    and deleted_at is null
);

create policy "participants can create their own transfer"
on transfers for insert
with check (
    from_user = auth.uid()
    and trip_id in (select trip_id from trip_members where user_id = auth.uid())
);

-- EDIT_HISTORY
create policy "trip members can read edit history for their trip's entities"
on edit_history for select
using (
    edited_by = auth.uid()
    or entity_id in (select id from expenses where trip_id in
        (select trip_id from trip_members where user_id = auth.uid()))
);


-- ------------------------------------------------------------
-- REALTIME
-- ------------------------------------------------------------
alter publication supabase_realtime add table expenses;
alter publication supabase_realtime add table expense_participants;
alter publication supabase_realtime add table transfers;
alter publication supabase_realtime add table cash_pools;