import SwiftUI
import SwiftData

/// 달력: 왼쪽 월 그리드, 오른쪽 선택일 패널
struct MacCalendarView: View {
    @Environment(MacNav.self) private var nav
    @Query(sort: \Session.date) private var sessions: [Session]

    @State private var month: Date = Calendar.current.startOfMonth(for: Date())
    @State private var selected: Date = Calendar.current.startOfDay(for: Date())

    private var cal: Calendar { Calendar.current }
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    /// logicalDay 기준 일자별 그룹
    private var byDay: [Date: [Session]] {
        Dictionary(grouping: sessions) { cal.startOfDay(for: $0.logicalDay) }
    }

    /// 6주 x 7일 = 42칸
    private var cells: [Date] {
        let first = cal.startOfMonth(for: month)
        let offset = cal.component(.weekday, from: first) - 1
        let start = cal.date(byAdding: .day, value: -offset, to: first) ?? first
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        return f.string(from: month)
    }

    var body: some View {
        HStack(spacing: 0) {
            grid
            Divider().overlay(Palette.cardStroke)
            sidePanel.frame(width: 340)
        }
    }

    // MARK: 월 그리드

    private var grid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                Text(monthTitle).font(.rounded(22, .bold)).frame(minWidth: 150)
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                Spacer()
                Button("오늘") {
                    month = cal.startOfMonth(for: Date())
                    selected = cal.startOfDay(for: Date())
                }
            }
            .buttonStyle(.bordered)

            HStack(spacing: 6) {
                ForEach(weekdays, id: \.self) { w in
                    Text(w).font(.rounded(13)).foregroundStyle(Palette.dim)
                        .frame(maxWidth: .infinity)
                }
            }

            let all = cells
            VStack(spacing: 6) {
                ForEach(0..<6, id: \.self) { r in
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { c in
                            dayCell(all[r * 7 + c])
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = cal.isDate(day, equalTo: month, toGranularity: .month)
        let isToday = cal.isDateInToday(day)
        let isSel = cal.isDate(day, inSameDayAs: selected)
        let list = byDay[day] ?? []
        return Button { selected = day } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .font(.rounded(14, isToday ? .bold : .semibold))
                    .foregroundStyle(isToday ? Color.black : (inMonth ? Color.white : Palette.dimmer))
                    .frame(minWidth: 24, minHeight: 24)
                    .background(isToday ? Palette.strength : Color.clear, in: .circle)
                HStack(spacing: 4) {
                    ForEach(list.prefix(3), id: \.persistentModelID) { s in
                        Image(systemName: s.macSymbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(s.macTint)
                    }
                    if list.count > 3 {
                        Text("+\(list.count - 3)").font(.rounded(11)).foregroundStyle(Palette.dim)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.card, in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSel ? Palette.strength : Palette.cardStroke, lineWidth: isSel ? 2 : 1)
            )
            .opacity(inMonth ? 1 : 0.55)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func shift(_ n: Int) {
        month = cal.date(byAdding: .month, value: n, to: month) ?? month
    }

    // MARK: 선택일 패널

    private var sidePanel: some View {
        let list = (byDay[cal.startOfDay(for: selected)] ?? []).sorted { $0.date < $1.date }
        return VStack(alignment: .leading, spacing: 14) {
            Text(selected.fullKorean).font(.rounded(20, .bold))
            if list.isEmpty {
                Text("기록 없음").font(.rounded(14)).foregroundStyle(Palette.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(list, id: \.persistentModelID) { s in
                        Button {
                            nav.selectedSession = s.persistentModelID
                            nav.section = .records
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: s.macSymbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(s.macTint)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.macTitle).font(.rounded(15, .semibold))
                                    if !s.macSummary.isEmpty {
                                        Text(s.macSummary).font(.rounded(12, .regular))
                                            .foregroundStyle(Palette.dim)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12)).foregroundStyle(Palette.dimmer)
                            }
                            .padding(12)
                            .background(Palette.card, in: .rect(cornerRadius: 14))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer(minLength: 0)
            Button { nav.newRecordDay = selected } label: {
                Label("기록 추가", systemImage: "plus")
                    .font(.rounded(15, .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
}

private extension Calendar {
    func startOfMonth(for d: Date) -> Date {
        date(from: dateComponents([.year, .month], from: d)) ?? d
    }
}
