# 운동로그 → Supabase 동기화 설계 (1단계: 폰 → 서버 단방향)

## 목표
- 폰(SwiftData)이 원본. 인터넷이 될 때 Supabase(Postgres)로 올린다.
- 웹·SQL 에서 언제든 조회할 수 있게 한다. 폰 고장/DB 초기화 시 백업 역할도 한다.
- 2단계(웹 보기 화면), 3단계(웹 → 폰 역방향)는 별도.

## 결정 사항
| 항목 | 결정 | 이유 |
|---|---|---|
| 클라이언트 | supabase-swift SPM 대신 URLSession 으로 REST 직접 호출 (PostgREST + GoTrue) | 프로젝트 파일에 패키지 의존성을 추가하지 않는다. 필요한 API 는 로그인·토큰 갱신·upsert·update 4개뿐 |
| 인증 | 이메일+비밀번호 1계정. 사용자가 Supabase 대시보드에서 계정 생성 → 앱 설정 화면에서 1회 로그인 | 매직링크는 딥링크 처리가 필요해 1단계에서 제외 |
| 변경 추적 | 행별 JSON 해시 비교. 마지막 업로드 해시를 UserDefaults 에 저장, 달라진 행만 upsert | 기존 코드의 모든 수정 지점에 updatedAt 을 심지 않아도 된다 |
| 삭제 | 이전에 올렸는데 로컬에 없는 id → 서버에서 `deleted = true` (소프트 삭제) | 실수 복구 가능 |
| 행 식별자 | Session/BodyRecord/PlannedWorkout 에 `syncID: UUID?` 추가. 없으면 첫 동기화 때 발급 | persistentModelID 는 기기 간 안정적 식별자가 아님 |
| 실행 시점 | 앱이 앞으로 올 때 + 운동 저장 직후. 최소 간격 60초 | 단순·충분 |
| 큰 데이터 | telemetry(심박·GPS 시계열)도 jsonb 로 올린다 | 세션당 수십 KB, 무료 500MB 한도 내 |

## 스키마 (Supabase SQL)
```sql
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
```

## 앱 구성 (새 파일 위주, 기존 코드는 최소 변경)
- `SupabaseConfig.swift` — 프로젝트 URL, anon key (anon key 는 공개용 키. RLS 로 보호)
- `SupabaseClient.swift` — 로그인(`/auth/v1/token?grant_type=password`), 토큰 갱신(`grant_type=refresh_token`), upsert(`POST /rest/v1/<table>` + `Prefer: resolution=merge-duplicates`), 삭제 표시(`PATCH`). 토큰은 Keychain 저장
- `SyncService.swift` — 해시 비교·업로드·삭제 표시, 마지막 동기화 시각/에러 상태 노출
- `SyncSettingsView.swift` — 로그인, 지금 동기화, 상태 표시 (상태 탭 또는 운동 탭 툴바에서 진입)
- 기존 변경: 모델 3개에 `syncID` 필드 추가, 앱 시작·포그라운드·운동 저장 지점에서 `SyncService.kick()` 호출

## 검증
- 시뮬레이터에 폰 DB 사본을 넣고 동기화 → Supabase 테이블 행 수·샘플 내용 비교
- 수정/삭제 후 재동기화 → 해당 행만 갱신·deleted 표시되는지
- 비행기 모드에서 저장 → 온라인 복귀 시 올라가는지
