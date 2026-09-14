create table if not exists public.passenger_observations (
  observation_id uuid primary key,
  session_id uuid not null,
  location text not null check (char_length(location) between 1 and 200),
  type text not null check (type in ('boarding', 'exiting')),
  timestamp_utc timestamptz not null,
  timestamp_nyc text not null,
  count smallint not null default 1 check (count = 1),
  received_at timestamptz not null default now()
);

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
select session_id, location, type, timestamp_nyc, count
from public.passenger_observations
order by timestamp_utc;

revoke all on table public.passenger_observations_export from anon, authenticated;
