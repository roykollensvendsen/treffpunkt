-- Robot Hood's heartbeat (spec 0122): a single row the owner's forum watch
-- upserts every poll; the app reads it to show whether the robot is
-- listening right now. Written only by the owner's tooling (postgres role) —
-- authenticated users read, nothing else.

create table public.robot_presence (
  id      integer primary key default 1 check (id = 1),
  seen_at timestamptz not null default now()
);

alter table public.robot_presence enable row level security;

create policy "Robot presence is readable by the signed-in"
  on public.robot_presence for select to authenticated
  using (true);

grant select on public.robot_presence to authenticated;
