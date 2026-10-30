-- 운동로그 동기화 초기 스키마 (docs/supabase-sync.md)
create table public.sessions (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id),
  date timestamptz not null,
  kind text not null,              -- strength / interval / activity
  condition text,
  body_part text,
  note text,
  start_at timestamptz,
  end_at timestamptz,
  cardio_mode text,
  activity_name text,
  distance_m double precision,
  lifts jsonb,                     -- [LiftEntry] 그대로 (setReps, setWeights, doneAt, rir, memo ...)
  interval jsonb,
  interval_detail jsonb,
  telemetry jsonb,
  health_kit_uuid text,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.body_records (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id),
  date timestamptz not null,
  data jsonb not null,             -- 체중·골격근·체지방 등 BodyRecord 전체
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.planned_workouts (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id),
  date timestamptz not null,
  data jsonb not null,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

-- 본인 데이터만 (행 단위 권한)
alter table public.sessions enable row level security;
alter table public.body_records enable row level security;
alter table public.planned_workouts enable row level security;
create policy own on public.sessions for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy own on public.body_records for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy own on public.planned_workouts for all using (user_id = auth.uid()) with check (user_id = auth.uid());
