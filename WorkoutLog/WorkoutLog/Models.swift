import Foundation
import SwiftData

// MARK: - 열거형

enum Condition: String, Codable, CaseIterable, Identifiable {
    case good, normal, bad
    var id: String { rawValue }
    var label: String {
        switch self {
        case .good: "굳"
        case .normal: "보통"
        case .bad: "별로"
        }
    }
    var symbol: String {
        switch self {
        case .good: "flame.fill"
        case .normal: "equal.circle.fill"
        case .bad: "battery.25percent"
        }
    }
}

enum WorkoutKind: String, Codable, CaseIterable, Identifiable {
    case strength, interval, activity
    var id: String { rawValue }
    var label: String {
        switch self {
        case .strength: "근력"
        case .interval: "인터벌"
        case .activity: "기타 운동"
        }
    }
    var symbol: String {
        switch self {
        case .strength: "figure.strengthtraining.traditional"
        case .interval: "figure.run"
        case .activity: "figure.mixed.cardio"
        }
    }
}

enum CardioMode: String, Codable, CaseIterable, Identifiable {
    case interval, steady
    var id: String { rawValue }
    var label: String { self == .interval ? "인터벌" : "일반" }
    var symbol: String { self == .interval ? "stopwatch.fill" : "figure.run" }
    var desc: String {
        self == .interval ? "고강도·회복 반복" : "일정 페이스로 지속"
    }
}

enum BodyPart: String, Codable, CaseIterable, Identifiable {
    case upper, lower, full
    var id: String { rawValue }
    var label: String {
        switch self {
        case .upper: "상체"
        case .lower: "하체"
        case .full: "전신"
        }
    }
}

// MARK: - 값 타입 (SwiftData 속성으로 임베드)

struct LiftEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var weight: Double      // kg
    var sets: Int
    var reps: Int
    var done: Int = 0       // 완료한 세트 수
    var bw: Bool? = nil     // 맨몸 운동 여부. 무게는 "추가 중량"을 뜻함.
    /// 세트별 실제 반복 수 (8-8-7-7). nil 이면 모든 세트가 reps 로 같다.
    var setReps: [Int]? = nil
    /// 세트별 무게 (65, 65, 67.5). nil 이면 모든 세트가 weight 로 같다. weight 는 항상 이 중 최댓값.
    var setWeights: [Double]? = nil
    /// 마지막 세트의 여유 반복 수(RIR). 4 는 "4 이상".
    var rir: Int? = nil
    /// 세트 완료 시각 (epoch 초). 실제 휴식 시간 계산용.
    var doneAt: [Double]? = nil
    /// 원암·원레그처럼 한쪽씩 하는 종목. 무게·횟수는 한쪽 기준.
    var uni: Bool? = nil
    /// 종목 메모 [LiftMemo] 의 JSON (LiftMemo.swift 의 memos 로 읽고 쓴다)
    var memoData: String? = nil
    /// 이 종목 세트 후 목표 휴식(초). nil 이면 기본 휴식값
    var restSec: Int? = nil
    /// "다음 운동 시작"(웜업 시작)을 누른 시각 (epoch 초). 종목 소요 시간의 시작점
    var warmupAt: Double? = nil

    var isBW: Bool { bw ?? false }
    var isUnilateral: Bool { uni ?? false }
    var isVaried: Bool { setReps != nil || setWeights != nil }
    /// 세트별 반복 수. 같은 횟수 방식이면 reps 를 sets 번 반복.
    var repsList: [Int] { setReps ?? Array(repeating: reps, count: max(sets, 0)) }
    /// 세트별 무게. 길이는 sets (모자라면 마지막 값, 넘치면 자른다). 없으면 weight 반복.
    var weightList: [Double] {
        let n = max(sets, 0)
        guard let w = setWeights, !w.isEmpty else { return Array(repeating: weight, count: n) }
        if w.count >= n { return Array(w.prefix(n)) }
        return w + Array(repeating: w.last ?? weight, count: n - w.count)
    }
    /// i번째 세트 무게 (범위 밖이면 마지막 값)
    func weightAt(_ i: Int) -> Double {
        let l = weightList
        return i >= 0 && i < l.count ? l[i] : (l.last ?? weight)
    }
    /// 세트마다 무게가 다른가
    var hasMixedWeights: Bool { Set(weightList).count > 1 }
    /// "3×8" · "8-8-7-7" · 무게가 섞이면 "65kg 5-5 · 67.5kg 4-3"
    var repsLabel: String {
        if hasMixedWeights {
            let w = weightList, r = repsList
            var groups: [(Int, [Int])] = []   // (시작 세트, 횟수들)
            for i in 0..<w.count {
                let n = i < r.count ? r[i] : reps
                if let last = groups.last, w[last.0] == w[i] { groups[groups.count - 1].1.append(n) }
                else { groups.append((i, [n])) }
            }
            return groups.map { "\(weightLabel(at: $0.0)) \($0.1.map(String.init).joined(separator: "-"))" }
                .joined(separator: " · ")
        }
        return isVaried ? repsList.map(String.init).joined(separator: "-") : "\(sets)×\(reps)"
    }
    /// 세트 사이 실제 휴식의 평균(초). 완료 시각이 2개 이상일 때만.
    var avgRest: Int? {
        guard let t = doneAt, t.count >= 2 else { return nil }
        let gaps = zip(t.dropFirst(), t).map { $0 - $1 }.filter { $0 > 0 }
        guard !gaps.isEmpty else { return nil }
        return Int(gaps.reduce(0, +) / Double(gaps.count))
    }
    /// "3×8 · RIR 2 · 휴식 2:00" (휴식 = 목표 휴식)
    var repsDetail: String {
        var parts = [repsLabel]
        if let r = rir { parts.append("RIR \(r >= 4 ? "4+" : String(r))") }
        // 휴식은 종목에 정한 목표값(고정)만 표시한다
        if let a = restSec { parts.append("휴식 \(a / 60):\(String(format: "%02d", a % 60))") }
        return parts.joined(separator: " · ")
    }
    /// 세트 하나 완료 / 취소 (완료 시각도 함께 관리)
    mutating func markSetDone(at date: Date = .now) {
        guard done < sets else { return }
        done += 1
        doneAt = (doneAt ?? []) + [date.timeIntervalSince1970]
    }
    mutating func undoSet() {
        guard done > 0 else { return }
        done -= 1
        if var t = doneAt, !t.isEmpty { t.removeLast(); doneAt = t.isEmpty ? nil : t }
    }
    mutating func resetSets() {
        done = 0; rir = nil; doneAt = nil
    }
    /// 세트별 방식으로 전환 (현재 값을 그대로 옮긴다)
    mutating func setVaried(_ on: Bool) {
        if on {
            setReps = repsList
            if hasMixedWeights { setWeights = weightList }
        } else {
            weight = weightList.first ?? weight
            reps = setReps?.first ?? reps
            setWeights = nil
            setReps = nil
        }
    }
    /// weight = 세트별 최댓값. 전부 같으면 setWeights 를 비운다.
    private mutating func normalizeWeights() {
        let l = weightList
        guard let m = l.max() else { return }
        if Set(l).count <= 1 { setWeights = nil }
        weight = m
    }
    /// i번째 세트 무게만 바꾼다. 세트별 방식은 유지(횟수도 세트별로 고정).
    mutating func setWeight(_ w: Double, at i: Int) {
        guard i >= 0, i < sets else { return }
        if setReps == nil { setReps = repsList }
        var l = weightList
        l[i] = w
        setWeights = l
        normalizeWeights()
    }
    /// i번째 세트부터 끝까지 무게를 delta 만큼 올리거나 내린다 (0~400kg).
    mutating func shiftWeight(from i: Int, by delta: Double) {
        guard i >= 0, i < sets else { return }
        if setReps == nil { setReps = repsList }
        var l = weightList
        for k in i..<l.count { l[k] = min(400, max(0, l[k] + delta)) }
        setWeights = l
        normalizeWeights()
    }
    /// i번째 세트를 지운다. 세트별 횟수와 완료 기록도 같이 지운다 (세트가 1개면 그대로).
    mutating func removeSet(at i: Int) {
        guard sets > 1, i >= 0, i < sets else { return }
        if var l = setReps, i < l.count { l.remove(at: i); setReps = l }
        if var w = setWeights, i < w.count { w.remove(at: i); setWeights = w }
        if i < done {
            done -= 1
            if var t = doneAt, i < t.count { t.remove(at: i); doneAt = t.isEmpty ? nil : t }
        }
        sets -= 1
        done = min(done, sets)
        normalizeWeights()
    }
    /// 세트별 방식에서 세트 수를 바꾼다. 새 세트는 마지막 세트 횟수를 따른다.
    mutating func resizeSets(_ n: Int) {
        let n = max(1, n)
        if var list = setReps {
            if n > list.count { list += Array(repeating: list.last ?? reps, count: n - list.count) }
            else { list = Array(list.prefix(n)) }
            setReps = list
        }
        if var w = setWeights {
            if n > w.count { w += Array(repeating: w.last ?? weight, count: n - w.count) }
            else { w = Array(w.prefix(n)) }
            setWeights = w
        }
        sets = n
        done = min(done, n)
        normalizeWeights()
    }
    /// 맨몸이면 추가 중량만 볼륨으로 계산. 한쪽 운동은 양쪽을 합친다.
    var volume: Double {
        repsList.enumerated().reduce(0) { $0 + weightAt($1.offset) * Double($1.element) } * (isUnilateral ? 2 : 1)
    }
    /// 종목 속성 배지. 모든 화면에서 이름 옆에 같은 모양으로 붙인다.
    var badges: [String] { (isBW ? ["BW"] : []) + (isUnilateral ? ["한쪽"] : []) }
    /// 무게. 맨몸이면 추가 중량이라 항상 부호를 붙인다: "+0kg" · "+10kg" · "40kg"
    /// 세트마다 무게가 다르면 빈 문자열 (repsLabel 이 무게까지 보여준다).
    var weightLabel: String { hasMixedWeights ? "" : weightLabel(at: 0) }
    /// i번째 세트 무게 (weightLabel 과 같은 모양)
    func weightLabel(at i: Int) -> String {
        let w = weightAt(i)
        return isBW ? "+\(w.trimmed)kg" : "\(w.trimmed)kg"
    }
    /// 배지를 못 쓰는 텍스트 자리용: "BW +0kg" · "한쪽 15kg"
    var weightText: String { (badges + [weightLabel]).filter { !$0.isEmpty }.joined(separator: " ") }
    /// i번째 세트 기준 weightText
    func weightText(at i: Int) -> String { (badges + [weightLabel(at: i)]).joined(separator: " ") }
    var summary: String { [name, weightText, repsLabel].filter { !$0.isEmpty }.joined(separator: " ") }
}

struct IntervalEntry: Codable, Hashable {
    var workSeconds: Int = 30
    var intensity: Int = 100        // %
    var restSeconds: Int = 150      // 2:30
    var recoveryPace: Int = 360     // 회복 페이스, 초/km (360 = 6:00/km)
    var sets: Int = 5
    var done: Int = 0

    /// "30초 100% · 2:30 @6:00/km × 5set"
    var summary: String {
        "\(workSeconds)초 \(intensity)% · \(restSeconds.clockString) @\(recoveryPace.clockString)/km × \(sets)set"
    }
    var totalSeconds: Int { (workSeconds + restSeconds) * sets }


}

// MARK: - SwiftData 모델

@Model
final class Session {
    var date: Date = Date()
    var kindRaw: String = WorkoutKind.strength.rawValue
    var conditionRaw: String = Condition.normal.rawValue
    var bodyPartRaw: String?
    var liftsData: [LiftEntry]?
    var interval: IntervalEntry?
    var note: String = ""
    var startAt: Date?
    var endAt: Date?
    var cardioModeRaw: String?
    // 배열·구조체는 Optional 이어야 기존 저장분이 안전하게 마이그레이션된다
    var routeData: [RoutePoint]?
    var hrData: [HRPoint]?
    var distanceMeters: Double = 0
    var telemetryData: Telemetry?
    var watchSessionID: String?
    var healthKitUUID: String?
    /// 애플 운동 앱 인터벌(사용자 설정 세션) 구간·워밍업. JSON 으로 저장.
    var intervalDetailData: Data?
    /// 기타 운동 이름 (배드민턴, 등산 …). kind == .activity 일 때만 쓴다.
    var activityName: String?

    init(date: Date = .now,
         kind: WorkoutKind = .strength,
         condition: Condition = .normal,
         bodyPart: BodyPart? = nil,
         lifts: [LiftEntry] = [],
         interval: IntervalEntry? = nil,
         note: String = "",
         startAt: Date? = nil,
         endAt: Date? = nil,
         cardioMode: CardioMode? = nil,
         route: [RoutePoint] = [],
         hr: [HRPoint] = [],
         distanceMeters: Double = 0,
         telemetry: Telemetry = Telemetry()) {
        self.date = date
        self.kindRaw = kind.rawValue
        self.conditionRaw = condition.rawValue
        self.bodyPartRaw = bodyPart?.rawValue
        self.liftsData = lifts.isEmpty ? nil : lifts
        self.interval = interval
        self.note = note
        self.startAt = startAt
        self.endAt = endAt
        self.cardioModeRaw = cardioMode?.rawValue
        self.routeData = route.isEmpty ? nil : route
        self.hrData = hr.isEmpty ? nil : hr
        self.distanceMeters = distanceMeters
        self.telemetryData = telemetry.isEmpty ? nil : telemetry
    }

    var kind: WorkoutKind {
        get { WorkoutKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }
    var condition: Condition {
        get { Condition(rawValue: conditionRaw) ?? .normal }
        set { conditionRaw = newValue.rawValue }
    }
    var lifts: [LiftEntry] {
        get { liftsData ?? [] }
        set { liftsData = newValue.isEmpty ? nil : newValue }
    }
    var route: [RoutePoint] {
        get { routeData ?? [] }
        set { routeData = newValue.isEmpty ? nil : newValue }
    }
    var hr: [HRPoint] {
        get { hrData ?? [] }
        set { hrData = newValue.isEmpty ? nil : newValue }
    }
    var telemetry: Telemetry {
        get { telemetryData ?? Telemetry() }
        set { telemetryData = newValue.isEmpty ? nil : newValue }
    }
    var intervalDetail: IntervalDetail? {
        get { intervalDetailData.flatMap { try? JSONDecoder().decode(IntervalDetail.self, from: $0) } }
        set { intervalDetailData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    /// 기록상 날짜. 새벽 4시 전에 시작한 운동은 전날 운동으로 친다.
    var logicalDay: Date { Session.logicalDay(for: date) }
    static let dayCutoffHour = 4
    /// 기록 날짜 기준 시각. 다음 날 새벽이면 24시 이후로 표시한다 (00:01 → 24:01).
    func clock(_ d: Date) -> String {
        let base = Calendar.current.startOfDay(for: logicalDay)
        let mins = max(0, Int(d.timeIntervalSince(base) / 60))
        return String(format: "%02d:%02d", mins / 60, mins % 60)
    }
    static func logicalDay(for d: Date) -> Date {
        let cal = Calendar.current
        return cal.component(.hour, from: d) < dayCutoffHour
            ? cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: d)) ?? d
            : d
    }

    var cardioMode: CardioMode? {
        get { cardioModeRaw.flatMap(CardioMode.init(rawValue:)) }
        set { cardioModeRaw = newValue?.rawValue }
    }
    var avgHR: Int {
        if telemetry.avgHR > 0 { return telemetry.avgHR }
        guard !hr.isEmpty else { return 0 }
        return Int(hr.map(\.bpm).reduce(0, +) / Double(hr.count))
    }
    var peakHR: Int {
        max(telemetry.maxHR, Int(hr.map(\.bpm).max() ?? 0))
    }
    var distanceKm: Double {
        let m = telemetry.distance > 0 ? telemetry.distance : distanceMeters
        return m / 1000
    }
    /// 초/km
    var avgPace: Int? {
        guard distanceKm > 0.05, let d = durationSeconds else { return nil }
        return Int(Double(d) / distanceKm)
    }

    var bodyPart: BodyPart? {
        get { bodyPartRaw.flatMap(BodyPart.init(rawValue:)) }
        set { bodyPartRaw = newValue?.rawValue }
    }

    var totalVolume: Double { lifts.reduce(0) { $0 + $1.volume } }
    /// 실제 운동 소요 시간(초). 시작·종료가 있을 때만.
    var durationSeconds: Int? {
        guard let s = startAt, let e = endAt else { return nil }
        return max(0, Int(e.timeIntervalSince(s)))
    }
    var isEmpty: Bool { lifts.isEmpty && interval == nil && intervalDetailData == nil && activityName == nil }
}

// MARK: - 도우미

extension Double {
    /// 40.0 -> "40", 42.5 -> "42.5", 3.75 -> "3.75"
    var trimmed: String {
        // 소수 둘째 자리까지 (직접 입력한 3.75kg 같은 무게가 3.8 로 보이지 않게)
        self == rounded() ? String(Int(self)) : String(format: "%g", (self * 100).rounded() / 100)
    }
}

extension Int {
    /// 3725 -> "1:02:05",  125 -> "2:05"
    var hmsString: String {
        let h = self / 3600, m = (self % 3600) / 60, sec = self % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec)
                     : String(format: "%d:%02d", m, sec)
    }
}

extension Date {
    var monthDay: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M.d"
        return f.string(from: self)
    }
    var weekdayShort: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "EEEEE"   // 화, 목, 일
        return f.string(from: self)
    }
    var hmShort: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "HH:mm"
        return f.string(from: self)
    }
    var hourMinute: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f.string(from: self)
    }
    var fullKorean: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f.string(from: self)
    }
}

/// 자주 쓰는 종목 프리셋
enum LiftPreset {
    static let all: [(name: String, weight: Double, sets: Int, reps: Int, bw: Bool)] = [
        ("벤치프레스", 40, 3, 8, false),
        ("랫풀머신", 20, 3, 8, false),
        ("숄더 바벨 프레스", 20, 3, 5, false),
        ("데드리프트", 50, 3, 5, false),
        ("레그레이즈", 0, 3, 15, true),
        ("풀업", 0, 3, 8, true),
        ("딥스", 0, 3, 10, true),
        ("플랭크", 0, 3, 60, true),
    ]
}
