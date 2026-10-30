import SwiftUI
import SwiftData

/// 운동한 날 달력. 날짜마다 근력/유산소를 아이콘으로 보여주고, 누르면 그날 기록을 아래에 띄운다.
struct CalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Session.date) private var sessions: [Session]
    @Query(sort: \PlannedWorkout.date) private var plans: [PlannedWorkout]

    @State private var month = Calendar.current.startOfMonth(for: .now)
    @State private var selected: Date?
    @State private var detail: Session?
    @State private var addDay: Date?

    private let cal = Calendar.current

    /// 기록 날짜(새벽 운동은 전날) → 그날 세션들
    private var byDay: [Date: [Session]] {
        Dictionary(grouping: sessions) { cal.startOfDay(for: $0.logicalDay) }
    }

    /// 예정일 → 아직 시작하지 않은 계획들
    private var planByDay: [Date: [PlannedWorkout]] {
        Dictionary(grouping: plans.filter { !$0.isDone }) { cal.startOfDay(for: $0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CardBox {
                        monthHeader
                        weekdayRow
                        grid
                        legend
                    }
                    if let day = selected {
                        dayList(day)
                    }
                }
                .padding(18).padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle("운동 달력")
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }.foregroundStyle(Palette.strength)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $detail) { SessionDetailView(session: $0) }
        .sheet(isPresented: Binding(get: { addDay != nil }, set: { if !$0 { addDay = nil } })) {
            if let d = addDay { AddActivitySheet(day: d) }
        }
    }

    // MARK: 월 헤더 + 요약

    private var monthHeader: some View {
        let days = byDay.filter { cal.isDate($0.key, equalTo: month, toGranularity: .month) }
        let all = days.values.flatMap { $0 }
        let strength = all.filter { $0.kind == .strength }.count
        let cardio = all.filter { $0.kind == .interval }.count
        let activity = all.filter { $0.kind == .activity }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(month.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "ko_KR"))))
                    .font(.rounded(22, .heavy)).foregroundStyle(.white)
                Spacer()
                stepButton("chevron.left") { shift(-1) }
                stepButton("chevron.right") { shift(1) }
            }
            HStack(spacing: 8) {
                summaryChip("\(days.count)일", "운동한 날", .white)
                summaryChip("\(strength)", "근력", Palette.strength)
                summaryChip("\(cardio)", "유산소", Palette.interval)
                if activity > 0 { summaryChip("\(activity)", "기타", Palette.activity) }
            }
        }
    }

    private func summaryChip(_ value: String, _ label: String, _ tint: Color) -> some View {
        HStack(spacing: 5) {
            Text(value).font(.rounded(15, .heavy)).monospacedDigit().foregroundStyle(tint)
            Text(label).font(.rounded(11, .semibold)).foregroundStyle(Palette.dim)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(tint.opacity(0.1), in: .capsule)
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08), in: .circle)
        }
        .buttonStyle(.plain)
    }

    private func shift(_ n: Int) {
        guard let m = cal.date(byAdding: .month, value: n, to: month) else { return }
        withAnimation(.snappy) {
            month = m
            selected = nil
        }
    }

    // MARK: 요일 + 날짜 격자

    private var weekdayRow: some View {
        let symbols = cal.veryShortWeekdaySymbolsKR
        return HStack(spacing: 0) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { i, s in
                Text(s)
                    .font(.rounded(11, .bold))
                    .foregroundStyle(i == 0 ? Palette.interval.opacity(0.7) : Palette.dimmer)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let cells = cal.monthCells(for: month)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                         spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 56)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let list = byDay[day] ?? []
        let planned = planByDay[day] ?? []
        let hasStrength = list.contains { $0.kind == .strength }
        let cardio = list.filter { $0.kind == .interval }
        let activities = list.filter { $0.kind == .activity }
        let isToday = cal.isDateInToday(day)
        let isSelected = selected.map { cal.isDate($0, inSameDayAs: day) } ?? false
        let empty = list.isEmpty && planned.isEmpty
        let planTint: Color = planned.contains { $0.kind == .strength } ? Palette.strength : Palette.interval
        let kindCount = [hasStrength, !cardio.isEmpty, !activities.isEmpty].filter { $0 }.count
        let tint: Color = kindCount > 1 ? .white
            : hasStrength ? Palette.strength
            : !cardio.isEmpty ? Palette.interval
            : !activities.isEmpty ? Palette.activity
            : !planned.isEmpty ? planTint : .clear

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                selected = isSelected ? nil : day
            }
            Haptics.tap()
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .font(.rounded(14, list.isEmpty ? .medium : .heavy)).monospacedDigit()
                    .foregroundStyle(empty ? Palette.dim : .white)
                HStack(spacing: kindCount > 2 ? -4 : 2) {
                    if hasStrength {
                        icon("dumbbell.fill", Palette.strength)
                    }
                    if let c = cardio.first {
                        icon(c.cardioMode == .interval || c.interval != nil ? "stopwatch.fill" : "figure.run",
                             Palette.interval)
                    }
                    if let a = activities.first {
                        icon(ActivityPreset.symbol(for: a.activityName ?? ""), Palette.activity)
                    }
                    if list.isEmpty, let p = planned.first {
                        planIcon(p.kind == .strength ? "dumbbell.fill" : "figure.run", planTint)
                    }
                }
                .frame(height: 16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(list.isEmpty ? Color.clear : tint.opacity(isSelected ? 0.28 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? (empty ? Color.white.opacity(0.6) : tint.opacity(0.9))
                                  : isToday ? Color.white.opacity(0.5)
                                  : (list.isEmpty && !planned.isEmpty) ? planTint.opacity(0.45) : .clear,
                                  style: StrokeStyle(lineWidth: isSelected ? 1.5 : 1,
                                                     dash: (!isSelected && !isToday && list.isEmpty && !planned.isEmpty) ? [3, 2] : []))
            )
        }
        .buttonStyle(.plain)
    }

    /// 예정 표시 — 속이 빈 아이콘
    private func planIcon(_ name: String, _ tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 16, height: 16)
            .overlay(Circle().strokeBorder(tint.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 1.5])))
    }

    private func icon(_ name: String, _ tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: 16, height: 16)
            .background(tint, in: .circle)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem("dumbbell.fill", "근력", Palette.strength)
            legendItem("figure.run", "유산소", Palette.interval)
            legendItem("stopwatch.fill", "인터벌", Palette.interval)
            legendItem("figure.mixed.cardio", "기타", Palette.activity)
            HStack(spacing: 5) {
                planIcon("dumbbell.fill", Palette.dim)
                Text("예정").font(.rounded(11, .semibold)).foregroundStyle(Palette.dim)
            }
            Spacer()
        }
    }

    private func legendItem(_ symbol: String, _ label: String, _ tint: Color) -> some View {
        HStack(spacing: 5) {
            icon(symbol, tint)
            Text(label).font(.rounded(11, .semibold)).foregroundStyle(Palette.dim)
        }
    }

    // MARK: 선택한 날

    private func dayList(_ day: Date) -> some View {
        let list = (byDay[day] ?? []).sorted { $0.date < $1.date }
        let planned = (planByDay[day] ?? []).sorted { $0.createdAt < $1.createdAt }
        return VStack(alignment: .leading, spacing: 10) {
            Text(day.fullKorean)
                .font(.rounded(15, .bold)).foregroundStyle(Palette.dim)
                .padding(.horizontal, 4)
            ForEach(list) { s in
                Button { detail = s } label: { SessionRow(session: s) }
                    .buttonStyle(.plain)
            }
            ForEach(planned) { p in
                PlanRow(plan: p)
            }
            Button {
                addDay = day
                Haptics.tap()
            } label: {
                Label("운동 추가", systemImage: "plus.circle.fill")
                    .font(.rounded(15, .semibold))
                    .foregroundStyle(Palette.activity)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Palette.activity.opacity(0.12), in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

// MARK: - 달력 계산

extension Calendar {
    func startOfMonth(for d: Date) -> Date {
        date(from: dateComponents([.year, .month], from: d)) ?? d
    }

    /// 월 격자: 첫 주 앞의 빈칸은 nil
    func monthCells(for month: Date) -> [Date?] {
        let first = startOfMonth(for: month)
        guard let range = range(of: .day, in: .month, for: first) else { return [] }
        let lead = (component(.weekday, from: first) - firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: lead)
        for d in range {
            cells.append(date(byAdding: .day, value: d - 1, to: first))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    /// 한국어 요일 한 글자, firstWeekday 부터
    var veryShortWeekdaySymbolsKR: [String] {
        let s = ["일", "월", "화", "수", "목", "금", "토"]
        let start = firstWeekday - 1
        return Array(s[start...] + s[..<start])
    }
}
