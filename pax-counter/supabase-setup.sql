-- After this base setup, run supabase-gps-migration.sql for the GPS-enabled app.
create table if not exists public.passenger_observations (
  observation_id uuid primary key,
  session_id uuid not null,
  staff_initials text,
  location text not null check (char_length(location) between 1 and 200),
  type text not null check (type in ('boarding', 'exiting')),
  timestamp_utc timestamptz not null,
  timestamp_nyc text not null,
  count smallint not null default 1 check (count = 1),
  received_at timestamptz not null default now()
);

alter table public.passenger_observations
  add column if not exists staff_initials text;

alter table public.passenger_observations
  drop constraint if exists passenger_observations_staff_initials_check;
alter table public.passenger_observations
  add constraint passenger_observations_staff_initials_check
  check (staff_initials is null or char_length(trim(staff_initials)) between 1 and 12);

alter table public.passenger_observations enable row level security;

revoke all on table public.passenger_observations from anon, authenticated;
grant insert on table public.passenger_observations to anon;

drop policy if exists "Public counter submissions" on public.passenger_observations;
create policy "Public counter submissions"
on public.passenger_observations
for insert
to anon
with check (
  type in ('boarding', 'exiting')
  and count = 1
  and char_length(location) between 1 and 200
);

create or replace view public.passenger_observations_export
with (security_invoker = true)
as
select session_id, location, type, timestamp_nyc, count, staff_initials
from public.passenger_observations
order by timestamp_utc;

revoke all on table public.passenger_observations_export from anon, authenticated;

create table if not exists public.passenger_count_sessions (
  session_id uuid primary key,
  staff_initials text check (
    staff_initials is null
    or char_length(trim(staff_initials)) between 1 and 12
  ),
  location text not null check (char_length(location) between 1 and 200),
  started_at_utc timestamptz not null,
  finished_at_utc timestamptz not null,
  van_count integer not null default 1 check (van_count = 1),
  boarding_total integer not null check (boarding_total >= 0),
  exiting_total integer not null check (exiting_total >= 0),
  received_at timestamptz not null default now(),
  check (finished_at_utc >= started_at_utc)
);

alter table public.passenger_count_sessions
  add column if not exists van_count integer not null default 1;

alter table public.passenger_count_sessions
  drop constraint if exists passenger_count_sessions_van_count_check;
alter table public.passenger_count_sessions
  add constraint passenger_count_sessions_van_count_check
  check (van_count = 1);

alter table public.passenger_count_sessions enable row level security;

revoke all on table public.passenger_count_sessions from anon, authenticated;
grant insert on table public.passenger_count_sessions to anon;

drop policy if exists "Public session submissions" on public.passenger_count_sessions;
create policy "Public session submissions"
on public.passenger_count_sessions
for insert
to anon
with check (
  char_length(location) between 1 and 200
  and (staff_initials is null or char_length(trim(staff_initials)) between 1 and 12)
  and van_count = 1
  and boarding_total >= 0
  and exiting_total >= 0
  and finished_at_utc >= started_at_utc
);

create or replace view public.passenger_count_sessions_export
with (security_invoker = true)
as
select
  session_id,
  staff_initials,
  location,
  started_at_utc,
  finished_at_utc,
  boarding_total,
  exiting_total,
  van_count
from public.passenger_count_sessions
order by started_at_utc;

revoke all on table public.passenger_count_sessions_export from anon, authenticated;
