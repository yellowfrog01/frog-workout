import SwiftUI

// MARK: - 프로그램 값 타입 (앱에 내장된 정적 데이터)

enum ProgramKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case strength, cardio
    var id: String { rawValue }
    var label: String { self == .strength ? "근력" : "유산소" }
    var symbol: String { self == .strength ? "dumbbell.fill" : "figure.run" }
    var tint: Color { self == .strength ? Palette.strength : Palette.interval }
    var workoutKind: WorkoutKind { self == .strength ? .strength : .interval }
}

/// 프로그램이 지정한 한 종목
struct ProgramLift: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sets: Int
    var reps: Int
    /// 1RM 대비 비율. 프로그램이 %로 지정하지 않으면 nil
    var pct1RM: Double? = nil
    var rir: Int? = nil
    var bw: Bool = false
    var uni: Bool = false
    var restSeconds: Int = 120
    var note: String = ""

    /// "5×5 · 80% · 휴식 3:00"
    var spec: String {
        var parts = ["\(sets)×\(reps)"]
        if let p = pct1RM { parts.append("\(Int((p * 100).rounded()))%") }
        if let r = rir { parts.append("RIR \(r)") }
        if restSeconds > 0 { parts.append("휴식 \(restSeconds.clockString)") }
        return parts.joined(separator: " · ")
    }
    var badges: [String] { (bw ? ["BW"] : []) + (uni ? ["한쪽"] : []) }

    /// 기록용 종목으로 변환. 무게는 과거 기록·1RM 으로 따로 채운다.
    func entry(weight: Double) -> LiftEntry {
        LiftEntry(name: name, weight: weight, sets: sets, reps: reps,
                  bw: bw ? true : nil, uni: uni ? true : nil)
    }
}

/// 프로그램이 지정한 유산소 한 세션
struct ProgramCardio: Hashable {
    var mode: CardioMode
    var workSeconds: Int = 0
    var intensityPct: Int = 0
    var restSeconds: Int = 0
    var recoveryPaceSec: Int? = nil
    var sets: Int = 0
    var minutes: Int = 0
    var paceSec: Int? = nil
    var note: String = ""

    var spec: String {
        var parts: [String] = []
        if mode == .interval {
            parts.append("\(workSeconds.clockString) × \(sets)")
            if intensityPct > 0 { parts.append("최대심박 \(intensityPct)%") }
            if restSeconds > 0 { parts.append("회복 \(restSeconds.clockString)") }
        } else {
            if minutes > 0 { parts.append("\(minutes)분") }
            if intensityPct > 0 { parts.append("최대심박 \(intensityPct)%") }
            if let p = paceSec { parts.append("\(p.clockString)/km") }
        }
        return parts.joined(separator: " · ")
    }

    /// 인터벌 기록 구조로 변환
    var intervalEntry: IntervalEntry? {
        guard mode == .interval else { return nil }
        return IntervalEntry(workSeconds: workSeconds,
                             intensity: intensityPct,
                             restSeconds: restSeconds,
                             recoveryPace: recoveryPaceSec ?? 360,
                             sets: sets)
    }
}

struct ProgramDay: Identifiable, Hashable {
    var id = UUID()
    var label: String
    var focus: String = ""
    var note: String = ""
    var lifts: [ProgramLift] = []
    var cardio: ProgramCardio? = nil

    /// "A · 전신"
    var heading: String { focus.isEmpty ? label : "\(label) · \(focus)" }
    /// 같은 날인지 비교하는 기준 (UUID 는 무시)
    var signature: String {
        let l = lifts.map { "\($0.name)|\($0.sets)|\($0.reps)" }.joined(separator: ",")
        return [label, focus, l, cardio?.spec ?? ""].joined(separator: "#")
    }
    var spec: String {
        if let c = cardio { return c.spec }
        return "\(lifts.count)종목"
    }
}

struct ProgramReview: Identifiable, Hashable {
    var id = UUID()
    var source: String
    var rating: Int
    var text: String
}

struct WorkoutProgram: Identifiable, Hashable {
    var id: String
    var title: String
    var kind: ProgramKind
    var goal: String
    var level: String
    var weeks: Int
    var daysPerWeek: Int
    var author: String
    var origin: String
    var summary: String
    var detail: String
    var progression: String
    var tags: [String]
    var days: [ProgramDay]
    var reviews: [ProgramReview]

    var weeksLabel: String { weeks == 0 ? "무기한" : "\(weeks)주" }
    var scheduleLabel: String { "주 \(daysPerWeek)회 · \(weeksLabel)" }
    /// 리뷰 평균 별점
    var rating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)
    }
    var detailParagraphs: [String] {
        detail.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    /// 반복 주기. A·B·A 처럼 한 주 목록이 주기의 배수가 아닐 때
    /// 다음 주가 B·A·B 로 이어지도록 실제 주기만 잘라낸다.
    var cycle: [ProgramDay] {
        let sigs = days.map(\.signature)
        for p in 1..<max(2, days.count) {
            if (0..<sigs.count).allSatisfy({ sigs[$0] == sigs[$0 % p] }) {
                return Array(days.prefix(p))
            }
        }
        return days
    }

    var liftNames: [String] {
        var seen = Set<String>()
        return days.flatMap(\.lifts).map(\.name).filter { seen.insert($0).inserted }
    }
}

extension ProgramCatalog {
    static func all(_ kind: ProgramKind) -> [WorkoutProgram] {
        programs.filter { $0.kind == kind }
    }
    static func find(_ id: String) -> WorkoutProgram? { programs.first { $0.id == id } }
}
