import Foundation
import SwiftData

/// 앞으로 할 운동 한 건. 실제 기록(Session)과 분리해서 저장한다.
@Model
final class PlannedWorkout {
    /// 예정일 (하루 단위, 자정)
    var date: Date = Date()
    var kindRaw: String = WorkoutKind.strength.rawValue
    /// "A · 전신"
    var title: String = ""
    var programID: String?
    var programTitle: String?
    /// 프로그램 안에서 몇 주차인지 (1부터)
    var week: Int = 1
    var liftsData: [LiftEntry]?
    var interval: IntervalEntry?
    var cardioModeRaw: String?
    /// 일반 유산소의 목표 시간(분)
    var cardioMinutes: Int?
    /// 목표 강도 (최대심박 %)
    var intensityPct: Int?
    var note: String = ""
    /// 이 계획으로 운동을 시작한 시각. 채워지면 예정 목록에서 빠진다.
    var startedAt: Date?
    var createdAt: Date = Date()

    init(date: Date,
         kind: WorkoutKind,
         title: String,
         programID: String? = nil,
         programTitle: String? = nil,
         week: Int = 1,
         lifts: [LiftEntry] = [],
         interval: IntervalEntry? = nil,
         cardioMode: CardioMode? = nil,
         cardioMinutes: Int? = nil,
         intensityPct: Int? = nil,
         note: String = "") {
        self.date = Calendar.current.startOfDay(for: date)
        self.kindRaw = kind.rawValue
        self.title = title
        self.programID = programID
        self.programTitle = programTitle
        self.week = week
        self.liftsData = lifts.isEmpty ? nil : lifts
        self.interval = interval
        self.cardioModeRaw = cardioMode?.rawValue
        self.cardioMinutes = cardioMinutes
        self.intensityPct = intensityPct
        self.note = note
        self.createdAt = .now
    }

    var kind: WorkoutKind {
        get { WorkoutKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }
    var cardioMode: CardioMode? {
        get { cardioModeRaw.flatMap(CardioMode.init(rawValue:)) }
        set { cardioModeRaw = newValue?.rawValue }
    }
    var lifts: [LiftEntry] {
        get { liftsData ?? [] }
        set { liftsData = newValue.isEmpty ? nil : newValue }
    }
    var isDone: Bool { startedAt != nil }
    var isOverdue: Bool {
        !isDone && date < Calendar.current.startOfDay(for: .now)
    }

    /// "4종목 · 12세트" · "30초 100% · 2:30 @6:00/km × 5set"
    var spec: String {
        if kind == .strength {
            let sets = lifts.reduce(0) { $0 + $1.sets }
            return lifts.isEmpty ? "종목 없음" : "\(lifts.count)종목 · \(sets)세트"
        }
        if let iv = interval { return iv.summary }
        var parts: [String] = []
        if let m = cardioMinutes { parts.append("\(m)분") }
        if let i = intensityPct, i > 0 { parts.append("최대심박 \(i)%") }
        return parts.isEmpty ? (cardioMode?.label ?? "유산소") : parts.joined(separator: " · ")
    }
    /// 남은 일수. 오늘이면 0, 지났으면 음수.
    var daysAway: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: date).day ?? 0
    }
    var whenLabel: String {
        switch daysAway {
        case 0: "오늘"
        case 1: "내일"
        case 2...6: "\(daysAway)일 후"
        case ..<0: "\(-daysAway)일 지남"
        default: date.monthDay
        }
    }
}

// MARK: - 프로그램 → 계획 생성

enum PlanBuilder {
    /// 프로그램을 시작일·요일에 맞춰 계획으로 펼친다.
    /// days 는 순서대로 계속 돌린다 (A·B·A → 다음 주 B·A·B).
    /// - Parameters:
    ///   - weekdays: 1(일) ~ 7(토)
    ///   - weeks: 만들 주 수
    ///   - history: 무게를 채울 과거 기록
    static func make(program: WorkoutProgram,
                     from start: Date,
                     weekdays: [Int],
                     weeks: Int,
                     history: [Session]) -> [PlannedWorkout] {
        let cal = Calendar.current
        let days = program.cycle
        guard !days.isEmpty, !weekdays.isEmpty, weeks > 0 else { return [] }
        let weights = lastWeights(history)
        let sorted = weekdays.sorted()
        let startDay = cal.startOfDay(for: start)
        var out: [PlannedWorkout] = []
        var n = 0

        for w in 0..<weeks {
            guard let base = cal.date(byAdding: .day, value: w * 7,
                                      to: weekStart(of: startDay, cal: cal)) else { continue }
            let baseWD = cal.component(.weekday, from: base)
            for wd in sorted {
                let offset = (wd - baseWD + 7) % 7
                guard let date = cal.date(byAdding: .day, value: offset, to: base) else { continue }
                if date < startDay { continue }
                let day = days[n % days.count]
                n += 1
                out.append(build(day, of: program, on: date, week: w + 1, weights: weights))
            }
        }
        // 시작일 주에 해당 요일이 남아 있지 않으면 첫 주가 통째로 비므로,
        // 실제로 만들어진 주만 1주차부터 다시 번호를 매긴다.
        let used = Set(out.map(\.week)).sorted()
        let renumber = Dictionary(uniqueKeysWithValues: used.enumerated().map { ($1, $0 + 1) })
        for p in out { p.week = renumber[p.week] ?? p.week }
        return out.sorted { $0.date < $1.date }
    }

    /// 주어진 날이 속한 주의 첫날
    private static func weekStart(of day: Date, cal: Calendar) -> Date {
        let back = (cal.component(.weekday, from: day) - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -back, to: day) ?? day
    }

    private static func build(_ day: ProgramDay, of program: WorkoutProgram,
                              on date: Date, week: Int,
                              weights: [String: Double]) -> PlannedWorkout {
        if let c = day.cardio {
            return PlannedWorkout(
                date: date, kind: .interval, title: day.heading,
                programID: program.id, programTitle: program.title, week: week,
                interval: c.intervalEntry,
                cardioMode: c.mode,
                cardioMinutes: c.mode == .steady ? c.minutes : nil,
                intensityPct: c.intensityPct > 0 ? c.intensityPct : nil,
                note: [day.note, c.note].filter { !$0.isEmpty }.joined(separator: " · "))
        }
        let lifts = day.lifts.map { $0.entry(weight: weights[key($0.name)] ?? 0) }
        return PlannedWorkout(
            date: date, kind: .strength, title: day.heading,
            programID: program.id, programTitle: program.title, week: week,
            lifts: lifts, note: day.note)
    }

    private static func key(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// 종목별 최근 사용 무게
    static func lastWeights(_ history: [Session]) -> [String: Double] {
        var out: [String: Double] = [:]
        for s in history.sorted(by: { $0.date > $1.date }) {
            for l in s.lifts where out[key(l.name)] == nil {
                out[key(l.name)] = l.weight
            }
        }
        return out
    }
}
