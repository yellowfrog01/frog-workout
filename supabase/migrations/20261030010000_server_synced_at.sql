-- 풀(받기) 커서용 서버 시각. 클라이언트가 보낸 updated_at(충돌 판정용)과 별개로,
-- 서버에 쓰인 순간의 시각을 항상 기록한다. 오프라인에서 고친 행이 과거 updated_at 으로
-- 늦게 올라와도 다른 기기가 놓치지 않게 synced_at 으로 받는다.
create or replace function public.set_synced_at() returns trigger
language plpgsql as $$
begin
  new.synced_at := clock_timestamp();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['sessions','body_records','planned_workouts'] loop
    execute format('alter table public.%I add column if not exists synced_at timestamptz not null default clock_timestamp()', t);
    execute format('drop trigger if exists trg_synced_at on public.%I', t);
    execute format('create trigger trg_synced_at before insert or update on public.%I for each row execute function public.set_synced_at()', t);
    execute format('create index if not exists %I on public.%I (user_id, synced_at)', t || '_synced_idx', t);
  end loop;
end $$;
