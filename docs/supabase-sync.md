# 운동로그 ↔ Supabase 동기화 설계 (오프라인 우선 + 변경 대기열)

## 목표 (사용자 요구, 2026-10-30)
- **Supabase 가 기본 저장소.** 폰(SwiftData)은 오프라인에서도 쓰기 위한 로컬 사본.
- **온라인이면 즉시 반영:** 로컬 변경이 저장되는 순간 Supabase 로 올린다.
- **오프라인이면 대기열:** 바뀐 항목 id 를 폰에 영속 저장(앱 종료에도 유지)하고, 연결이 돌아오면 자동으로 올린다.
- **복원:** 로컬 DB 가 비어 있으면(재설치·기기 교체) Supabase 에서 내려받아 채운다.
- 웹은 2단계(보기 전용). 웹에서 수정하는 양방향은 3단계 — 그때 충돌 규칙(updated_at 최신 우선)을 넣는다.

## 동작
- 변경 감지: `ModelContext.didSave` 알림에서 삽입·수정·삭제된 모델의 syncID 를 대기열(UserDefaults 또는 별도 파일)에 추가 → 즉시 flush 시도.
- 진행 중인 근력 운동(StrengthDraft)은 서버에 올리지 않는다. "운동 완료"로 Session 이 저장될 때 올라간다 (세트 체크마다 요청이 가지 않게).
- 네트워크 감시: `NWPathMonitor` 가 연결 복구를 알리면 flush. 앱 포그라운드 진입 때도 flush.
- flush: 대기열의 각 id 를 현재 로컬 값으로 upsert(없으면 deleted=true). 성공한 id 만 대기열에서 뺀다. 실패하면 남겨 두고 다음 기회에 재시도(지수 백오프).
- 해시 비교는 보조 수단: 처음 연결할 때 기존 전체 기록을 한 번 올리는 용도.

## 결정 사항
| 항목 | 결정 | 이유 |
|---|---|---|
| 클라이언트 | supabase-swift SPM 대신 URLSession 으로 REST 직접 호출 (PostgREST + GoTrue) | 프로젝트 파일에 패키지 의존성을 추가하지 않는다. 필요한 API 는 로그인·토큰 갱신·upsert·update 4개뿐 |
| 인증 | 이메일+비밀번호 1계정. 사용자가 Supabase 대시보드에서 계정 생성 → 앱 설정 화면에서 1회 로그인 | 매직링크는 딥링크 처리가 필요해 1단계에서 제외 |
| 변경 추적 | didSave 알림 → 영속 대기열. 최초 1회만 전체 해시 비교 업로드 | 기존 코드의 모든 수정 지점에 손대지 않아도 된다 |
| 삭제 | 이전에 올렸는데 로컬에 없는 id → 서버에서 `deleted = true` (소프트 삭제) | 실수 복구 가능 |
| 행 식별자 | Session/BodyRecord/PlannedWorkout 에 `syncID: UUID?` 추가. 없으면 첫 동기화 때 발급 | persistentModelID 는 기기 간 안정적 식별자가 아님 |
| 실행 시점 | 저장 즉시 + 연결 복구 시 + 포그라운드 진입 시 | 사용자 요구: 온라인이면 실시간 |
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
