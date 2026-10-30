import SwiftUI
import SwiftData

/// 기타 운동 프리셋 (이름, SF Symbol)
enum ActivityPreset {
    static let all: [(name: String, symbol: String)] = [
        ("배드민턴", "figure.badminton"),
        ("등산", "figure.hiking"),
        ("축구", "figure.soccer"),
        ("풋살", "figure.indoor.soccer"),
        ("농구", "figure.basketball"),
        ("테니스", "figure.tennis"),
        ("탁구", "figure.table.tennis"),
        ("수영", "figure.pool.swim"),
        ("자전거", "figure.outdoor.cycle"),
        ("걷기", "figure.walk"),
        ("요가", "figure.yoga"),
        ("클라이밍", "figure.climbing"),
        ("골프", "figure.golf"),
        ("볼링", "figure.bowling"),
    ]

    static let fallbackSymbol = "figure.mixed.cardio"

    /// 프리셋 이름이면 그 심볼, 직접 입력한 이름이면 기본 심볼
    static func symbol(for name: String) -> String {
        all.first { $0.name == name }?.symbol ?? fallbackSymbol
    }
}

extension Int {
    /// 7200 -> "2시간 0분", 2700 -> "45분" (초 단위 입력)
    var hmKorean: String {
        let h = self / 3600, m = (self % 3600) / 60
        return h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
    }
}

/// 달력에서 하루에 기타 운동(배드민턴·등산 등)을 직접 기록하는 시트
struct AddActivitySheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    let day: Date

    @State private var preset: String?
    @State private var custom = false
    @State private var customName = ""
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var memo = ""
    @FocusState private var nameFocused: Bool

    private let cal = Calendar.current

    init(day: Date) {
        self.day = day
        let start = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day
        _startTime = State(initialValue: start)
        _endTime = State(initialValue: start.addingTimeInterval(3600))
    }

    private var name: String {
        custom ? customName.trimmingCharacters(in: .whitespacesAndNewlines) : (preset ?? "")
    }
    private var valid: Bool { !name.isEmpty }

    private func minutesOfDay(_ d: Date) -> Int {
        cal.component(.hour, from: d) * 60 + cal.component(.minute, from: d)
    }

    /// 시작 시각. 새벽 4시 전이면 앱의 기록 날짜 규칙상 전날로 잡히므로 다음 날로 넘겨 선택한 날에 남긴다.
    private var startAt: Date {
        let s = cal.date(bySettingHour: minutesOfDay(startTime) / 60, minute: minutesOfDay(startTime) % 60,
                         second: 0, of: day) ?? day
        return cal.component(.hour, from: s) < Session.dayCutoffHour
            ? cal.date(byAdding: .day, value: 1, to: s) ?? s
            : s
    }

    /// 소요 분. 종료가 시작 이하이면 다음 날 종료로 본다.
    private var durationMinutes: Int {
        let s = minutesOfDay(startTime), e = minutesOfDay(endTime)
        return e > s ? e - s : e - s + 24 * 60
    }

    private var endAt: Date {
        cal.date(byAdding: .minute, value: durationMinutes, to: startAt) ?? startAt
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    kindPicker

                    CardBox {
                        DatePicker("시작", selection: $startTime, displayedComponents: .hourAndMinute)
                            .font(.rounded(15, .medium)).tint(Palette.activity)
                        DatePicker("종료", selection: $endTime, displayedComponents: .hourAndMinute)
                            .font(.rounded(15, .medium)).tint(Palette.activity)
                        HStack {
                            Text("소요").font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                            Spacer()
                            Text((durationMinutes * 60).hmKorean)
                                .font(.rounded(17, .bold)).monospacedDigit()
                                .foregroundStyle(Palette.activity)
                        }
                    }

                    CardBox {
                        SectionLabel(text: "메모")
                        TextField("메모 (선택)", text: $memo, axis: .vertical)
                            .font(.rounded(16, .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1...4)
                    }
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle(day.fullKorean)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }.foregroundStyle(Palette.dim)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .font(.rounded(16, .bold))
                        .foregroundStyle(valid ? Palette.activity : Palette.dimmer)
                        .disabled(!valid)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
    }

    // MARK: 운동 종류

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "운동 종류")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                ForEach(ActivityPreset.all, id: \.name) { p in
                    chip(p.symbol, p.name, on: !custom && preset == p.name) {
                        custom = false
                        preset = p.name
                        nameFocused = false
                    }
                }
                chip("square.and.pencil", "직접 입력", on: custom) {
                    custom = true
                    preset = nil
                    nameFocused = true
                }
            }
            if custom {
                TextField("운동 이름", text: $customName)
                    .font(.rounded(17, .semibold))
                    .foregroundStyle(.white)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.white.opacity(0.07), in: .rect(cornerRadius: 14))
                    .transition(.opacity)
            }
        }
    }

    private func chip(_ symbol: String, _ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { action() }
            Haptics.tap()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.rounded(12, .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? Color.black : Palette.dim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(on ? Palette.activity : Color.white.opacity(0.07), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard valid else { return }
        let start = startAt
        let s = Session(date: start, kind: .activity,
                        note: memo.trimmingCharacters(in: .whitespacesAndNewlines),
                        startAt: start, endAt: endAt)
        s.activityName = name
        ctx.insert(s)
        Haptics.success()
        dismiss()
    }
}
