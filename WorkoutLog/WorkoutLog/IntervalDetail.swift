import Foundation

// MARK: - 저장 형식

/// 인터벌 한 구간. 애플 운동 앱 사용자 설정 세션의 HKWorkoutActivity 하나에 대응한다.
struct IntervalSegment: Codable, Hashable, Identifiable {
    enum Kind: String, Codable { case warmup, work, recovery, cooldown }

    var kindRaw: String
    var round: Int               // 몇 번째 반복 (1부터). 워밍업·쿨다운은 0
    var start: Double            // 세션 시작 후 초
    var seconds: Double
    var completed: Bool = true   // 목표(시간·거리)를 채웠는지
    // HealthKit 이 구간별로 계산해 둔 통계
    var meters: Double = 0
    var avgHR: Double = 0
    var maxHR: Double = 0
    var avgPower: Double = 0
    var maxPower: Double = 0
    var avgSpeed: Double = 0     // m/s
    var maxSpeed: Double = 0
    var steps: Double = 0
    var avgStride: Double = 0    // m
    var avgGCT: Double = 0       // ms
    var avgVertOsc: Double = 0   // cm

    var kind: Kind { Kind(rawValue: kindRaw) ?? .work }
    var id: Double { start }
    var end: Double { start + seconds }
    /// 초/km. 구간 경계에서 거리 샘플이 앞뒤로 쏠려 거리÷시간은 부정확하므로 속도 센서 평균을 우선한다.
    var pace: Int? {
        if avgSpeed > 0.3 { return Int(1000 / avgSpeed) }
        return meters > 5 ? Int(seconds * 1000 / meters) : nil
    }
    /// spm
    var cadence: Int { seconds > 0 ? Int(steps / seconds * 60) : 0 }
}

/// 본운동 직전에 따로 뛴 워밍업 러닝.
struct WarmupRun: Codable, Hashable {
    struct Pause: Codable, Hashable { var from: Double; var to: Double }

    var healthKitUUID: String
    var startAt: Date
    var endAt: Date
    var seconds: Double          // 활동 시간 (일시정지 제외)
    var meters: Double = 0
    var activeKcal: Double = 0
    var pauses: [Pause] = []
    // 시계열. t = 워밍업 시작 후 초
    var hr: [MetricPoint] = []
    var speed: [MetricPoint] = []
    var power: [MetricPoint] = []

    var pausedSeconds: Double { pauses.reduce(0) { $0 + ($1.to - $1.from) } }
    var pace: Int? { meters > 5 ? Int(seconds * 1000 / meters) : nil }
    func isPaused(_ t: Double) -> Bool { pauses.contains { t >= $0.from && t <= $0.to } }
}

/// 인터벌 세션 전체 (계획 + 구간 + 워밍업)
struct IntervalDetail: Codable, Hashable {
    var planName: String?
    var plannedWorkSeconds: Double?
    var plannedRecoverySeconds: Double?
    var plannedSets: Int?
    var segments: [IntervalSegment] = []
    var warmup: WarmupRun?

    var work: [IntervalSegment] { segments.filter { $0.kind == .work } }
    var recoveries: [IntervalSegment] { segments.filter { $0.kind == .recovery } }

    /// "30초 질주 · 2:30 회복 × 5"
    var planSummary: String {
        let w = plannedWorkSeconds ?? work.first?.seconds.rounded() ?? 0
        let r = plannedRecoverySeconds ?? recoveries.first?.seconds.rounded() ?? 0
        let n = plannedSets ?? work.count
        return "\(Self.dur(w)) 질주 · \(Self.dur(r)) 회복 × \(n)"
    }
    private static func dur(_ s: Double) -> String {
        let v = Int(s.rounded())
        if v < 60 { return "\(v)초" }
        return v % 60 == 0 ? "\(v / 60)분" : String(format: "%d:%02d", v / 60, v % 60)
    }
}

// MARK: - 분석

/// 질주 1회 + 뒤따르는 회복 1회
struct IntervalRep: Identifiable, Hashable {
    var round: Int
    var work: IntervalSegment
    var recovery: IntervalSegment?
    /// 질주 중~직후 최고 심박. 심박은 질주보다 10~20초 늦게 정점에 닿으므로 회복 초반까지 본다.
    var peakHR: Double
    var peakAt: Double
    /// 정점 후 60초 동안 떨어진 심박 (bpm). 음수면 회복 중 오히려 올라간 것. 회복이 60초 미만이면 nil
    var drop60: Double?
    /// 다음 질주 직전(회복 끝) 심박
    var hrBeforeNext: Double?
    var id: Int { round }
}

struct IntervalReport {
    var reps: [IntervalRep]
    var cooldown: IntervalSegment?

    // 질주 합산
    var workSeconds: Double
    var workMeters: Double
    var workPace: Int?           // 초/km
    var workPower: Double        // 시간가중 평균 W
    var workMaxPower: Double
    var workHR: Double           // 시간가중 평균 bpm
    var workPeakHR: Double
    var workMaxSpeed: Double     // m/s
    // 회복 합산
    var recoverySeconds: Double
    var recoveryPace: Int?
    var recoveryHR: Double
    var avgDrop60: Double?
    var avgHRBeforeNext: Double?

    // 인터벌 품질 지표
    /// 마지막 질주 평균 파워 ÷ 첫 질주 (%)
    var powerHold: Double?
    /// 질주 속도 변동계수 (%). 낮을수록 고르게 뛴 것
    var speedCV: Double?
    /// 마지막 질주 최고심박 − 첫 질주 최고심박
    var peakHRDrift: Double?
    /// 첫 회복 60초 하락 − 마지막 회복 60초 하락. 양수면 뒤로 갈수록 회복이 느려진 것
    var recoveryFade: Double?
    var completedSets: Int
}

struct WarmupReport {
    enum Verdict { case good, normal, heavy }
    var seconds: Double
    var meters: Double
    var pace: Int?
    var avgHR: Double
    var endHR: Double?
    var avgPower: Double
    /// 마지막 5분(안정 구간) 평균 심박·페이스, 최대심박 대비 %
    var steadyHR: Double?
    var steadyPace: Int?
    var steadyPct: Double?
    /// 효율 (m/min ÷ bpm, 안정 구간). 같은 심박에서 얼마나 빨리 달렸나
    var ef: Double?
    /// 활동 5분 이후 전반 대비 후반 효율 저하 (%). 5% 미만이면 안정
    var decoupling: Double?
    /// 과거 워밍업 평균 효율 대비 (%). 기록 없으면 nil
    var efVsHistory: Double?
    var historyCount: Int
    var gapToMain: Double?       // 워밍업 끝 → 본운동 시작 (초)
    var verdict: Verdict
    var reasons: [String]
}

enum IntervalAnalysis {

    static func report(_ d: IntervalDetail, hr rawHR: [MetricPoint]) -> IntervalReport {
        let hr = rawHR.filter { $0.v > 0 }.sorted { $0.t < $1.t }
        let segs = d.segments.sorted { $0.start < $1.start }
        var reps: [IntervalRep] = []
        for (i, w) in segs.enumerated() where w.kind == .work {
            let next = i + 1 < segs.count ? segs[i + 1] : nil
            let rec = next?.kind == .recovery ? next : nil
            let limit = rec?.end ?? w.end
            let window = hr.filter { $0.t >= w.start && $0.t <= min(w.end + 25, limit) }
            let peak = window.max { $0.v < $1.v }
            var drop: Double?
            if let p = peak, let r = rec, p.t + 60 <= r.end, let v = value(hr, at: p.t + 60) {
                drop = p.v - v
            }
            let before = rec.flatMap { r in hr.last { $0.t <= r.end && $0.t >= r.start }?.v }
            reps.append(IntervalRep(round: reps.count + 1, work: w, recovery: rec,
                                    peakHR: peak?.v ?? w.maxHR, peakAt: peak?.t ?? w.start,
                                    drop60: drop, hrBeforeNext: before))
        }

        let works = reps.map(\.work)
        let recs = reps.compactMap(\.recovery)
        let wSec = works.reduce(0) { $0 + $1.seconds }
        let wM = works.reduce(0) { $0 + $1.meters }
        let rSec = recs.reduce(0) { $0 + $1.seconds }
        let rM = recs.reduce(0) { $0 + $1.meters }
        let speeds = works.filter { $0.seconds > 0 }.map { $0.meters / $0.seconds }
        let drops = reps.compactMap(\.drop60)
        let befores = reps.compactMap(\.hrBeforeNext)

        var hold: Double?
        if let f = works.first?.avgPower, let l = works.last?.avgPower, f > 0, works.count > 1 {
            hold = l / f * 100
        }
        var drift: Double?
        if reps.count > 1, let f = reps.first?.peakHR, let l = reps.last?.peakHR { drift = l - f }
        var fade: Double?
        if drops.count > 1 { fade = drops.first! - drops.last! }

        return IntervalReport(
            reps: reps,
            cooldown: segs.last { $0.kind == .cooldown },
            workSeconds: wSec, workMeters: wM,
            workPace: pace(works, meters: wM, seconds: wSec),
            workPower: weighted(works, \.avgPower),
            workMaxPower: works.map(\.maxPower).max() ?? 0,
            workHR: weighted(works, \.avgHR),
            workPeakHR: reps.map(\.peakHR).max() ?? 0,
            workMaxSpeed: works.map(\.maxSpeed).max() ?? 0,
            recoverySeconds: rSec,
            recoveryPace: pace(recs, meters: rM, seconds: rSec),
            recoveryHR: weighted(recs, \.avgHR),
            avgDrop60: drops.isEmpty ? nil : drops.reduce(0, +) / Double(drops.count),
            avgHRBeforeNext: befores.isEmpty ? nil : befores.reduce(0, +) / Double(befores.count),
            powerHold: hold,
            speedCV: cv(speeds),
            peakHRDrift: drift,
            recoveryFade: fade,
            completedSets: works.filter(\.completed).count)
    }

    /// 워밍업 컨디션. history = 이전 워밍업들 (비교 기준), estMax = 최대심박 추정
    static func warmup(_ w: WarmupRun, mainStart: Date?, history: [WarmupRun],
                       estMax: Double) -> WarmupReport {
        let hr = w.hr.filter { $0.v > 0 && !w.isPaused($0.t) }.sorted { $0.t < $1.t }
        let pw = w.power.filter { $0.v > 0 && !w.isPaused($0.t) }
        let avgHR = mean(hr.map(\.v)) ?? 0
        let steady = steadyWindow(w)
        let ef = efficiency(w)
        let dec = decoupling(w)
        let pct = steady.map { $0.hr / estMax * 100 }

        let pastEF = history.compactMap(efficiency)
        var vsHist: Double?
        if let e = ef, let base = mean(pastEF), base > 0 { vsHist = (e - base) / base * 100 }

        var reasons: [String] = []
        var score = 0
        if let v = vsHist {
            if v >= 3 { score += 1; reasons.append(String(format: "같은 심박 대비 속도가 평소보다 %.0f%% 빠름", v)) }
            else if v <= -3 { score -= 1; reasons.append(String(format: "같은 심박 대비 속도가 평소보다 %.0f%% 느림", -v)) }
            else { reasons.append("심박 대비 속도가 평소 수준") }
        } else {
            reasons.append("비교할 이전 워밍업 없음 — 이번 기록이 기준이 됨")
        }
        if let p = pct, let s = steady {
            let pace = s.pace.map { " (\(paceText($0))/km)" } ?? ""
            if p < 80 { score += 1; reasons.append(String(format: "마지막 5분 심박 %.0f = 최대의 %.0f%%%@ — 가볍게 뜀", s.hr, p, pace)) }
            else if p > 88 { score -= 1; reasons.append(String(format: "마지막 5분 심박 %.0f = 최대의 %.0f%%%@ — 워밍업치고 높음", s.hr, p, pace)) }
            else { reasons.append(String(format: "마지막 5분 심박 %.0f = 최대의 %.0f%%%@", s.hr, p, pace)) }
        }
        if let d = dec {
            if d < 5 { score += 1; reasons.append(String(format: "심박-속도 분리 %.1f%% — 안정", d)) }
            else if d > 10 { score -= 1; reasons.append(String(format: "심박-속도 분리 %.1f%% — 같은 속도인데 심박이 계속 오름", d)) }
            else { reasons.append(String(format: "심박-속도 분리 %.1f%% — 보통", d)) }
        }
        if w.pausedSeconds >= 60 {
            reasons.append("중간 정지 \(Int((w.pausedSeconds / 60).rounded()))분")
        }
        var gap: Double?
        if let m = mainStart {
            let g = m.timeIntervalSince(w.endAt)
            gap = g
            if g > 15 * 60 { reasons.append("본운동까지 \(Int(g / 60))분 쉼 — 워밍업 효과가 식었을 수 있음") }
        }
        let verdict: WarmupReport.Verdict = score > 0 ? .good : score < 0 ? .heavy : .normal

        return WarmupReport(seconds: w.seconds, meters: w.meters, pace: w.pace,
                            avgHR: avgHR, endHR: hr.last?.v,
                            avgPower: mean(pw.map(\.v)) ?? 0,
                            steadyHR: steady?.hr, steadyPace: steady?.pace, steadyPct: pct,
                            ef: ef, decoupling: dec, efVsHistory: vsHist,
                            historyCount: pastEF.count, gapToMain: gap,
                            verdict: verdict, reasons: reasons)
    }

    // MARK: 도우미

    /// 마지막 5분(활동 시간 기준) 평균 심박·속도
    static func steadyWindow(_ w: WarmupRun) -> (hr: Double, speed: Double, pace: Int?)? {
        guard w.seconds >= 360 else { return nil }
        let from = firstActive(w, after: w.seconds - 300)
        let hr = w.hr.filter { $0.v > 0 && $0.t >= from && !w.isPaused($0.t) }.map(\.v)
        let sp = w.speed.filter { $0.v > 0 && $0.t >= from && !w.isPaused($0.t) }.map(\.v)
        guard let h = mean(hr), let s = mean(sp), s > 0 else { return nil }
        return (h, s, Int(1000 / s))
    }

    /// 워밍업 효율: 안정 구간 평균 속도(m/min) ÷ 평균 심박
    static func efficiency(_ w: WarmupRun) -> Double? {
        guard let s = steadyWindow(w), s.hr > 0 else { return nil }
        return s.speed * 60 / s.hr
    }

    /// 활동 5분 이후를 반으로 나눈 전반·후반 효율 차이 (%). 초반 심박 상승 구간은 뺀다.
    static func decoupling(_ w: WarmupRun) -> Double? {
        guard w.seconds >= 600 else { return nil }
        let from = firstActive(w, after: 300)
        let hr = w.hr.filter { $0.v > 0 && $0.t >= from && !w.isPaused($0.t) }
        let sp = w.speed.filter { $0.v > 0 && $0.t >= from && !w.isPaused($0.t) }
        guard hr.count >= 6, sp.count >= 6,
              let a = hr.first?.t, let b = hr.last?.t, b - a > 180 else { return nil }
        let mid = (a + b) / 2
        func ef(_ lo: Double, _ hi: Double) -> Double? {
            guard let h = mean(hr.filter { $0.t >= lo && $0.t < hi }.map(\.v)),
                  let s = mean(sp.filter { $0.t >= lo && $0.t < hi }.map(\.v)), h > 0 else { return nil }
            return s / h
        }
        guard let e1 = ef(a, mid), let e2 = ef(mid, b + 1), e1 > 0 else { return nil }
        return (e1 - e2) / e1 * 100
    }

    static func paceText(_ secPerKm: Int) -> String {
        String(format: "%d:%02d", secPerKm / 60, secPerKm % 60)
    }

    /// 일시정지를 제외한 활동 시간이 `after` 초 지난 시점 (워밍업 시작 기준 초)
    private static func firstActive(_ w: WarmupRun, after: Double) -> Double {
        var t = 0.0, active = 0.0
        let step = 1.0
        let total = w.endAt.timeIntervalSince(w.startAt)
        while t < total {
            if !w.isPaused(t) { active += step; if active >= after { return t } }
            t += step
        }
        return 0
    }

    /// 선형 보간한 t 시점 값
    static func value(_ s: [MetricPoint], at t: Double) -> Double? {
        guard let i = s.firstIndex(where: { $0.t >= t }) else { return nil }
        if i == 0 { return s[0].v }
        let a = s[i - 1], b = s[i]
        let f = b.t > a.t ? (t - a.t) / (b.t - a.t) : 0
        return a.v + (b.v - a.v) * f
    }

    /// 구간들의 시간가중 평균 속도로 페이스. 속도 없으면 거리÷시간.
    private static func pace(_ segs: [IntervalSegment], meters: Double, seconds: Double) -> Int? {
        let v = weighted(segs, \.avgSpeed)
        if v > 0.3 { return Int(1000 / v) }
        return meters > 5 ? Int(seconds * 1000 / meters) : nil
    }

    private static func weighted(_ segs: [IntervalSegment], _ k: KeyPath<IntervalSegment, Double>) -> Double {
        let ok = segs.filter { $0[keyPath: k] > 0 }
        let t = ok.reduce(0) { $0 + $1.seconds }
        return t > 0 ? ok.reduce(0) { $0 + $1[keyPath: k] * $1.seconds } / t : 0
    }

    private static func mean(_ a: [Double]) -> Double? {
        a.isEmpty ? nil : a.reduce(0, +) / Double(a.count)
    }

    private static func cv(_ a: [Double]) -> Double? {
        guard a.count > 1, let m = mean(a), m > 0 else { return nil }
        let v = a.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(a.count)
        return v.squareRoot() / m * 100
    }
}
