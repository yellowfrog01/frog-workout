import SwiftUI
import SwiftData
import Charts

/// 기록 화면: 왼쪽 세션 목록 | 오른쪽 상세
struct MacRecordsView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(MacNav.self) private var nav
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @State private var pendingDelete: Session?

    var body: some View {
        @Bindable var nav = nav
        HSplitView {
            list(selection: $nav.selectedSession)
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
            detail
                .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        }
        .confirmationDialog("이 기록을 삭제할까요?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                if let s = pendingDelete { delete(s) }
                pendingDelete = nil
            }
            Button("취소", role: .cancel) { pendingDelete = nil }
        } message: {
            if let s = pendingDelete { Text("\(s.logicalDay.monthDay) \(s.macTitle)") }
        }
    }

    private var selected: Session? {
        guard let id = nav.selectedSession else { return nil }
        return sessions.first { $0.persistentModelID == id }
    }

    private func delete(_ s: Session) {
        if nav.selectedSession == s.persistentModelID { nav.selectedSession = nil }
        ctx.delete(s)
    }

    // MARK: 목록

    @ViewBuilder
    private func list(selection: Binding<PersistentIdentifier?>) -> some View {
        if sessions.isEmpty {
            Text("기록이 없습니다.\n⌘N 으로 새 기록을 추가하세요.")
                .font(.rounded(14, .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.dim)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: selection) {
                ForEach(sessions) { s in
                    SessionRow(session: s)
                        .tag(s.persistentModelID)
                        .contextMenu {
                            Button("삭제", systemImage: "trash", role: .destructive) { pendingDelete = s }
                        }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .onDeleteCommand {
                if let s = selected { pendingDelete = s }
            }
        }
    }

    // MARK: 상세

    @ViewBuilder
    private var detail: some View {
        if let s = selected {
            SessionDetail(session: s) { pendingDelete = s }
                .id(s.persistentModelID)
        } else {
            Text("기록을 선택하세요")
                .font(.rounded(15, .medium))
                .foregroundStyle(Palette.dim)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 목록 행

private struct SessionRow: View {
    let session: Session

    var body: some View {
        let day = session.logicalDay
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(day.monthDay)
                    .font(.rounded(13, .bold)).monospacedDigit()
                Text(day.weekdayShort)
                    .font(.rounded(11, .medium))
                    .foregroundStyle(Palette.dim)
            }
            .frame(width: 40)

            Image(systemName: session.macSymbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(session.macTint)
                .frame(width: 32, height: 32)
                .background(session.macTint.opacity(0.18), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.macTitle)
                    .font(.rounded(14, .semibold))
                    .lineLimit(1)
                let sum = session.macSummary
                if !sum.isEmpty {
                    Text(sum)
                        .font(.rounded(12, .medium)).monospacedDigit()
                        .foregroundStyle(Palette.dim)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}

// MARK: - 상세

private struct SessionDetail: View {
    let session: Session
    let onDelete: () -> Void
    @State private var editing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                switch session.kind {
                case .strength: strengthBody
                case .interval: intervalBody
                case .activity: EmptyView()
                }
                if !session.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CardBox {
                        SectionLabel(text: "메모")
                        Text(session.note)
                            .font(.rounded(14, .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $editing) { SessionEditSheet(session: session) }
    }

    // MARK: 헤더

    private var timeText: String {
        var parts: [String] = []
        if let s = session.startAt {
            var t = session.clock(s)
            if let e = session.endAt { t += "–" + session.clock(e) }
            parts.append(t)
        }
        if let d = session.durationSeconds, d > 0 { parts.append("소요 \(d.hmsString)") }
        return parts.joined(separator: " · ")
    }

    private var header: some View {
        CardBox {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: session.macSymbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(session.macTint)
                    .frame(width: 56, height: 56)
                    .background(session.macTint.opacity(0.18), in: .circle)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.macTitle)
                        .font(.rounded(24, .bold))
                    Text(session.logicalDay.fullKorean)
                        .font(.rounded(14, .medium))
                        .foregroundStyle(Palette.dim)
                    if !timeText.isEmpty {
                        Text(timeText)
                            .font(.rounded(13, .medium)).monospacedDigit()
                            .foregroundStyle(Palette.dim)
                    }
                    let c = session.condition
                    Label(c.label, systemImage: c.symbol)
                        .font(.rounded(12, .bold))
                        .foregroundStyle(Palette.condition(c))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Palette.condition(c).opacity(0.16), in: .capsule)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Button("편집") { editing = true }
                    Button("삭제", role: .destructive, action: onDelete)
                }
            }
        }
    }

    // MARK: 근력

    private var strengthBody: some View {
        let lifts = session.lifts
        let durations = LiftTiming.durations(lifts, start: session.startAt)
        let gaps = LiftTiming.transitions(lifts)
        return VStack(alignment: .leading, spacing: 12) {
            if lifts.isEmpty {
                CardBox {
                    Text("종목 기록이 없습니다")
                        .font(.rounded(14, .medium))
                        .foregroundStyle(Palette.dim)
                }
            }
            ForEach(Array(lifts.enumerated()), id: \.element.id) { i, lift in
                if i > 0, let g = gaps[lift.id] { TransitionGapLine(seconds: g) }
                LiftCard(lift: lift, duration: durations[lift.id])
            }
            if session.totalVolume > 0 {
                CardBox {
                    HStack {
                        SectionLabel(text: "총 볼륨")
                        Spacer()
                        Text("\(Int(session.totalVolume).formatted())kg")
                            .font(.rounded(20, .bold)).monospacedDigit()
                            .foregroundStyle(Palette.strength)
                    }
                }
            }
        }
    }

    // MARK: 인터벌/러닝

    private var hrSeries: [(min: Double, bpm: Double)] {
        let t = session.telemetry.hr
        if !t.isEmpty { return t.map { ($0.t / 60, $0.v) } }
        return session.hr.map { ($0.t / 60, $0.bpm) }
    }

    private var intervalBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardBox {
                HStack(alignment: .top, spacing: 28) {
                    if session.distanceKm > 0.01 {
                        stat("거리", String(format: "%.2fkm", session.distanceKm))
                    }
                    if let p = session.avgPace, session.distanceKm > 0.01 {
                        stat("평균 페이스", "\(p.clockString)/km")
                    }
                    if session.avgHR > 0 { stat("평균 HR", "\(session.avgHR)") }
                    if session.peakHR > 0 { stat("최대 HR", "\(session.peakHR)") }
                    if let d = session.durationSeconds, d > 0 { stat("소요", d.hmsString) }
                    Spacer(minLength: 0)
                }
                if let iv = session.interval {
                    Text(iv.summary)
                        .font(.rounded(13, .medium)).monospacedDigit()
                        .foregroundStyle(Palette.dim)
                }
            }
            let series = hrSeries
            if !series.isEmpty {
                CardBox {
                    SectionLabel(text: "심박수")
                    Chart {
                        ForEach(Array(series.enumerated()), id: \.offset) { _, p in
                            LineMark(x: .value("분", p.min), y: .value("bpm", p.bpm))
                                .foregroundStyle(Palette.interval)
                                .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartXAxisLabel("경과 (분)")
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 180)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.rounded(11, .bold))
                .foregroundStyle(Palette.dimmer)
            Text(value)
                .font(.rounded(20, .bold)).monospacedDigit()
                .foregroundStyle(session.macTint)
        }
    }
}

// MARK: - 종목 카드

private struct LiftCard: View {
    let lift: LiftEntry
    let duration: Int?

    var body: some View {
        let d = StatusEngine.display(lift.name)
        let badges = lift.badges
        let memos = lift.memos
        CardBox {
            HStack(spacing: 8) {
                Text(d.name.isEmpty ? lift.name : d.name)
                    .font(.rounded(17, .bold))
                ForEach(badges, id: \.self) { b in
                    Text(b)
                        .font(.rounded(10, .bold))
                        .foregroundStyle(Palette.strength)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Palette.strength.opacity(0.16), in: .capsule)
                }
                Spacer(minLength: 0)
                if let duration { LiftDurationLabel(seconds: duration) }
            }
            setsGrid
            Text(lift.repsDetail)
                .font(.rounded(12, .medium)).monospacedDigit()
                .foregroundStyle(Palette.dim)
            if !memos.isEmpty {
                LiftMemoLines(memos: memos, liftName: lift.name)
                    .padding(.horizontal, -6)
            }
        }
    }

    /// 세트가 많으면 두 열로 나눈다
    private var setsGrid: some View {
        let n = max(lift.sets, 0)
        let reps = lift.repsList
        let half = n > 6 ? (n + 1) / 2 : n
        return HStack(alignment: .top, spacing: 32) {
            grid(range: 0..<half, reps: reps)
            if half < n { grid(range: half..<n, reps: reps) }
            Spacer(minLength: 0)
        }
    }

    private func grid(range: Range<Int>, reps: [Int]) -> some View {
        Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 6) {
            GridRow {
                Text("세트").gridColumnAlignment(.leading)
                Text("무게")
                Text("횟수")
            }
            .font(.rounded(11, .bold))
            .foregroundStyle(Palette.dimmer)
            ForEach(Array(range), id: \.self) { i in
                GridRow {
                    Text("\(i + 1)").gridColumnAlignment(.leading)
                        .foregroundStyle(i < lift.done ? Palette.strength : Palette.dim)
                    Text(lift.weightLabel(at: i))
                    Text(i < reps.count ? "\(reps[i])" : "-")
                }
                .font(.rounded(14, .semibold)).monospacedDigit()
            }
        }
    }
}
