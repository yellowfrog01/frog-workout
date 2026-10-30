# 맥 앱 + 양방향 동기화 설계 (2026-10-30)

## 요구
- 맥에서도 아이폰 앱 기능을 쓴다. 기록 추가·수정 가능. 화면 비율·배치는 맥(데스크톱) 기준.
- 폰·맥 어느 쪽에서 고쳐도 Supabase 를 거쳐 양쪽이 같아진다.

## A. 양방향 동기화 (기존 docs/supabase-sync.md 확장)
- 업로드(기존): 로컬 해시 ≠ 마지막 업로드 해시 → upsert. 업로드 시 `updated_at` = 그 행이 로컬에서 바뀐 것을 처음 감지한 시각(`dirtySince`), 없으면 now.
- **풀(신규)**: `GET ?updated_at=gt.<lastPullAt>&order=updated_at.asc` (deleted 포함) 를 페이지로 받는다.
  - 로컬에 대기 중인 변경이 없는 행 → 원격 값으로 로컬 반영(삽입/수정/삭제). 반영 후 그 행의 업로드 해시 = 원격 내용 해시 (다시 올리지 않게).
  - 로컬에도 대기 중인 변경이 있는 행(충돌) → `updated_at` 비교, 최신 쪽 승리. 로컬이 지면 원격으로 덮고 대기 해제, 이기면 그대로 업로드.
  - lastPullAt = 받은 행들의 최대 updated_at (서버 시각 기준).
- 풀 시점: 앱 활성화, 로그인 직후, 업로드 직후, 앱이 앞에 있는 동안 60초마다. (Supabase Realtime 웹소켓은 이번 범위 밖)
- 서버 `updated_at` 은 클라이언트가 보낸 값을 쓴다. 기기 시계 차이는 감수(같은 사용자 1명, 수 초 오차).
- 진행 중 근력 운동(StrengthDraft)은 동기화 안 함 (기존과 같음).
- 동기화 코드(SupabaseClient/SyncMapper/SyncService)는 iOS·macOS 양쪽에서 컴파일돼야 한다. UIKit 사용은 `#if os(iOS)` 로 감싸고, 앱 활성화 감지는 각 앱의 scenePhase 에서 `SyncService.kick()` 호출로 처리.

## B. 맥 앱
- 별도 Xcode 프로젝트 `WorkoutLogMac/` (XcodeGen `project.yml` 로 생성). 아이폰 프로젝트 파일은 건드리지 않는다.
- 번들 ID `com.gimgeon.WorkoutLogMac`, macOS 14+, SwiftUI, SwiftData. 로컬 실행용(개발 서명).
- **공유 소스**: 아이폰 소스 폴더의 플랫폼 중립 파일을 경로로 참조해 같이 컴파일한다 — 모델(Models, BodyRecord, PlannedWorkout, Telemetry, IntervalDetail, LiftMemo, LiftTiming, LiftPhase 의 모델 부분), 계산(StatusEngine), 동기화(SupabaseClient, SyncMapper, SyncService), Theme(색·폰트). iOS 전용 API 를 쓰는 부분만 `#if os(iOS)` 로 감싼다(동작 변화 없음).
- **제외(맥에서 불가)**: HealthKit 가져오기, 워치 연동, GPS 러닝 기록, 잠금화면 Live Activity, 햅틱.
- **맥 전용 화면** (`WorkoutLogMac/Sources/`):
  - `NavigationSplitView`: 사이드바(기록 · 달력 · 상태 · 체성분 · 동기화) / 목록 / 상세 3단.
  - 기록: 날짜순 목록 + 상세(종목·세트별 무게·횟수·RIR·메모·종목 간 휴식·소요 시간), 편집(종목 추가/삭제, 세트별 무게·횟수, 컨디션, 시간, 메모).
  - 새 기록: 근력(종목·세트 입력, 실시간 진행 없이 사후 입력), 기타 운동(종목·시간).
  - 달력: 월 그리드 크게, 날짜 클릭 시 오른쪽에 그날 기록.
  - 상태: StatusEngine 결과(레벨, 종목별 e1RM·RM표, 추이).
  - 체성분: 인바디 기록 표·추이.
  - 키보드: ⌘N 새 기록, ⌫ 삭제, ⌘R 동기화.
- 데이터: 맥 로컬 SwiftData + 같은 SyncService. 첫 로그인 시 Supabase 에서 전부 내려받는다.

## 검증
- 맥 앱 빌드·실행, 로그인 전 화면 확인.
- 동기화 단위 확인: 업로드/풀/충돌 로직은 Supabase 계정이 생긴 뒤 폰·맥 실제 기록으로 확인.
