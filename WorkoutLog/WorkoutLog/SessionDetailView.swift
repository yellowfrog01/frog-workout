import SwiftUI
import SwiftData
import Charts

/// 세션 상세 — 수집한 모든 지표를 보여준다.
struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var session: Session
    @State private var editing = false
    @State private var confirmDelete = false

    /// 최대심박 추정 (존 계산용)
    private var estMax: Int { max(session.peakHR, 185) }
    private var tele: Telemetry { session.telemetry }
    private var tint: Color {
        switch session.kind {
        case .strength: Palette.strength
        case .interval: Palette.interval
        case .activity: Palette.activity
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    switch session.kind {
                    case .strength: strengthBlock
                    case .interval: cardioBlocks
                    case .activity: activityBlock
                    }
                    actions
                }
                .padding(18)
                .padding(.bottom, 40)
            }
            .background(Palette.bg)
            .navigationTitle("")
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }.foregroundStyle(Palette.dim)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("편집") { editing = true }
                        .font(.rounded(16, .bold)).foregroundStyle(tint)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $editing) { EditSessionSheet(session: session) }
        .alert("기록을 삭제할까요?", isPresented: $confirmDelete) {
            Button("삭제", role: .destructive) { ctx.delete(session); dismiss() }
            Button("취소", role: .cancel) { }
        } message: { Text("되돌릴 수 없습니다.") }
    }

    // MARK: - 헤더

    private var header: some View {
        CardBox {
            HStack(spacing: 7) {
                Image(systemName: session.kind == .activity
                      ? ActivityPreset.symbol(for: session.activityName ?? "") : session.kind.symbol)
                    .font(.system(size: 13, weight: .bold))
                Text(session.kind == .activity
                     ? (session.activityName ?? session.kind.label)
                     : (session.cardioMode?.label ?? session.kind.label))
                    .font(.rounded(14, .bold))
                Spacer()
                Image(systemName: session.condition.symbol)
                    .foregroundStyle(Palette.condition(session.condition))
                Text(session.condition.label)
                    .font(.rounded(13, .semibold))
                    .foregroundStyle(Palette.dim)
            }
            .foregroundStyle(tint)

            Text(session.logicalDay.fullKorean)
                .font(.rounded(20, .bold)).foregroundStyle(.white)
            if let s = session.startAt, let e = session.endAt {
                Text("\(session.clock(s)) – \(session.clock(e))")
                    .font(.rounded(13, .semibold)).monospacedDigit()
                    .foregroundStyle(Palette.dim)
            }
        }
    }

    // MARK: - 유산소

    @ViewBuilder
    private var cardioBlocks: some View {
        summaryGrid
        if let d = session.intervalDetail {
            IntervalSections(session: session, detail: d, estMax: estMax)
        }

        if !session.route.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "경로")
                RouteMap(points: session.route, height: 240)
            }
        }

        if tele.hr.count > 1 || !session.hr.isEmpty {
            CardBox {
                SectionLabel(text: "심박수")
                HStack(spacing: 14) {
                    stat("평균", "\(session.avgHR)", WatchTint.heart)
                    stat("최고", "\(session.peakHR)", WatchTint.heart)
                    if tele.minHR > 0 { stat("최저", "\(tele.minHR)", WatchTint.heart) }
                }
                HRChart(samples: hrPoints, height: 160)
                if !zones.isEmpty { zoneBars }
            }
        }

        if !tele.splits.isEmpty { splitsCard }
        if hasDynamics { dynamicsCard }
        if tele.elevationGain > 0 || tele.elevationLoss > 0 { elevationCard }
        if let iv = session.interval { intervalCard(iv) }
    }

    private var hrPoints: [HRPoint] {
        tele.hr.isEmpty ? session.hr : tele.hr.map { HRPoint(bpm: $0.v, t: $0.t) }
    }

    private var summaryGrid: some View {
        CardBox {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                cell("시간", (session.durationSeconds ?? 0).hmsString, "", WatchTint.time)
                cell("거리", String(format: "%.2f", session.distanceKm), "km", WatchTint.distance)
                cell("평균 페이스", session.avgPace.map { $0.clockString } ?? "--:--", "/km", WatchTint.pace)
                cell("활동 칼로리", "\(Int(tele.activeKcal))", "kcal", WatchTint.energy)
                if session.avgHR > 0 { cell("평균 심박", "\(session.avgHR)", "bpm", WatchTint.heart) }
                if tele.steps > 0 { cell("걸음", "\(tele.steps)", "", Palette.dim) }
            }
        }
    }

    private func cell(_ l: String, _ v: String, _ u: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: -1) {
            Text(l).font(.rounded(11, .bold)).foregroundStyle(c.opacity(0.8))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(v).font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundStyle(c)
                if !u.isEmpty {
                    Text(u).font(.rounded(11, .bold)).foregroundStyle(c.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ l: String, _ v: String, _ c: Color) -> some View {
        HStack(spacing: 4) {
            Text(l).font(.rounded(11, .semibold)).foregroundStyle(Palette.dimmer)
            Text(v).font(.rounded(17, .bold)).monospacedDigit().foregroundStyle(c)
        }
    }

    // MARK: - 심박 존

    private var zones: [(zone: Int, label: String, seconds: Int)] {
        tele.hrZones(maxHR: estMax).filter { $0.seconds > 0 }
    }

    private var zoneBars: some View {
        let total = max(1, zones.reduce(0) { $0 + $1.seconds })
        let colors: [Color] = [.gray, WatchTint.distance, WatchTint.pace,
                               Color(red: 1, green: 0.7, blue: 0.1), WatchTint.heart]
        return VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "심박 존 (최대 \(estMax) 추정)")
            ForEach(zones, id: \.zone) { z in
                HStack(spacing: 8) {
                    Text(z.label)
                        .font(.rounded(11, .semibold))
                        .foregroundStyle(Palette.dim)
                        .frame(width: 74, alignment: .leading)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colors[z.zone - 1])
                            .frame(width: max(3, geo.size.width * CGFloat(z.seconds) / CGFloat(total)))
                    }
                    .frame(height: 10)
                    Text(z.seconds.clockString)
                        .font(.rounded(11, .semibold)).monospacedDigit()
                        .foregroundStyle(Palette.dimmer)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - 스플릿

    private var splitsCard: some View {
        CardBox {
            SectionLabel(text: "스플릿")
            let fastest = tele.splits.map(\.pace).filter { $0 > 0 }.min() ?? 0
            ForEach(tele.splits) { sp in
                HStack {
                    Text("\(sp.index)")
                        .font(.rounded(14, .bold)).monospacedDigit()
                        .foregroundStyle(Palette.dim).frame(width: 22, alignment: .leading)
                    Text(sp.seconds.clockString)
                        .font(.rounded(15, .semibold)).monospacedDigit()
                        .foregroundStyle(.white).frame(width: 62, alignment: .leading)
                    Text("\(sp.pace.clockString)/km")
                        .font(.rounded(15, .bold)).monospacedDigit()
                        .foregroundStyle(sp.pace == fastest ? WatchTint.pace : Palette.dim)
                    Spacer()
                    if sp.avgHR > 0 {
                        Label("\(sp.avgHR)", systemImage: "heart.fill")
                            .font(.rounded(12, .semibold)).monospacedDigit()
                            .foregroundStyle(WatchTint.heart)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 러닝 다이내믹스

    private var hasDynamics: Bool {
        tele.avgCadence > 0 || tele.avgPower > 0 || tele.avgStride > 0
            || tele.avgVertOsc > 0 || tele.avgGCT > 0
    }

    private var dynamicsCard: some View {
        CardBox {
            SectionLabel(text: "러닝 다이내믹스")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                if tele.avgCadence > 0 { cell("케이던스", "\(tele.avgCadence)", "spm", Palette.strength) }
                if tele.avgPower > 0   { cell("파워", "\(tele.avgPower)", "W", WatchTint.energy) }
                if tele.avgStride > 0  { cell("보폭", String(format: "%.2f", tele.avgStride), "m", WatchTint.distance) }
                if tele.avgVertOsc > 0 { cell("상하 진동", String(format: "%.1f", tele.avgVertOsc), "cm", WatchTint.pace) }
                if tele.avgGCT > 0     { cell("접지 시간", "\(Int(tele.avgGCT))", "ms", Palette.dim) }
            }
        }
    }

    private var elevationCard: some View {
        CardBox {
            SectionLabel(text: "고도")
            HStack {
                cell("상승", String(format: "%.0f", tele.elevationGain), "m", WatchTint.pace)
                cell("하강", String(format: "%.0f", tele.elevationLoss), "m", WatchTint.distance)
            }
        }
    }

    private func intervalCard(_ iv: IntervalEntry) -> some View {
        CardBox {
            SectionLabel(text: "인터벌")
            Text(iv.summary).font(.rounded(15, .semibold)).foregroundStyle(.white)
            SetDots(total: iv.sets, done: .constant(iv.done), tint: Palette.interval, interactive: false)
        }
    }

    // MARK: - 기타 운동

    private var activityBlock: some View {
        CardBox {
            SectionLabel(text: "기타 운동")
            HStack {
                Text(session.activityName ?? session.kind.label)
                    .font(.rounded(17, .bold)).foregroundStyle(.white)
                Spacer()
                if let s = session.startAt, let e = session.endAt {
                    Text("\(session.clock(s))–\(session.clock(e))")
                        .font(.rounded(15, .bold)).monospacedDigit()
                        .foregroundStyle(Palette.activity)
                }
            }
            if let d = session.durationSeconds {
                HStack {
                    Text("소요").font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                    Spacer()
                    Text(d.hmKorean)
                        .font(.rounded(17, .bold)).monospacedDigit()
                        .foregroundStyle(Palette.activity)
                }
            }
            if !session.note.isEmpty {
                Divider().overlay(Palette.cardStroke)
                Text(session.note)
                    .font(.rounded(14, .medium)).foregroundStyle(Palette.dim)
            }
        }
    }

    // MARK: - 근력

    private var strengthBlock: some View {
        CardBox {
            SectionLabel(text: "종목")
            if session.lifts.isEmpty {
                Text("세부 기록 없음").font(.rounded(13, .medium)).foregroundStyle(Palette.dimmer)
            }
            let times = LiftTiming.durations(session.lifts, start: session.startAt)
            let gaps = LiftTiming.transitions(session.lifts)
            ForEach(session.lifts) { l in
                if let g = gaps[l.id] { TransitionGapLine(seconds: g) }
                HStack {
                    LiftNameLine(lift: l, size: 15, weight: .semibold)
                    if let sec = times[l.id] { LiftDurationLabel(seconds: sec) }
                    Spacer()
                    Text("\(l.weightLabel) \(l.repsDetail)")
                        .font(.rounded(15, .bold)).monospacedDigit()
                        .foregroundStyle(Palette.strength)
                }
                if !l.memos.isEmpty { LiftMemoLines(memos: l.memos, liftName: l.name) }
            }
            if session.totalVolume > 0 {
                Divider().overlay(Palette.cardStroke)
                HStack {
                    Text("총 볼륨").font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                    Spacer()
                    Text("\(Int(session.totalVolume).formatted()) kg")
                        .font(.rounded(18, .bold)).monospacedDigit()
                        .foregroundStyle(Palette.strength)
                }
            }
        }
    }

    private var actions: some View {
        Button(role: .destructive) { confirmDelete = true } label: {
            Label("이 기록 삭제", systemImage: "trash")
                .font(.rounded(16, .bold))
                .foregroundStyle(Color(red: 0.98, green: 0.35, blue: 0.31))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color(red: 0.98, green: 0.35, blue: 0.31).opacity(0.13),
                            in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
