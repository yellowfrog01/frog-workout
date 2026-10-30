import Foundation
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// StatusEngine
// "상태" 화면의 모든 수치 계산. SwiftUI 의존 없음(순수 계산).
// 공식·임계값은 전부 이 파일에 모여 있다. 나중에 분석 결과로 조정할 것.
//
// 공통 가정
// - 성별·나이 정보가 앱에 없다. 기준 범위(게이지)는 "30대 성인 남성, 일반인" 기준의
//   대략적인 값으로 잡았다. 임상 기준이 아니다.
// - 게이지(0...1)는 선형 보간 후 0...1 로 자른 값. lo > hi 이면 "낮을수록 좋음" 지표.
// - 레벨(Lv) 은 게이지를 1...10 으로 옮긴 표시용 값.
// ─────────────────────────────────────────────────────────────────────────────

// MARK: - 입력 스냅샷 (SwiftData 모델에서 값만 복사)

struct LiftLog {
    var date: Date
    var name: String
    var weight: Double
    var sets: Int
    var reps: Int           // 추정에 쓸 기준 세트의 반복 수 (effReps 참고)
    var done: Int
    var isBW: Bool
    var repsList: [Int] = []
    var rir: Int? = nil
    /// 세트별 무게 (repsList 와 같은 순서). 비어 있으면 모든 세트를 weight 로 본다.
    var weights: [Double] = []

    /// 세트별 e1RM 추정 입력. 마지막 세트만 RIR 을 반복 수에 더한다.
    /// 무게·반복이 0 이하인 세트는 제외.
    var setEstimates: [(w: Double, reps: Int, rirAdded: Bool)] {
        let repList = repsList.isEmpty ? [reps] : repsList
        var out: [(w: Double, reps: Int, rirAdded: Bool)] = []
        for (i, r) in repList.enumerated() {
            let w = i < weights.count ? weights[i] : weight
            var n = r
            var added = false
            if i == repList.count - 1, let rr = rir {
                n += rr
                added = true
            }
            if n <= 0 || w <= 0 { continue }
            out.append((w: w, reps: n, rirAdded: added))
        }
        return out
    }

    /// e1RM 이 가장 큰 세트. (반복 + RIR) ≤ epleyMaxReps 인 세트가 있으면 그 안에서, 없으면 전체에서 고른다.
    var bestSet: (w: Double, reps: Int, rirAdded: Bool)? {
        let all = setEstimates
        let inRange = all.filter { $0.reps <= StatusEngine.epleyMaxReps }
        let rows = inRange.isEmpty ? all : inRange
        return rows.max(by: { StatusEngine.epley($0.w, reps: $0.reps) < StatusEngine.epley($1.w, reps: $1.reps) })
    }

    /// 이 기록의 e1RM (최고 세트 기준). 유효 세트가 없으면 0.
    var e1RM: Double {
        guard let b = bestSet else { return 0 }
        return StatusEngine.epley(b.w, reps: b.reps)
    }

    /// 추정에 쓰는 반복 수 = 최고 세트의 반복 수 (마지막 세트면 RIR 포함).
    var effReps: Int { bestSet?.reps ?? 0 }
    /// 최고 세트에 RIR 이 포함됐는가. 아니면 한계까지 했는지 모르므로 "하한값"이다.
    var rirKnown: Bool { bestSet?.rirAdded ?? false }
}

struct CardioLog {
    var date: Date
    var seconds: Int?
    var distanceKm: Double
    var pace: Int?          // 초/km
}

struct BodyLog {
    var date: Date
    var weight: Double
    var skeletalMuscle: Double?
    var bodyFatMass: Double?
    var bodyFatPercent: Double?
    var smi: Double?
    var visceralLevel: Double?
    var score: Double?
    var bmr: Double?
}

struct VitalLog {
    var date: Date
    var kind: VitalKind
    var value: Double
}

// MARK: - 출력 타입

enum Better { case higher, lower, neutral }

enum Archetype {
    case novice, strength, endurance, hybrid
    var label: String {
        switch self {
        case .novice:    "견습"
        case .strength:  "근력형"
        case .endurance: "유산소형"
        case .hybrid:    "하이브리드"
        }
    }
    var subtitle: String {
        switch self {
        case .novice:    "기록이 더 쌓이면 빌드가 정해집니다"
        case .strength:  "무게를 올리는 빌드"
        case .endurance: "심폐 지구력 빌드"
        case .hybrid:    "근력 + 지구력 균형 빌드"
        }
    }
    var symbol: String {
        switch self {
        case .novice:    "sparkles"
        case .strength:  "dumbbell.fill"
        case .endurance: "figure.run"
        case .hybrid:    "figure.cross.training"
        }
    }
}

enum BuildTrend {
    case towardStrength, towardEndurance, steady, unknown
    var label: String {
        switch self {
        case .towardStrength:  "근력 쪽으로 이동 중"
        case .towardEndurance: "유산소 쪽으로 이동 중"
        case .steady:          "방향 유지"
        case .unknown:         "추세 판단 불가"
        }
    }
}

enum BodyDirection {
    case recomp, bulk, cut, muscleLoss, steady, unknown
    var label: String {
        switch self {
        case .recomp:     "리컴프 (근육↑ 지방↓)"
        case .bulk:       "벌크 (근육↑ 지방↑)"
        case .cut:        "감량 (지방↓)"
        case .muscleLoss: "근손실 주의 (근육↓)"
        case .steady:     "체성분 유지"
        case .unknown:    "체성분 기록 부족"
        }
    }
}

struct CoreStat: Identifiable {
    var id: String { code }
    var code: String        // STR / END / REC / BODY
    var label: String
    var gauge: Double?      // nil = 데이터 없음
}

struct BuildInfo {
    var archetype: Archetype
    var strengthShare: Double?      // 0 = 전부 유산소, 1 = 전부 근력
    var trend: BuildTrend
    var strengthCount: Int          // 최근 8주 근력 세션 수
    var cardioCount: Int            // 최근 8주 유산소 세션 수
    var bodyDirection: BodyDirection
    var level: Int
    var levelProgress: Double       // 다음 레벨까지 0...1
    var totalSessions: Int
    var weeklyFrequency: Double     // 최근 4주 주당 세션
    var core: [CoreStat]
}

struct BodyStat: Identifiable {
    var id: String { label }
    var label: String
    var unit: String
    var latest: Double
    var deltaPrev: Double?
    var deltaFirst: Double?
    var better: Better
    var gauge: Double?
    var decimals: Int
    var latestDate: Date
}

struct VitalStat: Identifiable {
    var id: String { kind.rawValue }
    var kind: VitalKind
    var value: Double?          // 최근 7일 평균
    var delta: Double?          // 최근 7일 평균 − 첫 7일 평균
    var count: Int
    var lastDate: Date?
    var gauge: Double?
    var hasData: Bool { value != nil }
}

struct CardioSummary {
    var sessions: Int           // 최근 28일
    var km: Double
    var minutes: Int
    var bestPace: Int?          // 초/km, 1km 이상 세션 중
}

enum MovePattern: String, CaseIterable, Identifiable {
    case push, pull, overhead, squat, hinge, core, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .push:     "밀기"
        case .pull:     "당기기"
        case .overhead: "오버헤드"
        case .squat:    "스쿼트"
        case .hinge:    "힌지"
        case .core:     "코어"
        case .other:    "기타"
        }
    }
}

struct RMValue: Identifiable {
    var id: Int { reps }
    var reps: Int
    var weight: Double
}

struct LiftStat: Identifiable {
    var id: String { name }
    var name: String
    var pattern: MovePattern
    var bestWeight: Double
    var bestReps: Int
    var bestDate: Date
    var e1RM: Double
    var rms: [RMValue]
    var delta: Double?          // 최근 28일 최고 e1RM − 그 이전 최고 e1RM
    var gauge: Double?          // 체중 대비 상대 근력
    var lowConfidence: Bool     // 기준 세트의 (반복 + RIR) 이 10 초과 → Epley 정확 범위 밖
    var lowerBound: Bool = false // 기준 세트에 RIR 이 없음 → 실제 1RM 은 이보다 높을 수 있음
}

struct BWLiftStat: Identifiable {
    var id: String { name }
    var name: String
    var pattern: MovePattern
    var bestReps: Int
    var bestAdded: Double       // 추가 중량 kg
}

enum FlagLevel { case ok, info, warn }

struct BalanceFlag: Identifiable {
    var id: String { text }
    var level: FlagLevel
    var text: String
}

struct PatternVolume: Identifiable {
    var id: String { pattern.rawValue }
    var pattern: MovePattern
    var sets: Int
}

struct StatusSnapshot {
    var build: BuildInfo
    var body: [BodyStat]
    var vitals: [VitalStat]
    var cardio: CardioSummary
    var lifts: [LiftStat]
    var bwLifts: [BWLiftStat]
    var volumes: [PatternVolume]
    var volumeWindowIsRecent: Bool  // true = 최근 28일, false = 전체 기록
    var flags: [BalanceFlag]
    var bodyweight: Double?
}

// MARK: - 엔진

enum StatusEngine {

    // 창(window) 길이
    static let buildWindowDays = 56     // 빌드 판정: 최근 8주
    static let recentDays = 28          // 추세·볼륨: 최근 4주
    static let vitalAvgDays = 7         // 지표 평균: 7일

    // MARK: 진입점

    static func snapshot(sessions: [Session], bodies: [BodyRecord], vitals: [Vital],
                         now: Date = .now) -> StatusSnapshot {
        var lifts: [LiftLog] = []
        var cardio: [CardioLog] = []
        var strengthDates: [Date] = []
        var cardioDates: [Date] = []
        for s in sessions where !s.isEmpty || s.kind == .interval {
            switch s.kind {
            case .strength:
                guard !s.lifts.isEmpty else { continue }
                strengthDates.append(s.logicalDay)
                for l in s.lifts {
                    lifts.append(LiftLog(date: s.logicalDay, name: statName(l), weight: l.weight,
                                         sets: l.sets, reps: l.reps, done: l.done, isBW: l.isBW,
                                         repsList: l.repsList, rir: l.rir, weights: l.weightList))
                }
            case .interval:
                cardioDates.append(s.logicalDay)
                cardio.append(CardioLog(date: s.logicalDay, seconds: s.durationSeconds,
                                        distanceKm: s.distanceKm, pace: s.avgPace))
            case .activity:
                break
            }
        }
        let bodyLogs = bodies.map {
            BodyLog(date: $0.date, weight: $0.weight, skeletalMuscle: $0.skeletalMuscle,
                    bodyFatMass: $0.bodyFatMass, bodyFatPercent: $0.bodyFatPercent,
                    smi: $0.smi, visceralLevel: $0.visceralLevel, score: $0.score, bmr: $0.bmr)
        }.sorted { $0.date < $1.date }
        let vitalLogs = vitals.map { VitalLog(date: $0.date, kind: $0.kind, value: $0.value) }

        let bw = bodyLogs.last(where: { $0.weight > 0 })?.weight
        let bodyStats = bodyStats(bodyLogs)
        let vitalStats = vitalStats(vitalLogs)
        let liftStats = liftStats(lifts, bodyweight: bw, now: now)
        let bwStats = bwLiftStats(lifts)
        let (vols, recent) = patternVolumes(lifts, now: now)
        let flags = balanceFlags(volumes: vols, lifts: liftStats)

        let core = coreStats(lifts: liftStats, vitals: vitalStats, body: bodyStats)
        let build = buildInfo(strengthDates: strengthDates, cardioDates: cardioDates,
                              body: bodyLogs, core: core, now: now)

        return StatusSnapshot(build: build, body: bodyStats, vitals: vitalStats,
                              cardio: cardioSummary(cardio, now: now),
                              lifts: liftStats, bwLifts: bwStats,
                              volumes: vols, volumeWindowIsRecent: recent,
                              flags: flags, bodyweight: bw)
    }

    // MARK: 공통 도우미

    /// 선형 게이지. lo → 0, hi → 1, 범위 밖은 자름. lo > hi 면 낮을수록 좋은 지표.
    static func gauge(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        guard hi != lo else { return 0 }
        return min(1, max(0, (v - lo) / (hi - lo)))
    }

    /// 게이지 0...1 → Lv 1...10
    static func level(_ g: Double) -> Int { 1 + Int((g * 9).rounded()) }

    static func mean(_ a: [Double]) -> Double? {
        a.isEmpty ? nil : a.reduce(0, +) / Double(a.count)
    }

    static func daysAgo(_ n: Int, from now: Date) -> Date {
        now.addingTimeInterval(-Double(n) * 86_400)
    }

    // MARK: 1. 빌드 방향

    /// 규칙
    /// - 최근 8주 세션 수로 근력 비중 r = 근력 / (근력 + 유산소).
    /// - 합계 < 3 → 견습(판정 보류).
    /// - r ≥ 0.65 → 근력형, r ≤ 0.35 → 유산소형, 그 외 → 하이브리드.
    /// - 추세: 최근 4주 r − 그 이전 4주 r. +0.10 초과 → 근력 쪽, −0.10 미만 → 유산소 쪽.
    ///   두 구간 중 하나라도 세션이 0 이면 판단 불가.
    /// - 레벨: 전체 세션 5회당 1레벨 (Lv = 1 + n/5).
    /// - 주당 빈도: 최근 4주 세션 수 / 4.
    static func buildInfo(strengthDates: [Date], cardioDates: [Date], body: [BodyLog],
                          core: [CoreStat], now: Date) -> BuildInfo {
        let from8 = daysAgo(buildWindowDays, from: now)
        let from4 = daysAgo(recentDays, from: now)
        let s8 = strengthDates.filter { $0 >= from8 }
        let c8 = cardioDates.filter { $0 >= from8 }
        let total8 = s8.count + c8.count

        var share: Double? = nil
        var arche: Archetype = .novice
        if total8 >= 3 {
            let r = Double(s8.count) / Double(total8)
            share = r
            arche = r >= 0.65 ? .strength : (r <= 0.35 ? .endurance : .hybrid)
        } else if total8 > 0 {
            share = Double(s8.count) / Double(total8)
        }

        func ratio(_ s: [Date], _ c: [Date]) -> Double? {
            let n = s.count + c.count
            return n == 0 ? nil : Double(s.count) / Double(n)
        }
        let recentR = ratio(s8.filter { $0 >= from4 }, c8.filter { $0 >= from4 })
        let olderR = ratio(s8.filter { $0 < from4 }, c8.filter { $0 < from4 })
        var trend: BuildTrend = .unknown
        if let a = recentR, let b = olderR {
            let d = a - b
            trend = d > 0.10 ? .towardStrength : (d < -0.10 ? .towardEndurance : .steady)
        }

        let total = strengthDates.count + cardioDates.count
        let recentCount = (strengthDates + cardioDates).filter { $0 >= from4 }.count

        return BuildInfo(archetype: arche, strengthShare: share, trend: trend,
                         strengthCount: s8.count, cardioCount: c8.count,
                         bodyDirection: bodyDirection(body),
                         level: 1 + total / 5,
                         levelProgress: Double(total % 5) / 5,
                         totalSessions: total,
                         weeklyFrequency: Double(recentCount) / 4,
                         core: core)
    }

    /// 체성분 방향. 최신 기록 vs 최신 기준 90일 이내 가장 오래된 기록(없으면 첫 기록).
    /// 골격근 Δm, 체지방량 Δf 를 비교. 임계값 0.3kg (인바디 측정 오차 수준 가정).
    /// - Δm > +t, Δf < −t → 리컴프
    /// - Δm > +t, Δf > +t → 벌크
    /// - Δm < −t          → 근손실 주의
    /// - Δf < −t          → 감량
    /// - 그 외            → 유지
    static func bodyDirection(_ body: [BodyLog]) -> BodyDirection {
        let rec = body.filter { $0.skeletalMuscle != nil && $0.bodyFatMass != nil }
        guard let last = rec.last, rec.count >= 2 else { return .unknown }
        let cutoff = last.date.addingTimeInterval(-90 * 86_400)
        let base = rec.first(where: { $0.date >= cutoff && $0.date < last.date }) ?? rec.first!
        guard base.date < last.date else { return .unknown }
        let dm = last.skeletalMuscle! - base.skeletalMuscle!
        let df = last.bodyFatMass! - base.bodyFatMass!
        let t = 0.3
        if dm > t && df < -t { return .recomp }
        if dm > t && df > t { return .bulk }
        if dm < -t { return .muscleLoss }
        if df < -t { return .cut }
        return .steady
    }

    /// 코어 스탯 4종 (0...1)
    /// - STR : 근력 종목 상대 근력 게이지의 평균
    /// - END : VO₂max 게이지
    /// - REC : 안정시 심박·HRV 게이지의 평균 (있는 것만)
    /// - BODY: SMI·체지방률 게이지의 평균 (있는 것만)
    static func coreStats(lifts: [LiftStat], vitals: [VitalStat], body: [BodyStat]) -> [CoreStat] {
        func vg(_ k: VitalKind) -> Double? { vitals.first { $0.kind == k }?.gauge }
        func bg(_ l: String) -> Double? { body.first { $0.label == l }?.gauge }
        return [
            CoreStat(code: "STR", label: "근력", gauge: mean(lifts.compactMap(\.gauge))),
            CoreStat(code: "END", label: "지구력", gauge: vg(.vo2Max)),
            CoreStat(code: "REC", label: "회복", gauge: mean([vg(.restingHR), vg(.hrv)].compactMap { $0 })),
            CoreStat(code: "BODY", label: "체성분", gauge: mean([bg("SMI"), bg("체지방률")].compactMap { $0 })),
        ]
    }

    // MARK: 2. 체성분

    /// 각 항목: 최신값, 직전 측정 대비 Δ, 첫 측정 대비 Δ. 값이 있는 기록만 사용.
    /// 게이지 기준 (성인 남성 가정)
    /// - 골격근량: 골격근/체중 비율 0.35 → 0.50
    /// - 체지방률: 30% → 10% (낮을수록 좋음)
    /// - SMI: 7.0 → 10.0 kg/m² (7.0 = AWGS 남성 근감소 기준)
    /// - 내장지방레벨: 15 → 1 (인바디 권장 < 10)
    /// - 인바디 점수: 60 → 100
    /// - 체중·체지방량·기초대사량: 게이지 없음
    static func bodyStats(_ logs: [BodyLog]) -> [BodyStat] {
        struct Spec {
            let label: String, unit: String, better: Better, decimals: Int
            let get: (BodyLog) -> Double?
            let gauge: ((Double, BodyLog) -> Double?)?
        }
        let specs: [Spec] = [
            Spec(label: "체중", unit: "kg", better: .neutral, decimals: 1,
                 get: { $0.weight > 0 ? $0.weight : nil }, gauge: nil),
            Spec(label: "골격근량", unit: "kg", better: .higher, decimals: 1,
                 get: { $0.skeletalMuscle },
                 gauge: { v, r in r.weight > 0 ? gauge(v / r.weight, 0.35, 0.50) : nil }),
            Spec(label: "체지방량", unit: "kg", better: .lower, decimals: 1,
                 get: { $0.bodyFatMass }, gauge: nil),
            Spec(label: "체지방률", unit: "%", better: .lower, decimals: 1,
                 get: { $0.bodyFatPercent }, gauge: { v, _ in gauge(v, 30, 10) }),
            Spec(label: "SMI", unit: "kg/m²", better: .higher, decimals: 1,
                 get: { $0.smi }, gauge: { v, _ in gauge(v, 7.0, 10.0) }),
            Spec(label: "내장지방", unit: "Lv", better: .lower, decimals: 0,
                 get: { $0.visceralLevel }, gauge: { v, _ in gauge(v, 15, 1) }),
            Spec(label: "인바디 점수", unit: "점", better: .higher, decimals: 0,
                 get: { $0.score }, gauge: { v, _ in gauge(v, 60, 100) }),
            Spec(label: "기초대사량", unit: "kcal", better: .higher, decimals: 0,
                 get: { $0.bmr }, gauge: nil),
        ]
        return specs.compactMap { sp in
            let rows = logs.compactMap { r in sp.get(r).map { (r, $0) } }
            guard let last = rows.last else { return nil }
            let prev = rows.count >= 2 ? rows[rows.count - 2].1 : nil
            let first = rows.count >= 2 ? rows[0].1 : nil
            return BodyStat(label: sp.label, unit: sp.unit, latest: last.1,
                            deltaPrev: prev.map { last.1 - $0 },
                            deltaFirst: first.map { last.1 - $0 },
                            better: sp.better,
                            gauge: sp.gauge?(last.1, last.0),
                            decimals: sp.decimals, latestDate: last.0.date)
        }
    }

    // MARK: 3. 유산소 능력

    /// 게이지 기준 (일반 성인 남성 가정, 좋은 쪽이 hi)
    static func vitalRange(_ k: VitalKind) -> (lo: Double, hi: Double)? {
        switch k {
        case .vo2Max:      (30, 55)     // ml/kg·min
        case .restingHR:   (80, 45)     // bpm, 낮을수록 좋음
        case .hrv:         (20, 80)     // ms SDNN
        case .hrRecovery:  (12, 40)     // 1분 회복 bpm
        case .walkingHR:   (115, 85)    // bpm, 낮을수록 좋음
        case .respiratory: (20, 12)     // 회/분, 낮을수록 좋음 (수면 중 기준)
        case .oxygen:      (90, 100)    // %
        case .wristTemp:   nil          // 기준선 대비 편차라 게이지 의미 없음
        }
    }

    /// 표시값 = 가장 최근 샘플 기준 7일 내 샘플 평균 (HRV·심박의 일간 잡음 완화).
    /// Δ = 표시값 − 첫 샘플 기준 7일 내 샘플 평균. 샘플 2개 미만이면 Δ 없음.
    /// 샘플이 없는 지표는 hasData = false (SE 1세대: 혈중 산소·손목 온도 센서 없음).
    static func vitalStats(_ logs: [VitalLog]) -> [VitalStat] {
        let grouped = Dictionary(grouping: logs, by: \.kind)
        return VitalKind.allCases.map { k in
            let s = (grouped[k] ?? []).sorted { $0.date < $1.date }
            guard let first = s.first, let last = s.last else {
                return VitalStat(kind: k, value: nil, delta: nil, count: 0, lastDate: nil, gauge: nil)
            }
            let span = Double(vitalAvgDays) * 86_400
            let recent = mean(s.filter { $0.date >= last.date.addingTimeInterval(-span) }.map(\.value))!
            let base = mean(s.filter { $0.date <= first.date.addingTimeInterval(span) }.map(\.value))!
            let g = vitalRange(k).map { gauge(recent, $0.lo, $0.hi) }
            return VitalStat(kind: k, value: recent,
                             delta: s.count >= 2 ? recent - base : nil,
                             count: s.count, lastDate: last.date, gauge: g)
        }
    }

    /// 최근 28일 유산소 세션 요약. 최고 페이스는 1km 이상 세션의 평균 페이스 중 최소.
    static func cardioSummary(_ logs: [CardioLog], now: Date) -> CardioSummary {
        let r = logs.filter { $0.date >= daysAgo(recentDays, from: now) }
        return CardioSummary(
            sessions: r.count,
            km: r.reduce(0) { $0 + $1.distanceKm },
            minutes: r.reduce(0) { $0 + ($1.seconds ?? 0) } / 60,
            bestPace: r.filter { $0.distanceKm >= 1 }.compactMap(\.pace).filter { $0 > 0 }.min())
    }

    // MARK: 4. 근력

    /// 종목명 → 동작 패턴. 키워드 포함 여부, 위에서부터 먼저 걸리는 것.
    /// 순서가 중요: "숄더 프레스"는 오버헤드, "레그레이즈"는 코어, "레그프레스"는 스쿼트.
    static let patternKeywords: [(MovePattern, [String])] = [
        (.core,     ["레그레이즈", "레그 레이즈", "플랭크", "크런치", "싯업", "윗몸",
                     "plank", "crunch", "sit-up", "leg raise"]),
        (.overhead, ["숄더", "오버헤드", "밀리터리", "레터럴", "ohp", "overhead", "shoulder", "military",
                     "lateral"]),
        (.hinge,    ["데드", "루마니안", "rdl", "힙 쓰러스트", "힙쓰러스트", "굿모닝",
                     "deadlift", "hip thrust", "good morning"]),
        (.squat,    ["스쿼트", "레그프레스", "레그 프레스", "런지", "핵",
                     "squat", "leg press", "lunge"]),
        (.pull,     ["풀업", "친업", "턱걸이", "랫", "로우", "풀다운", "암풀",
                     "pull", "row", "lat", "chin"]),
        (.push,     ["벤치", "프레스", "딥스", "푸시업", "푸쉬업", "체스트", "플라이",
                     "bench", "press", "dip", "push", "chest"]),
    ]

    static func pattern(of name: String) -> MovePattern {
        let n = name.lowercased()
        for (p, keys) in patternKeywords where keys.contains(where: { n.contains($0) }) {
            return p
        }
        return .other
    }

    /// 체중 대비 e1RM "목표" 비율 (중급자 대략치, 남성 가정). 게이지 = 비율/목표, 1 에서 자름.
    static func relativeStandard(_ p: MovePattern) -> Double? {
        switch p {
        case .push:     1.25    // 벤치프레스 1.25×BW
        case .overhead: 0.75    // 오버헤드 프레스 0.75×BW
        case .pull:     1.0     // 로우/랫풀다운 1.0×BW
        case .hinge:    2.0     // 데드리프트 2.0×BW
        case .squat:    1.5     // 스쿼트 1.5×BW
        case .core, .other: nil
        }
    }

    static let unilateralSuffix = " (한쪽)"
    /// 화면 표시용: 식별 이름에서 한쪽 표기를 떼고 배지로 돌린다
    static func display(_ statName: String) -> (name: String, badges: [String]) {
        statName.hasSuffix(unilateralSuffix)
            ? (String(statName.dropLast(unilateralSuffix.count)), ["한쪽"])
            : (statName, [])
    }

    /// 종목 식별 이름. 한쪽 운동은 한쪽 기준 무게라 양손 종목과 섞이지 않게 구분한다.
    static func statName(_ l: LiftEntry) -> String {
        let n = l.name.trimmingCharacters(in: .whitespaces)
        return l.isUnilateral ? n + unilateralSuffix : n
    }

    /// 기록 한 건의 e1RM (liftStats 와 같은 반복 수 규칙)
    static func e1RM(of l: LiftEntry) -> Double {
        let log = LiftLog(date: .now, name: l.name, weight: l.weight, sets: l.sets, reps: l.reps,
                          done: l.done, isBW: l.isBW, repsList: l.repsList, rir: l.rir, weights: l.weightList)
        return log.e1RM
    }

    /// Epley 가 정확한 반복 수 상한 (LeSuer 1997: 한계까지 10회 이하)
    static let epleyMaxReps = 10

    /// Epley 1RM 추정: e1RM = w × (1 + reps/30). reps = 1 이면 w 그대로.
    /// reps 에는 "반복 + RIR" 을 넣는다. RIR 자기 보고 오차는 평균 약 1회(Halperin 2022)
    /// → 40kg 기준 약 1.3kg(3%).
    static func epley(_ w: Double, reps: Int) -> Double {
        reps <= 1 ? w : w * (1 + Double(reps) / 30)
    }

    /// Epley 역산: n회 가능한 무게 w_n = e1RM / (1 + n/30). n = 1 이면 e1RM.
    static func weightFor(reps n: Int, e1RM: Double) -> Double {
        n <= 1 ? e1RM : e1RM / (1 + Double(n) / 30)
    }

    /// 원판 단위 표시용 0.5kg 반올림
    static func plate(_ w: Double) -> Double { (w * 2).rounded() / 2 }

    static let rmTargets = [1, 5, 8, 10]

    /// 사용하는 기록: 해당 종목에 완료 세트(done > 0) 기록이 하나라도 있으면 그것만,
    /// 없으면(과거 가져온 기록 등) 모든 기록을 수행한 것으로 간주.
    static func usable(_ logs: [LiftLog]) -> [LiftLog] {
        let done = logs.filter { $0.done > 0 }
        return done.isEmpty ? logs : done
    }

    /// 종목별 최고 세트(e1RM 최대) → 1/5/8/10RM. 맨몸(isBW)·무게 0·반복 0 제외.
    /// Δ = 최근 28일 최고 e1RM − 28일 이전 최고 e1RM.
    static func liftStats(_ logs: [LiftLog], bodyweight: Double?, now: Date) -> [LiftStat] {
        let weighted = logs.filter { !$0.isBW && $0.weight > 0 && $0.effReps > 0 }
        let byName = Dictionary(grouping: weighted, by: { $0.name.trimmingCharacters(in: .whitespaces) })
        let cutoff = daysAgo(recentDays, from: now)
        return byName.compactMap { name, raw -> LiftStat? in
            let all = usable(raw)
            // (반복 + RIR) ≤ 10 인 세트만 기준으로 삼는다. 전부 초과면 어쩔 수 없이 전체에서 고른다.
            let inRange = all.filter { $0.effReps <= epleyMaxReps }
            let rows = inRange.isEmpty ? all : inRange
            let score = { (l: LiftLog) in l.e1RM }
            guard let best = rows.max(by: { score($0) < score($1) }) else { return nil }
            let e1 = score(best)
            let recent = rows.filter { $0.date >= cutoff }.map(score).max()
            let older = rows.filter { $0.date < cutoff }.map(score).max()
            let p = pattern(of: name)
            var g: Double? = nil
            if let bw = bodyweight, bw > 0, let std = relativeStandard(p) {
                g = min(1, (e1 / bw) / std)
            }
            return LiftStat(
                name: name, pattern: p,
                bestWeight: best.bestSet?.w ?? best.weight, bestReps: best.effReps, bestDate: best.date,
                e1RM: e1,
                rms: rmTargets.map { RMValue(reps: $0, weight: plate(weightFor(reps: $0, e1RM: e1))) },
                delta: (recent != nil && older != nil) ? recent! - older! : nil,
                gauge: g,
                lowConfidence: best.effReps > epleyMaxReps,
                lowerBound: !best.rirKnown)
        }
        .sorted { $0.e1RM > $1.e1RM }
    }

    /// 맨몸 종목: 최고 반복 수와 최고 추가 중량.
    static func bwLiftStats(_ logs: [LiftLog]) -> [BWLiftStat] {
        let bw = usable(logs.filter(\.isBW))
        return Dictionary(grouping: bw, by: \.name).map { name, rows in
            BWLiftStat(name: name, pattern: pattern(of: name),
                       bestReps: rows.flatMap(\.repsList).max() ?? rows.map(\.reps).max() ?? 0,
                       bestAdded: rows.map(\.weight).max() ?? 0)
        }
        .sorted { $0.name < $1.name }
    }

    /// 패턴별 세트 수. 세트 수 = done > 0 이면 done, 아니면 계획 세트(sets).
    /// 무게가 없는 맨몸 종목도 공평하게 비교하려고 kg 볼륨 대신 세트 수를 쓴다.
    /// 최근 28일 기록이 없으면 전체 기록으로 계산 (두 번째 반환값 false).
    static func patternVolumes(_ logs: [LiftLog], now: Date) -> ([PatternVolume], Bool) {
        let recent = logs.filter { $0.date >= daysAgo(recentDays, from: now) }
        let src = recent.isEmpty ? logs : recent
        var acc: [MovePattern: Int] = [:]
        for l in src {
            acc[pattern(of: l.name), default: 0] += l.done > 0 ? l.done : l.sets
        }
        let vols = MovePattern.allCases.compactMap { p -> PatternVolume? in
            let n = acc[p] ?? 0
            return (n == 0 && (p == .other || p == .core)) ? nil : PatternVolume(pattern: p, sets: n)
        }
        return (vols, !recent.isEmpty)
    }

    /// 균형 판정 규칙 (세트 수 기준)
    /// 1) 당기기 / (밀기 + 오버헤드) : < 0.8 → 당기기 부족, > 1.5 → 밀기 부족, 그 외 OK.
    ///    밀기류 0 & 당기기 > 0 → 밀기 없음. 둘 다 0 → 판정 안 함.
    /// 2) 하체(스쿼트+힌지) / 상체(밀기+오버헤드+당기기) < 0.4 → 하체 부족.
    /// 3) 스쿼트 패턴 0 → 경고. 힌지 패턴 0 → 경고. 오버헤드 0 → 참고.
    /// 4) 근력 비율(e1RM): 스쿼트 < 벤치 → 하체 근력 열세.
    ///    오버헤드 / 벤치 < 0.55 → 어깨 프레스 약함 (일반적 비율 0.6~0.7 가정).
    static func balanceFlags(volumes: [PatternVolume], lifts: [LiftStat]) -> [BalanceFlag] {
        func v(_ p: MovePattern) -> Double { Double(volumes.first { $0.pattern == p }?.sets ?? 0) }
        let push = v(.push) + v(.overhead)
        let pull = v(.pull)
        let upper = push + pull
        let lower = v(.squat) + v(.hinge)
        var out: [BalanceFlag] = []
        guard upper + lower > 0 else { return out }

        if push > 0 {
            let r = pull / push
            let rs = String(format: "%.2f", r)
            if r < 0.8 { out.append(.init(level: .warn, text: "당기기 부족 — 당기기/밀기 \(rs) (권장 ≥ 0.8)")) }
            else if r > 1.5 { out.append(.init(level: .info, text: "밀기 부족 — 당기기/밀기 \(rs)")) }
            else { out.append(.init(level: .ok, text: "밀기·당기기 균형 \(rs)")) }
        } else if pull > 0 {
            out.append(.init(level: .warn, text: "밀기 패턴 기록 없음"))
        }

        if upper > 0 {
            let r = lower / upper
            if r < 0.4 {
                out.append(.init(level: .warn, text: "하체 비중 부족 — 하체/상체 \(String(format: "%.2f", r)) (권장 ≥ 0.4)"))
            } else {
                out.append(.init(level: .ok, text: "상·하체 비중 \(String(format: "%.2f", r))"))
            }
        }

        if v(.squat) == 0 { out.append(.init(level: .warn, text: "스쿼트 패턴 없음 — 스쿼트·레그프레스·런지")) }
        if v(.hinge) == 0 { out.append(.init(level: .warn, text: "힌지 패턴 없음 — 데드리프트·RDL")) }
        if v(.overhead) == 0 { out.append(.init(level: .info, text: "오버헤드 프레스 기록 없음")) }

        func best(_ p: MovePattern) -> Double? { lifts.filter { $0.pattern == p }.map(\.e1RM).max() }
        if let b = best(.push), let s = best(.squat), s < b {
            out.append(.init(level: .warn, text: "스쿼트 e1RM 이 벤치보다 낮음"))
        }
        if let b = best(.push), let o = best(.overhead), b > 0, o / b < 0.55 {
            out.append(.init(level: .info, text: "오버헤드/벤치 \(String(format: "%.2f", o / b)) — 어깨 프레스 약함"))
        }
        return out
    }
}
