-- Repair captured_at instants (spec 0118). Until now the client serialised a
-- LOCAL wall clock with no offset, which Postgres read as UTC — so every
-- stored captured_at is really the Europe/Oslo wall clock. Reinterpret them
-- (DST-aware) into true instants; from this deploy on, the client uploads
-- explicit UTC. created_at columns are server-generated and already correct.

update public.sessions
  set captured_at = (captured_at at time zone 'utc') at time zone 'Europe/Oslo'
  where captured_at is not null;

update public.felt_sessions
  set captured_at = (captured_at at time zone 'utc') at time zone 'Europe/Oslo';
