import Foundation

/// 앱에 내장된 운동 프로그램 목록. 공개된 자료를 정리한 것이며 자동 생성된 파일이다.
/// 총 10개.
enum ProgramCatalog {
    static let programs: [WorkoutProgram] = [
        WorkoutProgram(
            id: "stronglifts-5x5",
            title: "스트롱리프트 5×5",
            kind: .strength,
            goal: "기초 근력",
            level: "입문",
            weeks: 12,
            daysPerWeek: 3,
            author: "Mehdi Hadim",
            origin: "stronglifts.com (2007)",
            summary: "바벨 5종목 전신 주3일 입문 루틴",
            detail: "바벨 복합 종목 5개(스쿼트, 벤치프레스, 바벨 로우, 오버헤드 프레스, 데드리프트)만으로 구성된 전신 루틴이다. A와 B 두 가지 운동을 하루 간격으로 번갈아 하며, 스쿼트는 매 세션에 들어간다. 데드리프트만 1세트 5회이고 나머지는 모두 5세트 5회다.\n\n효과의 근거는 단순하다. 세션마다 무게를 조금씩 올리는 선형 증량이고, 초보자는 신경계 적응 덕분에 이 방식으로 수개월간 꾸준히 무게를 올릴 수 있다. 종목 수가 적어 폼을 익히기 쉽고, 기록할 변수도 적어 중도 포기율이 낮다.\n\n웨이트 경험이 없거나 1년 이상 쉰 사람, 기본 3대 운동 자세부터 만들어야 하는 사람에게 적합하다. 주 3일 이상 확보가 어려운 사람에게도 현실적이다.\n\n한계는 분명하다. 스쿼트를 주 3회 5×5로 하는 볼륨은 초보자 기준으로도 과한 편이어서 피로가 누적되고 예상보다 빨리 정체가 온다. 팔, 후면 삼각근, 수직 당기기(풀업·랫풀다운) 볼륨이 사실상 없어 근성장 목적만 보면 균형이 떨어진다. 보통 3~6개월, 증량이 반복적으로 막히는 시점에서 다른 프로그램으로 넘어가는 것이 전제된 입문용 루틴이다.",
            progression: "모든 세트에서 5회를 채우면 다음 세션에 스쿼트·데드리프트는 2.5~5kg, 상체 종목은 1.25~2.5kg 올린다. 같은 무게에서 3회 연속 실패하면 10% 감량 후 다시 올라간다.",
            tags: ["전신", "바벨", "입문", "주3일"],
            days: [
                ProgramDay(label: "A", focus: "전신", note: "월요일 기준. A→B→A 순으로 하루 이상 간격을 둔다.", lifts: [
                    ProgramLift(name: "스쿼트", sets: 5, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "빈 바 또는 추정 1RM의 50%에서 시작"),
                    ProgramLift(name: "벤치프레스", sets: 5, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: ""),
                    ProgramLift(name: "바벨 로우", sets: 5, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: ""),
                ]),
                ProgramDay(label: "B", focus: "전신", note: "수요일 기준.", lifts: [
                    ProgramLift(name: "스쿼트", sets: 5, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: ""),
                    ProgramLift(name: "오버헤드 프레스", sets: 5, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: ""),
                    ProgramLift(name: "데드리프트", sets: 1, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 300, note: "작업세트 1세트만. 워밍업은 별도"),
                ]),
                ProgramDay(label: "A", focus: "전신", note: "금요일 기준. 다음 주는 B→A→B로 시작한다.", lifts: [
                    ProgramLift(name: "스쿼트", sets: 5, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: ""),
                    ProgramLift(name: "벤치프레스", sets: 5, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: ""),
                    ProgramLift(name: "바벨 로우", sets: 5, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: ""),
                ]),
            ],
            reviews: [
                ProgramReview(source: "r/Fitness 위키", rating: 4, text: "입문자용 선형 증량 루틴으로 널리 검증됐고 시작 장벽이 낮다는 평가를 받는다. 다만 스쿼트를 주 3회 5×5로 하는 볼륨이 과해 피로가 쌓이고 정체가 빨리 온다는 지적이 함께 붙는다. 팔·후면 삼각근·수직 당기기 볼륨이 거의 없어 근성장만 보면 보조 종목을 따로 추가해야 한다."),
                ProgramReview(source: "PowerliftingToWin (Izzy Narvaez)", rating: 2, text: "파워리프팅 목적으로는 '단순히 비효율적'이라고 결론 내린 리뷰다. 스쿼트 볼륨이 데드리프트의 10배에 달하는 불균형, 초보자에게 5×5보다 3×5가 더 적합하다는 점을 근거로 든다. 반면 프로그램 자체가 동작하지 않는다는 주장은 아니며, 더 나은 대안이 있다는 취지다."),
                ProgramReview(source: "Legion Athletics 프로그램 가이드", rating: 3, text: "종목이 적고 기록이 단순해 운동 습관을 만드는 데 효과적이라고 평가한다. 단점으로는 상체 보조 볼륨 부재와 증량 정체 후 대응 수단이 10% 감량뿐이라는 점을 든다. 3~6개월 뒤에는 중급 프로그램으로 넘어가는 것을 전제로 추천한다."),
            ]),
        WorkoutProgram(
            id: "gzclp",
            title: "GZCLP",
            kind: .strength,
            goal: "근력 + 근성장",
            level: "입문",
            weeks: 16,
            daysPerWeek: 4,
            author: "Cody Lefever",
            origin: "r/gzcl (GZCL 메소드의 선형 증량 파생판)",
            summary: "3단 티어 구조 선형 증량 4분할",
            detail: "한 세션을 세 개의 티어로 나눈다. T1은 그날의 메인 리프트로 5세트 3회(마지막 세트 AMRAP), T2는 다른 복합 종목을 3세트 10회, T3는 보조 종목을 3세트 15회(마지막 세트 AMRAP)로 한다. 스쿼트·벤치프레스·데드리프트·오버헤드 프레스 4종목이 각각 한 번은 T1, 한 번은 T2로 돌아가므로 4일이 한 사이클이다.\n\n설계 원칙은 T1:T2:T3 반복수 비율을 대략 1:2:3으로 맞추는 것이다. 가장 무거운 구간에 볼륨이 가장 적고, 가벼운 구간에 볼륨이 가장 많다. 같은 종목을 고중량 저반복과 중량 고반복 두 방식으로 다루기 때문에 근력과 근육량을 동시에 가져가고, 5×5류보다 정체 지점이 늦게 온다.\n\n5×5류 입문 루틴을 3~6개월 돌려 세션마다 증량이 막히기 시작한 사람에게 적합하다. 주 4일 확보가 가능하고 스프레드시트나 앱으로 기록을 관리할 의지가 있는 경우에 잘 맞는다.\n\n주의점은 세 가지다. 첫째, 세션이 60~80분 걸리고 T1이 10×1 단계까지 내려가면 1시간 20분을 넘기기도 한다. 둘째, 단계 하강 규칙(T1 5×3→6×2→10×1, T2 3×10→3×8→3×6)이 5×5보다 복잡해 종이 기록으로 관리하기 번거롭다. 셋째, T2의 3세트 10회는 체력 소모가 커서 칼로리 적자 상태에서는 진행이 거의 멈춘다.",
            progression: "T1·T2는 지정 세트를 모두 채우면 다음 세션에 상체 2.5kg / 하체 5kg 증량하고, 실패하면 렙 스킴 단계를 한 칸 내려 같은 무게로 이어간다. T3는 마지막 AMRAP에서 25회 이상 나오면 2.5kg 올린다.",
            tags: ["전신", "바벨", "AMRAP", "주4일"],
            days: [
                ProgramDay(label: "A1", focus: "스쿼트 중심", note: "T1 시작 무게는 해당 종목 5RM 정도.", lifts: [
                    ProgramLift(name: "스쿼트", sets: 5, reps: 3, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "T1. 마지막 세트는 AMRAP"),
                    ProgramLift(name: "벤치프레스", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "T2"),
                    ProgramLift(name: "랫풀다운", sets: 3, reps: 15, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 90, note: "T3. 마지막 세트는 AMRAP"),
                ]),
                ProgramDay(label: "A2", focus: "오버헤드 프레스 중심", note: "", lifts: [
                    ProgramLift(name: "오버헤드 프레스", sets: 5, reps: 3, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "T1. 마지막 세트는 AMRAP"),
                    ProgramLift(name: "데드리프트", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 150, note: "T2. 가장 힘든 세션"),
                    ProgramLift(name: "바벨 로우", sets: 3, reps: 15, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 90, note: "T3. 덤벨 로우로 대체 가능"),
                ]),
                ProgramDay(label: "B1", focus: "벤치프레스 중심", note: "", lifts: [
                    ProgramLift(name: "벤치프레스", sets: 5, reps: 3, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "T1. 마지막 세트는 AMRAP"),
                    ProgramLift(name: "스쿼트", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 150, note: "T2"),
                    ProgramLift(name: "랫풀다운", sets: 3, reps: 15, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 90, note: "T3. 마지막 세트는 AMRAP"),
                ]),
                ProgramDay(label: "B2", focus: "데드리프트 중심", note: "", lifts: [
                    ProgramLift(name: "데드리프트", sets: 5, reps: 3, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 240, note: "T1. 마지막 세트는 AMRAP"),
                    ProgramLift(name: "오버헤드 프레스", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "T2"),
                    ProgramLift(name: "바벨 로우", sets: 3, reps: 15, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 90, note: "T3. 마지막 세트는 AMRAP"),
                ]),
            ],
            reviews: [
                ProgramReview(source: "r/gzcl 프로그램 리뷰 스레드", rating: 4, text: "네 종목을 저반복 고중량과 고반복 두 방식으로 굴려 단순 5×5보다 지루하지 않고, 정체가 와도 단계를 내려 계속 진행할 수 있다는 점을 장점으로 꼽는다. 단점은 세션 길이로, 60~80분이 기본이고 T1이 10×1 단계에 들어가면 1시간 20분을 넘긴다는 후기가 많다."),
                ProgramReview(source: "Lift Vault GZCLP 가이드", rating: 4, text: "단순 입문 루틴을 3~6개월 돌린 뒤 넘어오기 좋은 다음 단계로 평가한다. 다만 T1/T2/T3의 단계 하강 규칙 때문에 계산이 늘어나 스프레드시트나 앱 없이 관리하기 번거롭다는 점을 지적한다."),
                ProgramReview(source: "Boostcamp 사용자 리뷰", rating: 3, text: "볼륨과 빈도 배분이 균형 잡혀 있고 종목마다 자극이 다양하다는 평이 많다. 반면 잉여 칼로리 없이는 증량 속도가 급격히 떨어지고, 감량기에 T2 3세트 10회를 소화하기가 매우 힘들다는 후기가 반복된다."),
            ]),
        WorkoutProgram(
            id: "reddit-ppl-metallicadpa",
            title: "레딧 PPL (메탈리카드파 6일)",
            kind: .strength,
            goal: "근성장",
            level: "중급",
            weeks: 0,
            daysPerWeek: 6,
            author: "u/metallicadpa",
            origin: "r/Fitness (2015)",
            summary: "주6일 밀기·당기기·하체 분할",
            detail: "당기기(Pull) → 밀기(Push) → 하체(Legs)를 두 바퀴 돌고 하루 쉬는 주 6일 분할이다. 각 세션의 첫 종목은 복합 운동으로 마지막 세트를 AMRAP으로 하는 선형 증량 구간이고, 이후는 3세트 8~12회의 보조 종목으로 볼륨을 채운다. 당기기 날은 데드리프트 중심과 바벨 로우 중심이, 밀기 날은 벤치프레스 중심과 오버헤드 프레스 중심이 번갈아 나온다.\n\n근성장에 유효한 이유는 빈도와 볼륨이다. 주요 근육군을 주 2회 자극하고, 세션당 17~23 작업세트로 부위별 주간 볼륨이 충분하다. 동시에 복합 종목은 여전히 세션마다 증량하므로 근력도 함께 올라간다. 삼두, 이두, 측면 삼각근, 후면 삼각근에 직접 볼륨이 배정된 점이 5×5류와 가장 큰 차이다.\n\n입문 선형 증량 프로그램을 끝낸 뒤 체격을 키우려는 사람, 주 6일을 규칙적으로 확보할 수 있는 사람에게 적합하다.\n\n한계는 스케줄과 회복이다. 주 6일 고정이라 일정 변수에 취약하고 세션이 60~90분 걸린다. 스쿼트 직접 작업세트가 세션당 3세트뿐이라 하체 자극이 부족하다는 지적이 흔하며, 레그 프레스·루마니안 데드리프트로 보완하는 구조다. 완전 초보가 바로 시작하면 회복이 따라오지 않아 보조 볼륨을 소화하기 전에 복합 종목 증량이 먼저 멈춘다.",
            progression: "복합 종목은 마지막 AMRAP 세트에서 목표 반복을 채우면 다음 세션에 벤치·오버헤드 프레스·로우·스쿼트 2.5kg, 데드리프트 5kg 증량한다. 보조 종목은 지정 구간 하단에서 상단까지 반복을 늘린 뒤 증량하고, 3회 연속 실패 시 10% 감량한다.",
            tags: ["분할", "근성장", "주6일", "바벨", "머신"],
            days: [
                ProgramDay(label: "Pull 1", focus: "등·이두", note: "데드리프트 중심 당기기 날.", lifts: [
                    ProgramLift(name: "데드리프트", sets: 1, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 300, note: "1세트 5회+ (AMRAP)"),
                    ProgramLift(name: "랫풀다운", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "8~12회 구간"),
                    ProgramLift(name: "시티드 케이블 로우", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "8~12회 구간"),
                    ProgramLift(name: "페이스 풀", sets: 5, reps: 15, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 60, note: "15~20회 구간"),
                    ProgramLift(name: "해머 컬", sets: 4, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 60, note: "8~12회, 페이스 풀과 슈퍼세트 가능"),
                    ProgramLift(name: "덤벨 컬", sets: 4, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 60, note: "8~12회 구간"),
                ]),
                ProgramDay(label: "Push 1", focus: "가슴·어깨·삼두", note: "벤치프레스 중심 밀기 날.", lifts: [
                    ProgramLift(name: "벤치프레스", sets: 5, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 240, note: "4세트 5회 + 마지막 1세트 AMRAP"),
                    ProgramLift(name: "오버헤드 프레스", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "보조 강도. 8~12회"),
                    ProgramLift(name: "인클라인 덤벨 프레스", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "8~12회 구간"),
                    ProgramLift(name: "트라이셉 푸시다운", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 60, note: "8~12회 구간"),
                    ProgramLift(name: "오버헤드 트라이셉 익스텐션", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 60, note: "8~12회 구간"),
                    ProgramLift(name: "사이드 레터럴 레이즈", sets: 6, reps: 15, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 45, note: "15~20회. 삼두 종목과 슈퍼세트로 3+3세트"),
                ]),
                ProgramDay(label: "Legs 1", focus: "하체", note: "", lifts: [
                    ProgramLift(name: "스쿼트", sets: 3, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 240, note: "2세트 5회 + 마지막 1세트 AMRAP"),
                    ProgramLift(name: "루마니안 데드리프트", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 150, note: "8~12회 구간"),
                    ProgramLift(name: "레그 프레스", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "8~12회 구간"),
                    ProgramLift(name: "시티드 레그 컬", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 90, note: "8~12회 구간"),
                    ProgramLift(name: "스탠딩 카프 레이즈", sets: 5, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 60, note: "8~12회, 최상단에서 정지"),
                ]),
                ProgramDay(label: "Pull 2", focus: "등·이두", note: "바벨 로우 중심 당기기 날.", lifts: [
                    ProgramLift(name: "바벨 로우", sets: 5, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 240, note: "4세트 5회 + 마지막 1세트 AMRAP"),
                    ProgramLift(name: "랫풀다운", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "8~12회 구간"),
                    ProgramLift(name: "시티드 케이블 로우", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "8~12회 구간"),
                    ProgramLift(name: "페이스 풀", sets: 5, reps: 15, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 60, note: "15~20회 구간"),
                    ProgramLift(name: "해머 컬", sets: 4, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 60, note: "8~12회 구간"),
                    ProgramLift(name: "덤벨 컬", sets: 4, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 60, note: "8~12회 구간"),
                ]),
                ProgramDay(label: "Push 2", focus: "어깨·가슴·삼두", note: "오버헤드 프레스 중심 밀기 날.", lifts: [
                    ProgramLift(name: "오버헤드 프레스", sets: 5, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 240, note: "4세트 5회 + 마지막 1세트 AMRAP"),
                    ProgramLift(name: "벤치프레스", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "보조 강도. 8~12회"),
                    ProgramLift(name: "인클라인 덤벨 프레스", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "8~12회 구간"),
                    ProgramLift(name: "트라이셉 푸시다운", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 60, note: "8~12회 구간"),
                    ProgramLift(name: "오버헤드 트라이셉 익스텐션", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 60, note: "8~12회 구간"),
                    ProgramLift(name: "사이드 레터럴 레이즈", sets: 6, reps: 15, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 45, note: "15~20회. 삼두 종목과 슈퍼세트로 3+3세트"),
                ]),
                ProgramDay(label: "Legs 2", focus: "하체", note: "다음 날은 휴식.", lifts: [
                    ProgramLift(name: "스쿼트", sets: 3, reps: 5, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 240, note: "2세트 5회 + 마지막 1세트 AMRAP"),
                    ProgramLift(name: "루마니안 데드리프트", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 150, note: "8~12회 구간"),
                    ProgramLift(name: "레그 프레스", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "8~12회 구간"),
                    ProgramLift(name: "시티드 레그 컬", sets: 3, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 90, note: "8~12회 구간"),
                    ProgramLift(name: "스탠딩 카프 레이즈", sets: 5, reps: 8, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 60, note: "8~12회 구간"),
                ]),
            ],
            reviews: [
                ProgramReview(source: "r/Fitness 위키", rating: 4, text: "위키가 대표 PPL로 올려둔 무료 루틴이다. 복합 종목 선형 증량과 부위별 보조 볼륨을 함께 갖춰 근성장 목적에 잘 맞는다는 평가다. 단점은 주 6일 고정 스케줄이라 일정 변수에 취약하고 세션이 60~90분 걸린다는 점이다."),
                ProgramReview(source: "Lift Vault 프로그램 노트", rating: 4, text: "스프레드시트 지원이 잘 되어 있고 가장 많이 실행된 무료 PPL 중 하나로 소개한다. 반복적으로 나오는 단점은 하체 볼륨으로, 스쿼트 직접 작업세트가 세션당 3세트뿐이라 레그 프레스와 루마니안 데드리프트에 크게 의존한다는 지적이다."),
                ProgramReview(source: "Liftosaur 프로그램 가이드", rating: 3, text: "세션당 17~23 작업세트는 중급자 수준의 부하라고 명시한다. 팔과 측면 삼각근 볼륨은 넉넉하지만, 입문자가 바로 시작하면 회복이 부족해 보조 볼륨보다 복합 종목 증량이 먼저 멈춘다는 점을 주의사항으로 든다."),
            ]),
        WorkoutProgram(
            id: "531-for-beginners",
            title: "5/3/1 포 비기너스",
            kind: .strength,
            goal: "근력",
            level: "중급",
            weeks: 12,
            daysPerWeek: 3,
            author: "Jim Wendler",
            origin: "5/3/1 (2009) 의 입문자용 템플릿",
            summary: "트레이닝 맥스 기반 3주 파동 증량",
            detail: "실제 1RM이 아니라 트레이닝 맥스(추정 1RM의 90%)를 기준으로 무게를 계산한다. 3주가 한 사이클이며 주차별로 강도가 달라진다. 1주차는 65/75/85%, 2주차는 70/80/90%, 3주차는 75/85/95%로 올라가고 마지막 세트는 AMRAP이다. 이어서 그날 첫 세트 무게(FSL)로 5세트 5회를 추가한다. 하루에 메인 리프트 두 개를 하므로 주 3일로 4대 종목을 모두 커버한다.\n\n효과의 핵심은 강도 관리다. 트레이닝 맥스를 실제 능력보다 낮게 잡기 때문에 대부분의 세트가 여유 있게 끝나고, AMRAP으로 그날의 컨디션을 반영한다. 증량은 사이클 단위로 이뤄져 회복 시간이 충분하고, 그래서 선형 프로그램처럼 매주 실패와 감량을 반복하지 않는다. FSL 5×5가 볼륨을 담당해 폼 반복 횟수도 많다.\n\n세션마다 증량이 더 이상 불가능해진 사람, 또는 부상 이력이 있어 실패 세트를 피하고 싶은 사람에게 적합하다. 보조운동(밀기 / 당기기 / 한다리·코어 각 카테고리에서 하나, 합계 50~100회)이 자유 선택이라 약점 보완이 쉽다.\n\n주의점은 두 가지다. 첫째, 진짜 초보에게는 증량 속도가 느리다. 선형 프로그램이 12~16주 만에 낼 수 있는 상승분을 5/3/1은 1년에 걸쳐 내므로, 초기 급성장 구간을 낭비할 수 있다는 비판이 지배적이다. 둘째, 하루 메인 리프트 두 개 + 각각 FSL 5×5이므로 세션 볼륨과 소요 시간이 상당하다. 트레이닝 맥스를 높게 잡으면 곧바로 무너진다.",
            progression: "3주 사이클이 끝나면 AMRAP 성적과 무관하게 상체 트레이닝 맥스에 2.5kg, 하체에 5kg를 더한다. 10주 단위로 트레이닝 맥스 테스트를 해서 실제 상승분을 확인하고 필요하면 재설정한다.",
            tags: ["바벨", "근력", "퍼센트 기반", "주3일"],
            days: [
                ProgramDay(label: "1일차", focus: "스쿼트 + 벤치프레스", note: "표기 %는 모두 트레이닝 맥스(추정 1RM의 90%) 기준. 1주차 수치.", lifts: [
                    ProgramLift(name: "스쿼트", sets: 3, reps: 5, pct1RM: 0.85, rir: nil, bw: false, uni: false, restSeconds: 180, note: "1주차 65%×5, 75%×5, 85%×5+ (마지막 AMRAP). 2주차 70/80/90%×3, 3주차 75/85/95%×5/3/1+"),
                    ProgramLift(name: "스쿼트 (FSL 5×5)", sets: 5, reps: 5, pct1RM: 0.65, rir: nil, bw: false, uni: false, restSeconds: 120, note: "그날 첫 세트 무게로 5×5. 2주차 70%, 3주차 75%"),
                    ProgramLift(name: "벤치프레스", sets: 3, reps: 5, pct1RM: 0.85, rir: nil, bw: false, uni: false, restSeconds: 180, note: "메인 리프트 2. 주차별 % 동일"),
                    ProgramLift(name: "벤치프레스 (FSL 5×5)", sets: 5, reps: 5, pct1RM: 0.65, rir: nil, bw: false, uni: false, restSeconds: 120, note: ""),
                    ProgramLift(name: "딥스", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: true, uni: false, restSeconds: 90, note: "밀기 보조. 카테고리 내 자유 선택"),
                    ProgramLift(name: "친업", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: true, uni: false, restSeconds: 90, note: "당기기 보조"),
                    ProgramLift(name: "덤벨 런지", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: true, restSeconds: 90, note: "한다리·코어 보조. 보조 3종 합계 50~100회"),
                ]),
                ProgramDay(label: "2일차", focus: "데드리프트 + 오버헤드 프레스", note: "1일차와 최소 하루 간격.", lifts: [
                    ProgramLift(name: "데드리프트", sets: 3, reps: 5, pct1RM: 0.85, rir: nil, bw: false, uni: false, restSeconds: 240, note: "1주차 65/75/85%, 마지막 세트 AMRAP"),
                    ProgramLift(name: "데드리프트 (FSL 5×5)", sets: 5, reps: 5, pct1RM: 0.65, rir: nil, bw: false, uni: false, restSeconds: 150, note: "폼 유지가 어려우면 3×5로 줄여도 된다"),
                    ProgramLift(name: "오버헤드 프레스", sets: 3, reps: 5, pct1RM: 0.85, rir: nil, bw: false, uni: false, restSeconds: 180, note: "메인 리프트 2"),
                    ProgramLift(name: "오버헤드 프레스 (FSL 5×5)", sets: 5, reps: 5, pct1RM: 0.65, rir: nil, bw: false, uni: false, restSeconds: 120, note: ""),
                    ProgramLift(name: "푸시업", sets: 3, reps: 15, pct1RM: nil, rir: nil, bw: true, uni: false, restSeconds: 60, note: "밀기 보조"),
                    ProgramLift(name: "랫풀다운", sets: 3, reps: 12, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 90, note: "당기기 보조"),
                    ProgramLift(name: "행잉 레그 레이즈", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: true, uni: false, restSeconds: 60, note: "코어 보조"),
                ]),
                ProgramDay(label: "3일차", focus: "벤치프레스 + 스쿼트", note: "같은 종목이 주 2회 들어오되 순서가 바뀐다.", lifts: [
                    ProgramLift(name: "벤치프레스", sets: 3, reps: 5, pct1RM: 0.85, rir: nil, bw: false, uni: false, restSeconds: 180, note: "1주차 65/75/85%, 마지막 세트 AMRAP"),
                    ProgramLift(name: "벤치프레스 (FSL 5×5)", sets: 5, reps: 5, pct1RM: 0.65, rir: nil, bw: false, uni: false, restSeconds: 120, note: ""),
                    ProgramLift(name: "스쿼트", sets: 3, reps: 5, pct1RM: 0.85, rir: nil, bw: false, uni: false, restSeconds: 180, note: "메인 리프트 2"),
                    ProgramLift(name: "스쿼트 (FSL 5×5)", sets: 5, reps: 5, pct1RM: 0.65, rir: nil, bw: false, uni: false, restSeconds: 120, note: ""),
                    ProgramLift(name: "딥스", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: true, uni: false, restSeconds: 90, note: "밀기 보조"),
                    ProgramLift(name: "바벨 로우", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 90, note: "당기기 보조"),
                    ProgramLift(name: "불가리안 스플릿 스쿼트", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: true, restSeconds: 90, note: "한다리 보조"),
                ]),
            ],
            reviews: [
                ProgramReview(source: "r/Fitness 위키", rating: 4, text: "트레이닝 맥스를 낮게 잡고 시작하므로 폼을 다듬으면서 오래 진행할 수 있고 정체와 감량 사이클이 드물다는 점을 장점으로 든다. 단점은 진짜 초보에게는 증량 속도가 선형 프로그램보다 느려 초기 급성장 구간을 활용하지 못한다는 것이다."),
                ProgramReview(source: "Starting Strength 포럼", rating: 2, text: "5/3/1은 세션마다 증량이 불가능해진 중급자용이라는 입장이 지배적이다. 초보가 바로 시작하면 선형 프로그램이 12~16주에 낼 상승분을 1년에 걸쳐 내게 된다는 비판이 반복된다. 프로그램 자체의 완성도는 인정하지만 적용 시점이 틀렸다는 논지다."),
                ProgramReview(source: "Empire Barbell 프로그램 리뷰", rating: 4, text: "AMRAP으로 컨디션을 반영하고 보조운동 선택이 자유로워 약점 보완과 장기 운영에 유리하다고 평가한다. 단점으로는 하루 메인 리프트 두 개에 각각 FSL 5×5가 붙어 세션 볼륨과 소요 시간이 상당하다는 점, 트레이닝 맥스를 과하게 잡으면 몇 사이클 안에 무너진다는 점을 든다."),
            ]),
        WorkoutProgram(
            id: "lyle-generic-bulking",
            title: "라일 맥도날드 제네릭 벌킹 루틴",
            kind: .strength,
            goal: "근성장 (벌크)",
            level: "중급",
            weeks: 8,
            daysPerWeek: 4,
            author: "Lyle McDonald",
            origin: "bodyrecomposition.com 포럼 (2008~2009)",
            summary: "상·하체 주4일, 부위당 주2회",
            detail: "상체와 하체를 각각 주 2회 훈련하는 4일 분할이다. 보통 월·화·목·금으로 배치하며 두 상체 세션, 두 하체 세션의 구성은 동일하다. 세션마다 복합 종목 3~4개와 고립 종목 2~3개를 하고, 반복수는 메인 6~8회, 보조 10~12회, 고립 12~15회로 구간이 다르다.\n\n설계 의도는 저볼륨 방식(예: 도그크랩)과 고볼륨 보디빌딩 분할 사이를 메우는 것이다. 주요 근육군을 주당 10~14세트로 훈련하는데, 이는 현재 근성장 연구가 지지하는 범위에 들어간다. 반복 구간 안에서 반복수를 먼저 늘리고 상단을 채운 뒤 무게를 올리는 이중 진행을 쓰므로, 매 세션 증량이 불가능해진 중급자도 진행 지표를 유지할 수 있다.\n\n선형 증량이 끝난 뒤 체중을 늘리면서 근육량을 키우려는 중급자용이다. 주당 0.25~0.5kg 정도의 체중 증가를 전제로 설계되었다.\n\n주의점. 반복수를 6~8, 10~12처럼 범위로만 지정해 세트마다 판단이 필요하고(라일 본인은 이를 의도된 설계라고 밝혔다) 초보에게는 기준이 모호하다. 팔과 어깨 직접 볼륨이 적어 복합 종목의 간접 자극에 의존하는데, 이 부분은 오래 논쟁된 지점이다. 또 6~8주 사이클 후 디로드를 반드시 지켜야 하며, 이틀 연속 훈련이 두 번 들어가 하체 세션 후 상체 회복이 겹칠 수 있다.",
            progression: "이중 진행. 지정 반복 구간의 하단에서 시작해 모든 세트에서 상단을 채우면 2.5kg 올리고 다시 하단부터 시작한다. 6~8주 사이클을 마치면 1~2주 디로드를 하고, 새 사이클 첫 2주는 작업 무게의 85~95%로 시작한다.",
            tags: ["상하체 분할", "근성장", "이중 진행", "주4일"],
            days: [
                ProgramDay(label: "상체 1", focus: "상체 전체", note: "월요일 기준.", lifts: [
                    ProgramLift(name: "벤치프레스", sets: 4, reps: 6, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "6~8회 구간"),
                    ProgramLift(name: "바벨 로우", sets: 3, reps: 6, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "6~8회 구간"),
                    ProgramLift(name: "오버헤드 프레스", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "10~12회 구간. 덤벨로도 가능"),
                    ProgramLift(name: "친업", sets: 2, reps: 10, pct1RM: nil, rir: nil, bw: true, uni: false, restSeconds: 120, note: "10~12회. 어려우면 랫풀다운으로 대체"),
                    ProgramLift(name: "스컬크러셔", sets: 2, reps: 12, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 90, note: "12~15회 구간"),
                    ProgramLift(name: "해머 컬", sets: 2, reps: 12, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 90, note: "12~15회 구간"),
                ]),
                ProgramDay(label: "하체 1", focus: "하체 전체", note: "화요일 기준.", lifts: [
                    ProgramLift(name: "스쿼트", sets: 4, reps: 6, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "6~8회 구간"),
                    ProgramLift(name: "루마니안 데드리프트", sets: 3, reps: 6, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "6~8회 구간 (스티프 레그 데드리프트)"),
                    ProgramLift(name: "레그 프레스", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "10~12회 구간"),
                    ProgramLift(name: "시티드 레그 컬", sets: 2, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "10~12회 구간"),
                    ProgramLift(name: "스탠딩 카프 레이즈", sets: 3, reps: 6, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "6~8회 구간"),
                    ProgramLift(name: "시티드 카프 레이즈", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "10~12회 구간"),
                ]),
                ProgramDay(label: "상체 2", focus: "상체 전체", note: "목요일 기준. 상체 1과 동일 구성.", lifts: [
                    ProgramLift(name: "벤치프레스", sets: 4, reps: 6, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "6~8회 구간"),
                    ProgramLift(name: "바벨 로우", sets: 3, reps: 6, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "6~8회 구간"),
                    ProgramLift(name: "오버헤드 프레스", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "10~12회 구간"),
                    ProgramLift(name: "친업", sets: 2, reps: 10, pct1RM: nil, rir: nil, bw: true, uni: false, restSeconds: 120, note: "10~12회 구간"),
                    ProgramLift(name: "스컬크러셔", sets: 2, reps: 12, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 90, note: "12~15회 구간"),
                    ProgramLift(name: "해머 컬", sets: 2, reps: 12, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 90, note: "12~15회 구간"),
                ]),
                ProgramDay(label: "하체 2", focus: "하체 전체", note: "금요일 기준. 하체 1과 동일 구성.", lifts: [
                    ProgramLift(name: "스쿼트", sets: 4, reps: 6, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "6~8회 구간"),
                    ProgramLift(name: "루마니안 데드리프트", sets: 3, reps: 6, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "6~8회 구간"),
                    ProgramLift(name: "레그 프레스", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "10~12회 구간"),
                    ProgramLift(name: "시티드 레그 컬", sets: 2, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "10~12회 구간"),
                    ProgramLift(name: "스탠딩 카프 레이즈", sets: 3, reps: 6, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 180, note: "6~8회 구간"),
                    ProgramLift(name: "시티드 카프 레이즈", sets: 3, reps: 10, pct1RM: nil, rir: nil, bw: false, uni: false, restSeconds: 120, note: "10~12회 구간"),
                ]),
            ],
            reviews: [
                ProgramReview(source: "Legion Athletics 프로그램 가이드", rating: 4, text: "주요 근육군을 주 2회, 주당 10~14세트로 훈련해 근성장 연구가 지지하는 볼륨 범위에 들어간다고 평가한다. 단점은 반복수를 범위로만 지정해 세트마다 하단/상단을 스스로 판단해야 하고, 경험이 적으면 기준이 모호하다는 점이다."),
                ProgramReview(source: "JCD Fitness (GBR FAQ 정리)", rating: 4, text: "저볼륨 방식과 고볼륨 보디빌딩 분할 사이를 노린 설계로 중급자 벌킹에 합리적이라고 본다. 반복적으로 제기되는 단점은 팔과 어깨의 직접 볼륨이 적다는 것이며, 복합 종목의 간접 자극만으로 충분한지는 오래 논쟁된 부분이다."),
                ProgramReview(source: "Liftosaur 프로그램 가이드", rating: 3, text: "구성이 단순하고 이중 진행 규칙이 명확해 기록 관리가 쉽다고 소개한다. 주의점으로는 월·화·목·금 배치에서 이틀 연속 훈련이 두 번 들어가 하체 세션 후 상체 회복이 겹치는 점, 6~8주 사이클마다 디로드를 건너뛰면 무게가 정체된다는 점을 든다."),
            ]),
        WorkoutProgram(
            id: "couch-to-5k",
            title: "카우치 투 5K (C25K)",
            kind: .cardio,
            goal: "러닝 입문 · 30분 연속 달리기",
            level: "입문",
            weeks: 9,
            daysPerWeek: 3,
            author: "Josh Clark (1996년 고안)",
            origin: "NHS Better Health 공식 Couch to 5K 플랜",
            summary: "9주에 30분 연속 달리기까지",
            detail: "걷기와 달리기를 번갈아 하는 것으로 시작해 9주 뒤 30분을 쉬지 않고 달리는 것을 목표로 하는 주 3회 플랜이다. 1996년 Josh Clark이 만들었고, 영국 NHS가 Better Health 프로그램에서 무료 오디오 가이드와 함께 공식 배포한다. 1주차는 5분 빠르게 걷기로 워밍업한 뒤 1분 달리기 / 1분 30초 걷기를 8회 반복하고, 9주차에는 세 번의 세션 모두 30분 연속 달리기다.\n\n효과의 핵심은 걷기 구간으로 심폐 부하를 쪼개서 점진적으로 늘리는 것이다. 주 3회를 격일로 배치해 회복일을 강제하며, 주당 실제 달리기 시간이 1주차 약 9분에서 9주차 90분으로 늘어난다. NHS도 휴식일이 달리기만큼 중요하다고 명시한다.\n\n달리기 경험이 전혀 없거나 오래 쉬었던 사람, 5K 완주가 첫 목표인 사람에게 맞는다. 별도 장비나 심박계가 필요 없고 시간만 재면 된다.\n\n주의할 점은 4주차에서 5주차 3회로 넘어가는 구간이다. 직전까지 최대 8분 연속이었던 것이 갑자기 20분 연속으로 뛴다. 심폐 능력은 몇 주 만에 적응하지만 힘줄·건·뼈는 그보다 훨씬 느리게 적응하기 때문에, 이 지점에서 정강이 통증과 중도 포기 보고가 몰린다. NHS 공식 안내도 필요하면 같은 주나 같은 세션을 반복해도 된다고 적어 두었다. 체중이 많거나 40대 이상이면 각 주를 두 번씩 하는 편이 안전하다.\n\n한계는 페이스·거리 목표가 없다는 점이다. 9주차의 30분 달리기가 반드시 5km가 되지는 않으며(느린 경우 4km 내외), 기록을 줄이는 훈련으로는 쓸 수 없다. 완주 이후에는 별도의 5K/10K 플랜으로 넘어가야 한다.",
            progression: "매주 달리기 구간을 늘리고 걷기 구간을 줄인다. 1주차 1분 달리기/1분 30초 걷기 8회 → 5주차 3회 20분 연속 → 6주차 3회 25분 → 9주차 30분 연속. 힘들면 같은 주를 반복하는 것이 공식 권장이다.",
            tags: ["러닝", "입문", "걷기/달리기", "5K"],
            days: [
                ProgramDay(label: "1일차", focus: "달리기/걷기", note: "5분 빠르게 걷기 워밍업, 5분 걷기 쿨다운", cardio:
                    ProgramCardio(mode: .interval, workSeconds: 300, intensityPct: 70, restSeconds: 180, recoveryPaceSec: nil, sets: 3, minutes: 0, paceSec: nil, note: "달리기/걷기 — 5분 달리기 3회, 사이에 3분 걷기")),
                ProgramDay(label: "2일차", focus: "달리기/걷기", note: "5분 빠르게 걷기 워밍업, 5분 걷기 쿨다운", cardio:
                    ProgramCardio(mode: .interval, workSeconds: 480, intensityPct: 70, restSeconds: 300, recoveryPaceSec: nil, sets: 2, minutes: 0, paceSec: nil, note: "달리기/걷기 — 8분 달리기 2회, 사이에 5분 걷기")),
                ProgramDay(label: "3일차", focus: "연속 달리기", note: "5주차의 분기점. 5분 걷기 워밍업 후 걷기 없이 달린다", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 72, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 20, paceSec: nil, note: "첫 20분 연속 달리기. 느려도 멈추지 않는 것이 목표")),
            ],
            reviews: [
                ProgramReview(source: "NHS Better Health 공식 안내", rating: 4, text: "휴식일이 달리기만큼 중요하다고 강조하며, 필요하면 같은 주나 세션을 반복해도 된다고 명시한다. 즉 9주는 최소 기간일 뿐이며 그대로 지키라는 뜻이 아니다."),
                ProgramReview(source: "r/running 위키 (초보자 플랜 섹션)", rating: 4, text: "달리기를 시작하는 가장 흔하고 무난한 출발점으로 소개된다. 다만 페이스 개념이 없어 초보가 너무 빨리 달리다 지치는 문제가 반복 지적되며, 완주 후에는 별도 5K/10K 플랜으로 옮겨가라고 안내한다."),
                ProgramReview(source: "None to Run 블로그 (5주차 분석)", rating: 3, text: "8분 연속에서 20분 연속으로 뛰는 5주차 3회가 70% 이상의 급증이며, 중도 포기와 정강이 통증이 여기 집중된다고 분석한다. 심폐 적응 속도와 결합조직 적응 속도의 불일치를 원인으로 지적하고 더 완만한 진행을 권한다."),
            ]),
        WorkoutProgram(
            id: "norwegian-4x4",
            title: "노르웨이식 4×4 인터벌",
            kind: .cardio,
            goal: "VO2max 향상",
            level: "중급",
            weeks: 8,
            daysPerWeek: 3,
            author: "Ulrik Wisløff 연구팀 (NTNU 심장운동연구그룹, CERG)",
            origin: "Helgerud et al., Med Sci Sports Exerc 2007;39(4):665-671",
            summary: "4분×4세트로 VO2max 올리기",
            detail: "10분 워밍업 뒤 4분 동안 최대심박의 90~95%로 달리고 3분 동안 70% 수준으로 회복하는 것을 4세트 반복한 다음 5~10분 쿨다운하는 세션이다. 전체 40분 내외이고 실제 고강도 구간은 16분이다. 노르웨이 과학기술대학교(NTNU) 심장운동연구그룹에서 Ulrik Wisløff 팀이 정립했다.\n\n근거는 Helgerud 2007 연구다. 중등도로 훈련된 남성 40명을 4군으로 나눠 총 운동량을 같게 맞추고 8주간 주 3회 훈련시켰다. 결과는 4×4 인터벌군 VO2max +7.2%, 15초/15초 인터벌군 +5.5%였고, 70% HRmax 지속주군과 85% HRmax 젖산역치군은 유의한 변화가 없었다. 1회 심박출량은 인터벌 훈련군에서만 약 10% 증가했다. 즉 같은 양을 훈련해도 강도 배분에 따라 결과가 갈렸다는 것이 이 연구의 요지다.\n\n이미 주 2~3회 달릴 수 있고 유산소 상한을 끌어올리고 싶은 중급자에게 맞는다. 페이스가 아니라 심박으로 관리하는 프로토콜이므로 심박계가 사실상 필수다. 4분 구간의 첫 1~2분은 목표 심박에 도달하지 않는 것이 정상이며, 구간 끝에서 90~95%에 들어가면 된다.\n\n주의점. 첫째, 강도가 높아 심혈관 질환·고혈압 이력이 있으면 사전 상담이 필요하고 러닝 입문자에게는 부적합하다. 둘째, 주 3회 4×4만 하는 것은 연구 프로토콜이며 실제 권장은 주 2회 4×4 + 중강도 지속주 1회(CERG 기준 주 2~3회)다. 이 데이터의 주간 구성도 그 방식을 따랐다. 셋째, 향상은 8~10주 구간에서 가장 크고 이후 둔화되며, VO2max 상승이 곧 레이스 기록 단축을 보장하지는 않는다. 역치 훈련과 장거리 지속주를 대체하는 것이 아니라 얹는 것으로 봐야 한다.",
            progression: "속도가 아니라 심박으로 올린다. 처음 2주는 4분 구간을 88~90% HRmax로 시작해 이후 90~95%까지 올리고, 같은 심박에서 페이스가 빨라지는 것으로 향상을 확인한다. 세트 수는 4개, 회복 3분을 그대로 유지한다.",
            tags: ["러닝", "인터벌", "VO2max", "고강도"],
            days: [
                ProgramDay(label: "1일차", focus: "인터벌", note: "10분 조깅 워밍업, 5~10분 쿨다운", cardio:
                    ProgramCardio(mode: .interval, workSeconds: 240, intensityPct: 92, restSeconds: 180, recoveryPaceSec: nil, sets: 4, minutes: 0, paceSec: nil, note: "4분 90~95% HRmax, 회복 3분은 70% HRmax 조깅")),
                ProgramDay(label: "2일차", focus: "지속주", note: "인터벌 사이의 중강도 세션. 원 연구에는 없고 실제 권장 구성에서 온 날", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 70, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 45, paceSec: nil, note: "대화 가능한 페이스로 유지")),
                ProgramDay(label: "3일차", focus: "인터벌", note: "10분 조깅 워밍업, 5~10분 쿨다운. 1일차와 최소 48시간 간격", cardio:
                    ProgramCardio(mode: .interval, workSeconds: 240, intensityPct: 92, restSeconds: 180, recoveryPaceSec: nil, sets: 4, minutes: 0, paceSec: nil, note: "4분 90~95% HRmax, 회복 3분은 70% HRmax 조깅")),
            ],
            reviews: [
                ProgramReview(source: "Helgerud et al., Med Sci Sports Exerc 2007", rating: 5, text: "총 운동량을 맞춘 8주 비교에서 4×4군만 VO2max +7.2%와 심박출량 +10%를 얻었고 지속주·역치군은 유의한 변화가 없었다. 단 대상이 중등도로 훈련된 젊은 남성 40명이라 여성·고령자·엘리트에게 그대로 확장하기는 어렵다."),
                ProgramReview(source: "NTNU 심장운동연구그룹(CERG) 공식 안내", rating: 4, text: "대부분의 사람에게 주 2~3회가 자극과 회복의 균형점이라고 안내한다. 심박 기반이라 심박계 없이는 강도 관리가 사실상 불가능하다는 점이 진입 장벽이다."),
                ProgramReview(source: "Fitbook 매거진 4×4 체험 리포트", rating: 3, text: "40분이면 끝나고 효과가 빠르게 체감된다는 점을 장점으로 꼽는다. 반면 4분 구간의 주관적 고통이 상당해 주 3회를 지속하기 어렵고, 컨디션이 나쁜 날에는 목표 심박에 도달하지 못한다는 단점을 지적한다."),
            ]),
        WorkoutProgram(
            id: "polarized-80-20",
            title: "80/20 폴러라이즈드 트레이닝",
            kind: .cardio,
            goal: "강도 분배 최적화로 지구력 향상",
            level: "중급",
            weeks: 0,
            daysPerWeek: 5,
            author: "Stephen Seiler (University of Agder)",
            origin: "Seiler & Kjerland, Scand J Med Sci Sports 2006 / Stöggl & Sperlich, Front Physiol 2014",
            summary: "쉬운 80% + 힘든 20%",
            detail: "특정 주차표가 아니라 강도 분배 모델이다. Stephen Seiler가 크로스컨트리 스키·조정·달리기·사이클 엘리트 선수들의 실제 훈련 기록을 측정한 결과, 전체 세션의 약 80%가 첫 젖산·환기 역치(LT1) 아래였고 15~20%가 두 번째 역치(LT2) 위였다. 그 사이의 중간 강도는 5~10%에 불과했다. 처방이 아니라 관찰된 패턴에서 출발했다는 점이 이 모델의 특징이다.\n\n개입 연구로는 Stöggl & Sperlich 2014가 자주 인용된다. 잘 훈련된 지구력 선수 48명을 폴러라이즈드·역치 중심·고volume·HIIT 네 군으로 나눠 9주간 훈련시켰고, 폴러라이즈드군이 VO2peak +11.7%, 탈진까지 걸린 시간 +17.4%, 최대 출력 +5.1%로 가장 폭넓게 향상됐다. 역치 중심군과 고volume 저강도군에서는 추가 향상이 관찰되지 않았다.\n\n주 4회 이상, 주 5시간 이상 달리는 사람에게 의미가 있다. 세션 수가 적으면 80/20을 맞출 여지 자체가 작다. 실전에서 가장 흔한 실패는 하드 세션이 약해서가 아니라 쉬운 날이 쉽지 않아서다. 80%에 해당하는 날은 코로 호흡하며 문장을 이어 말할 수 있는 강도까지 실제로 낮춰야 한다.\n\n한계도 분명하다. 첫째, 최근 메타분석은 레크리에이션 수준에서는 중간 강도 비중이 더 큰 피라미달 분포가 폴러라이즈드보다 효과적이며, 폴러라이즈드의 우위는 엘리트에서만 약간 나타난다고 보고한다. 잘 훈련된 러너를 16주간 비교한 연구에서는 두 분포 모두 효과적이고 유의한 차이가 없었다. 둘째, 80/20을 세션 수 기준으로 볼지 시간 기준으로 볼지, 존 경계를 심박·젖산·RPE 중 무엇으로 그을지에 따라 같은 훈련이 다른 숫자로 계산된다. 셋째, 레이스 페이스 특이성(마라톤 페이스 훈련)이 구조적으로 빠지므로 목표 대회 직전에는 보정이 필요하다.",
            progression: "고강도 세션 수는 주 1~2회로 고정하고 늘리는 것은 주로 저강도 시간이다. 고강도 구간 총량은 4×4분에서 4×8분, 5×8분 수준으로 몇 주 단위로 늘리고, 주간 총 시간이 늘어나도 하드 세션 수는 그대로 둔다.",
            tags: ["러닝", "폴러라이즈드", "존관리", "지속주"],
            days: [
                ProgramDay(label: "1일차", focus: "이지런", note: "80% 쪽. 대화가 끊기면 너무 빠르다", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 68, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 45, paceSec: nil, note: "LT1 아래, 코호흡 가능한 강도")),
                ProgramDay(label: "2일차", focus: "인터벌", note: "20% 쪽. 15분 워밍업, 10분 쿨다운", cardio:
                    ProgramCardio(mode: .interval, workSeconds: 480, intensityPct: 90, restSeconds: 180, recoveryPaceSec: nil, sets: 4, minutes: 0, paceSec: nil, note: "4×8분, 회복 3분 조깅. LT2 위 강도")),
                ProgramDay(label: "3일차", focus: "이지런", note: "전날 하드 세션 뒤 회복. 절대 페이스를 올리지 않는다", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 68, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 50, paceSec: nil, note: "LT1 아래")),
                ProgramDay(label: "4일차", focus: "이지런", note: "", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 68, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 40, paceSec: nil, note: "LT1 아래. 시간이 없으면 이 날을 줄인다")),
                ProgramDay(label: "5일차", focus: "롱런", note: "주간 저강도 시간의 대부분을 여기서 확보", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 70, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 100, paceSec: nil, note: "끝까지 LT1 아래 유지. 후반에 페이스가 올라가면 실패")),
            ],
            reviews: [
                ProgramReview(source: "Seiler & Kjerland, Scand J Med Sci Sports 2006", rating: 5, text: "엘리트 선수들의 실제 훈련 분포가 심박·RPE·젖산 어느 기준으로 봐도 저강도 약 75~80%, 중간 6~8%, 고강도 15~20%로 수렴한다는 관찰 연구다. 무엇이 효과적인지를 증명한 실험이 아니라 무엇을 하고 있는지를 기술한 연구라는 한계가 있다."),
                ProgramReview(source: "Stöggl & Sperlich, Front Physiol 2014", rating: 4, text: "9주 개입에서 폴러라이즈드군이 VO2peak +11.7%, 탈진 시간 +17.4%로 네 군 중 가장 넓게 향상됐다. 다만 대상이 이미 잘 훈련된 선수 48명이고 기간이 9주에 불과해, 일반 러너와 장기 적용에 그대로 대입하기는 어렵다."),
                ProgramReview(source: "TrainingPeaks 코치 블로그 (폴러라이즈드 vs 피라미달)", rating: 3, text: "저강도 비중을 확보한다는 원칙 자체는 거의 모든 코치가 동의하는 부분이라고 정리한다. 반면 폴러라이즈드가 피라미달보다 우월하다는 주장은 근거가 갈리며, 레크리에이션 러너에서는 오히려 피라미달이 낫다는 보고가 있어 80/20을 규칙처럼 지킬 필요는 없다고 본다."),
            ]),
        WorkoutProgram(
            id: "daniels-vdot",
            title: "잭 다니엘스 VDOT 주간 구성 (E/M/T/I/R)",
            kind: .cardio,
            goal: "기록 기반 페이스 관리로 기록 단축",
            level: "중급",
            weeks: 0,
            daysPerWeek: 5,
            author: "Jack Daniels",
            origin: "Daniels' Running Formula (Human Kinetics)",
            summary: "VDOT로 5개 페이스 관리",
            detail: "최근 레이스 기록으로 VDOT 값을 구하고, 그 값에 대응하는 다섯 가지 훈련 페이스를 표에서 읽어 주간 훈련을 조립하는 방식이다. E(이지)는 최대심박의 65~79%로 유산소 기반과 회복, M(마라톤 페이스)은 80~90%, T(역치)는 88~92%로 '편하게 힘든' 강도, I(인터벌)는 97~100%로 VO2max 자극, R(레피티션)은 심박 기준 없이 페이스로만 관리하는 스피드·러닝이코노미 구간이다.\n\n각 페이스마다 노리는 적응이 다르고 허용 총량이 정해져 있다는 점이 이 체계의 핵심이다. T는 한 세션에 20~60분, I는 구간당 최대 5분에 같은 시간만큼 E 페이스 회복, R은 구간당 최대 2분이고 주당 총량 8km(5마일) 이내다. 롱런은 주간 거리의 25~30%를 넘기지 않는다. 주간 거리의 70~80%는 E로 채우고 나머지를 M·T와 I·R이 나눠 갖는다. 즉 강도를 올리는 자유도는 좁고, 양의 상한이 먼저 정해져 있다.\n\n최근 레이스 기록이 있고 주 4회 이상 달리는 중급 이상에게 맞는다. 주간은 강조 세션(Q1)과 보조 세션(Q2)을 두고 나머지를 E로 채우는 형태이며, 아래 구성은 T와 I를 각각 Q1·Q2로 잡은 예다.\n\n주의점. 첫째, 페이스를 목표 기록으로 잡으면 안 된다. Fellrnr도 목표 시간 기준 페이스는 과훈련 위험을 키우고 훈련 효과를 떨어뜨린다고 지적한다. 반드시 실제로 뛴 기록에서 VDOT을 잡는다. 둘째, 2017년 J Strength Cond Res 연구는 VDOT이 대학 선수와 레크리에이션 러너 모두에서 실측 VO2max를 과소평가했다고 보고했다. 표의 페이스가 항상 생리학적으로 정확한 값은 아니다. 셋째, 언덕과 더위를 보정하는 명시적 규칙이 없어 지형이 험한 곳에서는 별도 판단이 필요하다. 넷째, 표를 찾고 세션을 계산하는 과정 자체가 번거롭고, 이 진입 장벽이 가장 흔한 중단 이유다.",
            progression: "약 6주 단위 국면으로 강조점을 바꾼다(기초 E 중심 → R → I → T 중심). 주간 거리는 한 번 올린 뒤 3~4주 유지하고, 페이스는 감으로 올리지 않고 레이스나 타임트라이얼을 다시 뛰어 VDOT을 1~2점 갱신할 때만 바꾼다.",
            tags: ["러닝", "VDOT", "역치", "인터벌"],
            days: [
                ProgramDay(label: "1일차", focus: "Q1 역치(T)", note: "15분 E 워밍업, 10분 E 쿨다운", cardio:
                    ProgramCardio(mode: .interval, workSeconds: 300, intensityPct: 90, restSeconds: 60, recoveryPaceSec: nil, sets: 4, minutes: 0, paceSec: nil, note: "T 페이스 크루즈 인터벌 5분×4(총 20분), 회복 1분. 한 세션 T 총량은 20~60분 이내")),
                ProgramDay(label: "2일차", focus: "이지런(E)", note: "", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 70, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 40, paceSec: nil, note: "E 페이스, 65~79% HRmax")),
                ProgramDay(label: "3일차", focus: "Q2 인터벌(I)", note: "15분 E 워밍업, 10분 E 쿨다운", cardio:
                    ProgramCardio(mode: .interval, workSeconds: 180, intensityPct: 98, restSeconds: 180, recoveryPaceSec: nil, sets: 5, minutes: 0, paceSec: nil, note: "I 페이스 3분×5, 회복은 같은 시간 E 페이스 조깅. 구간은 5분을 넘기지 않는다")),
                ProgramDay(label: "4일차", focus: "이지런(E)", note: "", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 70, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 50, paceSec: nil, note: "E 페이스")),
                ProgramDay(label: "5일차", focus: "롱런(E)", note: "주간 거리의 25~30% 이내로 제한", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 72, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 100, paceSec: nil, note: "E 페이스, 최대 150분")),
            ],
            reviews: [
                ProgramReview(source: "Daniels' Running Formula (Human Kinetics)", rating: 5, text: "각 페이스의 목적과 허용 총량을 숫자로 못박아 훈련 과부하를 구조적으로 막는다. 반면 훈련 유형별 상한과 국면 구성이 많아 처음 읽는 사람에게는 규칙이 과하게 느껴진다."),
                ProgramReview(source: "Fellrnr.com — Jack Daniels / VDOT 항목", rating: 4, text: "기록으로 체력을 측정하고 그 체력으로 페이스를 정한다는 발상 자체가 이후 많은 플랜의 토대가 됐다고 평가한다. 단점으로는 VDOT과 세션을 표에서 찾는 수고, 언덕 지형 보정 규칙의 부재, 그리고 목표 기록 기반 페이스가 과훈련으로 이어진다는 점을 든다."),
                ProgramReview(source: "An Evaluation of Time-Trial-Based Predictions of VO2max, J Strength Cond Res 2017", rating: 3, text: "VDOT 계산기가 대학 선수와 레크리에이션 러너 모두에서 실측 VO2max를 과소평가했다고 보고했다. 표의 페이스를 생리학적 정답으로 다루지 말고 상대적 기준으로 쓰라는 근거가 된다."),
            ]),
        WorkoutProgram(
            id: "hansons-half",
            title: "핸슨스 하프마라톤 메소드 (초급)",
            kind: .cardio,
            goal: "하프마라톤 완주·기록",
            level: "중급",
            weeks: 18,
            daysPerWeek: 6,
            author: "Keith & Kevin Hanson, Luke Humphrey",
            origin: "Hansons Half-Marathon Method (Hansons-Brooks Distance Project)",
            summary: "누적 피로로 하프 후반 버티기",
            detail: "18주, 주 6일 달리기에 완전 휴식 1일(수요일)로 구성된다. 핵심 세션은 세 개다. 화요일 스피드·스트렝스 인터벌, 목요일 하프 목표 페이스 템포, 일요일 롱런이며 나머지 사흘은 이지런으로 주간 거리를 채운다. 초급 플랜의 최대 주간 거리는 48마일(약 77km), 상급은 51마일이다. 스피드·템포 없이 롱런만 하는 'Just Finish' 버전도 별도로 있다.\n\n설계 원리는 '누적 피로(cumulative fatigue)'다. 완전히 회복되지 않은 상태에서 다음 훈련을 하도록 배치해, 레이스 후반의 지친 다리로 목표 페이스를 유지하는 능력을 만든다는 것이다. 그래서 롱런을 12마일(약 19km)에서 끊고 대신 주간 거리와 빈도를 높인다. 하드 세션 사이에 이지런을 끼워 배치하는 것도 회복을 완전히 주지 않기 위한 의도다.\n\n세션은 프로그램 진행에 따라 성격이 바뀐다. 전반기 화요일은 5K 페이스의 짧은 반복(예: 400m×12)이고, 중반 이후에는 10K 페이스의 긴 반복(예: 2마일×3) 이른바 스트렝스 세션으로 전환된다. 목요일 템포는 하프 목표 페이스를 유지하며 거리를 점차 늘려 레이스 페이스 감각과 젖산역치를 함께 다룬다.\n\n이미 주 30~40km를 소화하고 있고 주 6일을 감당할 수 있는 사람에게 맞는다. 반대로 고volume에서 부상이 잦은 사람, 주 3~4일만 달릴 수 있는 사람에게는 맞지 않는다는 지적이 코치 리뷰에서 공통적으로 나온다. 이름이 '초급'이지만 러닝 입문자용이 아니다.\n\n그 외 한계. 롱런이 12마일에서 멈추기 때문에 레이스 거리를 한 번도 뛰어보지 못한 채 출발선에 서게 되고, 이 점이 심리적 불안 요인으로 자주 언급된다. 또 템포 페이스를 현재 실력이 아니라 희망 목표로 잡으면 누적 피로가 과훈련으로 넘어간다. 주 6일이라 일정 유연성이 거의 없다는 점도 실제 이탈 이유다.",
            progression: "주간 거리를 늘리면서 화요일 세션을 5K 페이스 짧은 반복에서 10K 페이스 긴 반복으로 전환하고, 목요일 템포 거리를 점차 늘린다. 롱런은 12마일까지만 늘리고 후반에는 10마일과 12마일을 주 단위로 번갈아 한다.",
            tags: ["러닝", "하프마라톤", "템포", "누적피로"],
            days: [
                ProgramDay(label: "1일차(월)", focus: "이지런", note: "전날 롱런 뒤 회복. 페이스를 올리지 않는다", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 68, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 45, paceSec: nil, note: "대화 가능한 페이스, 6~8km")),
                ProgramDay(label: "2일차(화)", focus: "스피드/스트렝스", note: "1.5~3km 조깅 워밍업과 쿨다운 포함", cardio:
                    ProgramCardio(mode: .interval, workSeconds: 90, intensityPct: 95, restSeconds: 120, recoveryPaceSec: nil, sets: 12, minutes: 0, paceSec: nil, note: "5K 페이스 400m×12, 회복은 400m 조깅. 프로그램 중반 이후 10K 페이스 2마일×3 같은 스트렝스 세션으로 전환")),
                ProgramDay(label: "3일차(목)", focus: "템포", note: "수요일 완전 휴식 다음 날. 앞뒤로 1.5~3km 조깅", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 85, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 50, paceSec: nil, note: "하프 목표 페이스 그대로. 주차가 올라가며 거리가 길어진다")),
                ProgramDay(label: "4일차(금)", focus: "이지런", note: "템포 다음 날. 의도적으로 느리게", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 68, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 40, paceSec: nil, note: "6~8km")),
                ProgramDay(label: "5일차(토)", focus: "이지런", note: "롱런 전날. 다리를 완전히 털지 않는 것이 의도된 설계", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 68, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 55, paceSec: nil, note: "8~11km")),
                ProgramDay(label: "6일차(일)", focus: "롱런", note: "최대 12마일(약 19km)에서 멈춘다", cardio:
                    ProgramCardio(mode: .steady, workSeconds: 0, intensityPct: 72, restSeconds: 0, recoveryPaceSec: nil, sets: 0, minutes: 100, paceSec: nil, note: "이지 페이스보다 약간 빠르게. 후반에는 10마일과 12마일을 번갈아")),
            ],
            reviews: [
                ProgramReview(source: "Luke Humphrey Running 공식 안내", rating: 4, text: "초급·상급 모두 주 6일에 세 개의 핵심 세션을 두고 초급은 주 48마일에서 정점을 찍는 구조로 안내한다. 대신 주 3~4일만 가능한 사람을 위한 선택지는 롱런 중심의 'Just Finish' 뿐이어서 중간 옵션이 없다."),
                ProgramReview(source: "Laura Norris Running (러닝 코치 블로그 리뷰)", rating: 4, text: "지친 상태에서 달리는 훈련이 레이스 후반 페이스 유지에 실제로 도움이 된다고 평가한다. 다만 고volume에서 부상이 잦은 사람과 주 3~4일만 달릴 수 있는 초보에게는 부적합하다고 명확히 선을 긋는다."),
                ProgramReview(source: "LetsRun.com 포럼 (핸슨스 플랜 적용 후기 스레드)", rating: 3, text: "주간 거리와 빈도가 일정하게 유지돼 체력이 꾸준히 쌓인다는 후기가 많다. 반면 롱런이 짧아 레이스 거리를 미리 경험하지 못하는 불안, 그리고 템포 페이스를 목표 기록으로 잡았을 때 중반부터 무너진다는 지적이 반복된다."),
            ]),
    ]
}
