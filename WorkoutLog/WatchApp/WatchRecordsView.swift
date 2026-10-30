import SwiftUI

/// 아이폰이 보내준 기록 요약. 워치는 저장소를 직접 못 보므로 요약만 받는다.
struct WatchRecord: Codable, Identifiable, Hashable {
    var d: Double
    var kind: String
    var cond: String
    var title: String
    var sub: String

    var id: String { "\(d)-\(title)" }
    var date: Date { Date(timeIntervalSince1970: d) }
    var isStrength: Bool { kind == "strength" }
    var symbol: String {
        isStrength ? "figure.strengthtraining.traditional" : "figure.run"
    }
    var tint: Color {
        isStrength ? Color(red: 0.85, green: 0.98, blue: 0.20)
                   : Color(red: 0.20, green: 0.82, blue: 0.94)
    }
    var condSymbol: String {
        switch cond {
        case "good": "flame.fill"
        case "bad": "battery.25percent"
        default: "equal.circle.fill"
        }
    }

    init?(_ m: [String: Any]) {
        guard let d = m["d"] as? Double else { return nil }
        self.d = d
        self.kind = m["kind"] as? String ?? "interval"
        self.cond = m["cond"] as? String ?? "normal"
        self.title = m["title"] as? String ?? "운동"
        self.sub = m["sub"] as? String ?? ""
    }

    var dayLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M.d (E)"
        return f.string(from: date)
    }
}

struct WatchRecordsView: View {
    @EnvironmentObject var m: WatchWorkoutManager

    var body: some View {
        List {
            if m.records.isEmpty {
                Text(m.phoneReachable ? "불러오는 중…" : "아이폰에서 앱을 열어주세요")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            ForEach(m.records) { r in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: r.symbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(r.tint)
                        Text(r.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer(minLength: 2)
                        Image(systemName: r.condSymbol)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    Text(r.dayLabel)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    if !r.sub.isEmpty {
                        Text(r.sub)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(r.tint.opacity(0.85))
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .navigationTitle("기록")
        .onAppear { m.requestRecords() }
    }
}

/// 시작 전 종류 선택. 아이폰 플로우의 미니 버전.
struct WatchStartView: View {
    @EnvironmentObject var m: WatchWorkoutManager

    var body: some View {
        List {
            row("일반 러닝", "figure.run", Color(red: 0.20, green: 0.82, blue: 0.94),
                "야외 · 일정 페이스") { m.start(outdoor: true, cardio: "steady") }
            row("인터벌", "stopwatch.fill", Color(red: 1.0, green: 0.55, blue: 0.15),
                "야외 · 고강도 반복") { m.start(outdoor: true, cardio: "interval") }
            row("실내 러닝", "figure.indoor.cycle", Color(red: 0.65, green: 0.60, blue: 0.98),
                "트레드밀") { m.start(outdoor: false, cardio: "steady") }

            if !m.message.isEmpty {
                Text(m.message)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
            }
        }
        .navigationTitle("운동 시작")
    }

    private func row(_ title: String, _ symbol: String, _ c: Color,
                     _ desc: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(c)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(desc)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(!m.authorized)
    }
}
