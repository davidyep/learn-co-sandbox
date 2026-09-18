-- Run in Supabase SQL Editor before publishing the GPS-enabled app.
begin;
alter table public.passenger_count_sessions
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists gps_accuracy_m double precision,
  add column if not exists gps_captured_at timestamptz,
  add column if not exists gps_status text not null default 'not_requested';

alter table public.passenger_count_sessions
  drop constraint if exists passenger_count_sessions_gps_check;
alter table public.passenger_count_sessions
  add constraint passenger_count_sessions_gps_check check (
    (gps_status = 'captured'
      and latitude is not null and latitude between -90 and 90
      and longitude is not null and longitude between -180 and 180
      and gps_accuracy_m is not null and gps_accuracy_m >= 0
      and gps_accuracy_m < 'Infinity'::double precision
      and gps_captured_at is not null)
    or (gps_status in ('not_requested','denied','timeout','unavailable','interrupted')
      and latitude is null and longitude is null
      and gps_accuracy_m is null and gps_captured_at is null)
  );

create or replace view public.passenger_count_sessions_export
with (security_invoker = true) as
select session_id, staff_initials, location, started_at_utc, finished_at_utc,
       boarding_total, exiting_total, van_count,
       latitude, longitude, gps_accuracy_m, gps_captured_at, gps_status
from public.passenger_count_sessions
order by started_at_utc;
revoke all on table public.passenger_count_sessions_export from anon, authenticated;
commit;
