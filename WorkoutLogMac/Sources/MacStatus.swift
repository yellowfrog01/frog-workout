import SwiftUI
import SwiftData
import Charts

/// 상태 화면(맥). StatusEngine 스냅샷을 카드 그리드로 보여준다.
struct MacStatusView: View {
    @Query private var sessions: [Session]
    @Query private var bodies: [BodyRecord]
    @Query private var vitals: [Vital]
    @State private var selectedLift: String?

    private let columns = [GridItem(.adaptive(minimum: 440), spacing: 16, alignment: .top)]

    var body: some View {
        let snap = StatusEngine.snapshot(sessions: sessions, bodies: bodies, vitals: vitals)
        ScrollView {
            VStack(spacing: 16) {
                LazyVGrid(columns: columns, spacing: 16) {
                    buildCard(snap.build)
                    coreCard(snap.build.core)
                }
                liftsCard(snap)
                LazyVGrid(columns: columns, spacing: 16) {
                    cardioCard(snap.cardio)
                    volumeCard(snap)
                    flagsCard(snap.flags)
                    bodyCard(snap.body)
                }
            }
            .padding(24)
        }
        .background(Palette.bg)
        .navigationTitle("상태")
    }

    // MARK: 빌드 / 코어

    private func buildCard(_ b: BuildInfo) -> some View {
        CardBox {
            SectionLabel(text: "빌드")
            HStack(spacing: 14) {
                Image(systemName: b.archetype.symbol)
                    .font(.system(size: 30))
                    .foregroundStyle(Palette.strength)
                    .frame(width: 52, height: 52)
                    .background(Palette.strength.opacity(0.14), in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(b.archetype.label).font(.rounded(22, .bold))
                    Text(b.archetype.subtitle).font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                }
                Spacer()
                Text("Lv \(b.level)").font(.rounded(26, .heavy)).foregroundStyle(Palette.strength)
            }
            bar(b.levelProgress, tint: Palette.strength)
            HStack {
                Text("다음 레벨까지 \(Int((b.levelProgress * 5).rounded()))/5").foregroundStyle(Palette.dim)
                Spacer()
                Text("총 \(b.totalSessions)회").foregroundStyle(Palette.dim)
            }
            .font(.rounded(12, .medium))
            Divider().overlay(Palette.cardStroke)
            HStack(spacing: 24) {
                miniStat("근력 (8주)", "\(b.strengthCount)회")
                miniStat("유산소 (8주)", "\(b.cardioCount)회")
                miniStat("주당 빈도", String(format: "%.1f회", b.weeklyFrequency))
                miniStat("추세", b.trend.label)
            }
            Text(b.bodyDirection.label).font(.rounded(12, .medium)).foregroundStyle(Palette.dim)
        }
    }

    private func coreCard(_ core: [CoreStat]) -> some View {
        CardBox {
            SectionLabel(text: "코어 스탯")
            ForEach(core) { c in
                HStack(spacing: 12) {
                    Text(c.code).font(.rounded(13, .bold)).frame(width: 44, alignment: .leading)
                    Text(c.label).font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                        .frame(width: 56, alignment: .leading)
                    if let g = c.gauge {
                        bar(g, tint: Palette.strength)
                        Text("\(Int((g * 100).rounded()))")
                            .font(.rounded(13, .bold)).monospacedDigit()
                            .frame(width: 34, alignment: .trailing)
                    } else {
                        bar(0, tint: Palette.strength)
                        Text("–").font(.rounded(13, .bold)).foregroundStyle(Palette.dim)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: 종목별 근력

    private func liftsCard(_ snap: StatusSnapshot) -> some View {
        CardBox {
            SectionLabel(text: "종목별 근력")
            if snap.lifts.isEmpty && snap.bwLifts.isEmpty {
                emptyText("근력 기록이 없습니다. 기록을 추가하면 e1RM 이 계산됩니다.")
            } else {
                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 0) {
                        liftHeader
                        ForEach(snap.lifts) { l in liftRow(l) }
                        if !snap.bwLifts.isEmpty { bwTable(snap.bwLifts) }
                        Text("* 한계 반복 수 10 초과로 오차 큼   ↑ 하한값(RIR 없음)")
                            .font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
                    }
                    .frame(minWidth: 520)
                    if let l = snap.lifts.first(where: { $0.name == selectedLift }) {
                        liftDetail(l).frame(minWidth: 320, maxWidth: 420)
                    } else if !snap.lifts.isEmpty {
                        Text("종목을 선택하면 RM 표와 e1RM 추이가 표시됩니다.")
                            .font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                            .frame(minWidth: 320, maxWidth: 420, minHeight: 160)
                    }
                }
            }
        }
    }

    private var liftHeader: some View {
        HStack(spacing: 8) {
            Text("종목").frame(maxWidth: .infinity, alignment: .leading)
            Text("e1RM").frame(width: 80, alignment: .trailing)
            Text("최고").frame(width: 130, alignment: .trailing)
            Text("28일").frame(width: 56, alignment: .trailing)
            Text("상대 Lv").frame(width: 56, alignment: .trailing)
        }
        .font(.rounded(11, .bold)).foregroundStyle(Palette.dimmer)
        .padding(.vertical, 6).padding(.horizontal, 8)
    }

    private func liftRow(_ l: LiftStat) -> some View {
        let d = StatusEngine.display(l.name)
        let on = l.name == selectedLift
        return Button {
            selectedLift = on ? nil : l.name
        } label: {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(d.name).lineLimit(1)
                    ForEach(d.badges, id: \.self) { b in
                        Text(b).font(.rounded(10, .bold)).foregroundStyle(Palette.dim)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.white.opacity(0.08), in: .capsule)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(kg(l.e1RM) + (l.lowConfidence ? "*" : "") + (l.lowerBound ? "↑" : ""))
                    .frame(width: 80, alignment: .trailing)
                Text("\(kg(l.bestWeight))×\(l.bestReps) · \(shortDate(l.bestDate))")
                    .font(.rounded(12, .medium)).foregroundStyle(Palette.dim)
                    .frame(width: 130, alignment: .trailing)
                Group {
                    if let dl = l.delta {
                        Text(signed(dl)).foregroundStyle(dl > 0 ? Palette.strength : (dl < 0 ? Palette.interval : Palette.dim))
                    } else {
                        Text("–").foregroundStyle(Palette.dim)
                    }
                }
                .frame(width: 56, alignment: .trailing)
                Group {
                    if let g = l.gauge { Text("Lv \(StatusEngine.level(g))") } else { Text("–").foregroundStyle(Palette.dim) }
                }
                .frame(width: 56, alignment: .trailing)
            }
            .font(.rounded(14, .semibold)).monospacedDigit()
            .padding(.vertical, 8).padding(.horizontal, 8)
            .background(on ? Palette.strength.opacity(0.14) : Color.clear, in: .rect(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func bwTable(_ rows: [BWLiftStat]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: "맨몸 종목").padding(.top, 14).padding(.horizontal, 8)
            ForEach(rows) { r in
                HStack {
                    Text(StatusEngine.display(r.name).name).lineLimit(1)
                    Spacer()
                    Text("최고 \(r.bestReps)회").foregroundStyle(Palette.dim)
                    Text(r.bestAdded > 0 ? "+\(kg(r.bestAdded))kg" : "맨몸")
                        .foregroundStyle(Palette.dim).frame(width: 80, alignment: .trailing)
                }
                .font(.rounded(13, .semibold)).monospacedDigit()
                .padding(.vertical, 4).padding(.horizontal, 8)
            }
        }
    }

    private func liftDetail(_ l: LiftStat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(StatusEngine.display(l.name).name).font(.rounded(16, .bold))
            HStack(spacing: 0) {
                ForEach(l.rms) { r in
                    VStack(spacing: 3) {
                        Text("\(r.reps)RM").font(.rounded(11, .bold)).foregroundStyle(Palette.dimmer)
                        Text(kg(r.weight)).font(.rounded(15, .bold)).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            let pts = e1RMHistory(l.name)
            if pts.count >= 2 {
                Chart(pts, id: \.date) { p in
                    LineMark(x: .value("날짜", p.date), y: .value("e1RM", p.value))
                        .foregroundStyle(Palette.strength)
                    PointMark(x: .value("날짜", p.date), y: .value("e1RM", p.value))
                        .foregroundStyle(Palette.strength)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 170)
            } else {
                Text("추이를 그릴 기록이 부족합니다.")
                    .font(.rounded(12, .medium)).foregroundStyle(Palette.dim)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04), in: .rect(cornerRadius: 14))
    }

    /// 종목의 날짜별 최고 e1RM (맨몸·무게 0 제외)
    private func e1RMHistory(_ name: String) -> [(date: Date, value: Double)] {
        var byDay: [Date: Double] = [:]
        for s in sessions where s.kind == .strength {
            for l in s.lifts where !l.isBW && l.weight > 0 && StatusEngine.statName(l) == name {
                let e = StatusEngine.e1RM(of: l)
                if e > 0 { byDay[s.logicalDay] = max(byDay[s.logicalDay] ?? 0, e) }
            }
        }
        return byDay.map { (date: $0.key, value: $0.value) }.sorted { $0.date < $1.date }
    }

    // MARK: 유산소 / 볼륨 / 균형 / 체성분

    private func cardioCard(_ c: CardioSummary) -> some View {
        CardBox {
            SectionLabel(text: "유산소 (최근 28일)")
            if c.sessions == 0 {
                emptyText("최근 28일 유산소 기록이 없습니다.")
            } else {
                HStack(spacing: 24) {
                    miniStat("세션", "\(c.sessions)회")
                    miniStat("거리", String(format: "%.1fkm", c.km))
                    miniStat("시간", "\(c.minutes)분")
                    miniStat("최고 페이스", c.bestPace.map { "\($0.clockString)/km" } ?? "–")
                }
            }
        }
    }

    private func volumeCard(_ snap: StatusSnapshot) -> some View {
        CardBox {
            SectionLabel(text: "패턴별 볼륨 · \(snap.volumeWindowIsRecent ? "최근 28일" : "전체 기록") (세트)")
            if snap.volumes.allSatisfy({ $0.sets == 0 }) {
                emptyText("근력 기록이 없습니다.")
            } else {
                Chart(snap.volumes) { v in
                    BarMark(x: .value("세트", v.sets), y: .value("패턴", v.pattern.label))
                        .foregroundStyle(Palette.strength)
                        .annotation(position: .trailing) {
                            Text("\(v.sets)").font(.rounded(11, .bold)).foregroundStyle(Palette.dim)
                        }
                }
                .chartYScale(domain: snap.volumes.map(\.pattern.label))
                .frame(height: CGFloat(snap.volumes.count) * 30 + 10)
            }
        }
    }

    private func flagsCard(_ flags: [BalanceFlag]) -> some View {
        CardBox {
            SectionLabel(text: "균형")
            if flags.isEmpty {
                emptyText("판정할 근력 기록이 부족합니다.")
            } else {
                ForEach(flags) { f in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: flagSymbol(f.level)).foregroundStyle(flagColor(f.level))
                        Text(f.text).font(.rounded(13, .medium))
                    }
                }
            }
        }
    }

    private func bodyCard(_ stats: [BodyStat]) -> some View {
        CardBox {
            SectionLabel(text: "체성분")
            if stats.isEmpty {
                emptyText("체성분 기록이 없습니다.")
            } else {
                ForEach(stats) { s in
                    HStack {
                        Text(s.label).font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                        Spacer()
                        Text(String(format: "%.\(s.decimals)f", s.latest) + " \(s.unit)")
                            .font(.rounded(14, .bold)).monospacedDigit()
                        deltaText(s.deltaPrev, s).frame(width: 64, alignment: .trailing)
                        Text(shortDate(s.latestDate)).font(.rounded(11, .medium))
                            .foregroundStyle(Palette.dimmer).frame(width: 44, alignment: .trailing)
                    }
                }
                Text("증감은 직전 측정 대비").font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)
            }
        }
    }

    @ViewBuilder
    private func deltaText(_ d: Double?, _ s: BodyStat) -> some View {
        if let d {
            let good: Bool? = switch s.better {
            case .higher: d == 0 ? nil : d > 0
            case .lower: d == 0 ? nil : d < 0
            case .neutral: nil
            }
            Text((d > 0 ? "+" : "") + String(format: "%.\(s.decimals)f", d))
                .font(.rounded(12, .semibold)).monospacedDigit()
                .foregroundStyle(good == nil ? Palette.dim : (good! ? Palette.strength : Palette.interval))
        } else {
            Text("–").font(.rounded(12, .semibold)).foregroundStyle(Palette.dim)
        }
    }

    // MARK: 공용 조각

    private func bar(_ g: Double, tint: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(tint).frame(width: geo.size.width * min(1, max(0, g)))
            }
        }
        .frame(height: 8)
    }

    private func miniStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.rounded(11, .bold)).foregroundStyle(Palette.dimmer)
            Text(value).font(.rounded(15, .bold)).monospacedDigit()
        }
    }

    private func emptyText(_ t: String) -> some View {
        Text(t).font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
    }

    private func flagSymbol(_ l: FlagLevel) -> String {
        switch l {
        case .ok: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        case .warn: "exclamationmark.triangle.fill"
        }
    }

    private func flagColor(_ l: FlagLevel) -> Color {
        switch l {
        case .ok: Palette.strength
        case .info: Color.white.opacity(0.6)
        case .warn: Palette.activity
        }
    }

    private func kg(_ w: Double) -> String {
        w.rounded() == w ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }

    private func signed(_ d: Double) -> String { (d > 0 ? "+" : "") + kg(d) }

    private func shortDate(_ d: Date) -> String {
        d.formatted(.dateTime.month().day())
    }
}
