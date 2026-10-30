import SwiftUI
import SwiftData

// "상태" 화면. 계산은 전부 StatusEngine, 여기서는 그리기만 한다.
struct StatusView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query(sort: \BodyRecord.date, order: .reverse) private var bodies: [BodyRecord]
    @Query(sort: \Vital.date, order: .reverse) private var vitals: [Vital]
    @State private var triedVitals = false

    var body: some View {
        let snap = StatusEngine.snapshot(sessions: sessions, bodies: bodies, vitals: vitals)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    BuildCard(build: snap.build)
                    BodySection(stats: snap.body)
                    CardioSection(vitals: snap.vitals, summary: snap.cardio)
                    StrengthSection(snap: snap)
                }
                .padding(18).padding(.bottom, 40)
            }
            .background(Palette.bg)
            .navigationTitle("상태")
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        // 지표 탭이 없어졌으므로 첫 실행 때 한 번은 여기서 건강 앱 지표를 끌어온다
        .task {
            guard vitals.isEmpty, !triedVitals else { return }
            triedVitals = true
            VitalsImporter.importAll(existing: [], insert: { ctx.insert($0) }) { _, _ in }
        }
    }
}

// MARK: - 공통 조각

private enum StatTint {
    static let strength = Palette.strength
    static let endurance = Palette.interval
    static let hybrid = WatchTint.distance
    static let novice = Color.white.opacity(0.7)
    static let warn = Color(red: 1.00, green: 0.62, blue: 0.20)

    static func archetype(_ a: Archetype) -> Color {
        switch a {
        case .novice: novice
        case .strength: strength
        case .endurance: endurance
        case .hybrid: hybrid
        }
    }
}

/// 10칸 세그먼트 게이지 (RPG 스탯 바)
private struct SegmentBar: View {
    let value: Double?      // 0...1
    let tint: Color
    var segments = 10
    var height: CGFloat = 6

    var body: some View {
        let filled = value.map { Int(($0 * Double(segments)).rounded()) } ?? 0
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < filled ? tint : Color.white.opacity(0.08))
                    .frame(height: height)
            }
        }
    }
}

private struct LevelTag: View {
    let gauge: Double?
    let tint: Color
    var body: some View {
        Text(gauge.map { "Lv \(StatusEngine.level($0))" } ?? "Lv –")
            .font(.rounded(10, .heavy)).monospacedDigit()
            .foregroundStyle(gauge == nil ? Palette.dimmer : tint)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background((gauge == nil ? Color.white : tint).opacity(0.12), in: .capsule)
    }
}

private struct DeltaText: View {
    let delta: Double?
    let better: Better
    var decimals = 1
    var size: CGFloat = 13

    var body: some View {
        if let d = delta {
            Text(Fmt.signed(d, decimals))
                .font(.rounded(size, .bold)).monospacedDigit()
                .foregroundStyle(color(d))
        }
    }

    private func color(_ d: Double) -> Color {
        let eps = decimals == 0 ? 0.5 : 0.05
        if abs(d) < eps || better == .neutral { return Palette.dim }
        let good = better == .higher ? d > 0 : d < 0
        return good ? Palette.strength : WatchTint.energy
    }
}

private enum Fmt {
    static func num(_ v: Double, _ decimals: Int) -> String {
        String(format: "%.\(decimals)f", v)
    }
    static func signed(_ v: Double, _ decimals: Int) -> String {
        var s = num(v, decimals)
        if s.hasPrefix("-"), Double(s) == 0 { s.removeFirst() }   // "-0.0" 방지
        return s.hasPrefix("-") ? s : "+" + s
    }
    static func kg(_ v: Double) -> String { v.trimmed }
}

private struct SectionHeader: View {
    let title: String
    let symbol: String
    let tint: Color
    /// 상세 화면으로 들어갈 수 있는 섹션이면 화살표를 붙인다
    var more: Bool = false
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
            SectionLabel(text: title)
            if more {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Palette.dimmer)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .contentShape(.rect)
    }
}

private struct EmptyLine: View {
    let text: String
    var body: some View {
        Text(text).font(.rounded(13, .medium)).foregroundStyle(Palette.dimmer)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 1. 빌드

private struct BuildCard: View {
    let build: BuildInfo

    var body: some View {
        let tint = StatTint.archetype(build.archetype)
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "목표 · 빌드 방향", symbol: "scope", tint: tint)
            CardBox {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle().fill(tint.opacity(0.14))
                        Circle().trim(from: 0, to: build.levelProgress)
                            .stroke(tint, style: .init(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: build.archetype.symbol)
                            .font(.system(size: 24, weight: .bold)).foregroundStyle(tint)
                    }
                    .frame(width: 62, height: 62)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(build.archetype.label)
                                .font(.rounded(24, .heavy)).foregroundStyle(.white)
                            Text("Lv \(build.level)")
                                .font(.rounded(13, .heavy)).monospacedDigit()
                                .foregroundStyle(.black)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(tint, in: .capsule)
                        }
                        Text(build.archetype.subtitle)
                            .font(.rounded(12, .medium)).foregroundStyle(Palette.dim)
                        Text("누적 \(build.totalSessions)회 · 주 \(Fmt.num(build.weeklyFrequency, 1))회 · 다음 레벨까지 \(5 - build.totalSessions % 5)회")
                            .font(.rounded(11, .semibold)).foregroundStyle(Palette.dimmer)
                    }
                    Spacer(minLength: 0)
                }

                axis(tint: tint)

                HStack(spacing: 8) {
                    chip(build.trend.label, symbol: trendSymbol)
                    chip(build.bodyDirection.label, symbol: "figure.stand")
                }

                Divider().overlay(Palette.cardStroke)

                VStack(spacing: 9) {
                    ForEach(build.core) { c in
                        HStack(spacing: 10) {
                            Text(c.code).font(.rounded(11, .heavy)).monospaced()
                                .foregroundStyle(coreTint(c.code))
                                .frame(width: 38, alignment: .leading)
                            Text(c.label).font(.rounded(12, .semibold))
                                .foregroundStyle(Palette.dim)
                                .frame(width: 44, alignment: .leading)
                            SegmentBar(value: c.gauge, tint: coreTint(c.code))
                            LevelTag(gauge: c.gauge, tint: coreTint(c.code))
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private var trendSymbol: String {
        switch build.trend {
        case .towardStrength: "arrow.right"
        case .towardEndurance: "arrow.left"
        case .steady: "equal"
        case .unknown: "questionmark"
        }
    }

    private func coreTint(_ code: String) -> Color {
        switch code {
        case "STR": Palette.strength
        case "END": Palette.interval
        case "REC": WatchTint.distance
        default: Palette.condition(.normal)
        }
    }

    /// 유산소 ←→ 근력 축 위의 현재 위치
    private func axis(tint: Color) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(LinearGradient(
                        colors: [StatTint.endurance.opacity(0.55), StatTint.hybrid.opacity(0.45),
                                 StatTint.strength.opacity(0.55)],
                        startPoint: .leading, endPoint: .trailing))
                        .frame(height: 6)
                    if let s = build.strengthShare {
                        Circle().fill(.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                            .offset(x: max(0, min(w - 14, w * s - 7)))
                    }
                }
                .frame(height: 14)
            }
            .frame(height: 14)
            HStack {
                Text("유산소 \(build.cardioCount)").foregroundStyle(StatTint.endurance)
                Spacer()
                Text("최근 8주").foregroundStyle(Palette.dimmer)
                Spacer()
                Text("근력 \(build.strengthCount)").foregroundStyle(StatTint.strength)
            }
            .font(.rounded(11, .bold)).monospacedDigit()
        }
    }

    private func chip(_ text: String, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            Text(text).font(.rounded(11, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(Palette.dim)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Color.white.opacity(0.07), in: .capsule)
    }
}

// MARK: - 2. 체성분

private struct BodySection: View {
    let stats: [BodyStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink { BodyView() } label: {
                SectionHeader(title: "체성분", symbol: "figure.stand",
                              tint: WatchTint.distance, more: true)
            }
            .buttonStyle(.plain)
            CardBox {
                if stats.isEmpty {
                    EmptyLine(text: "눌러서 인바디 CSV 또는 건강 앱 기록을 가져오세요")
                } else {
                    if let d = stats.first?.latestDate {
                        HStack {
                            Text("최근 측정 \(d.monthDay)").font(.rounded(11, .semibold))
                                .foregroundStyle(Palette.dimmer)
                            Spacer()
                            Text("직전 / 처음 대비").font(.rounded(11, .semibold))
                                .foregroundStyle(Palette.dimmer)
                        }
                    }
                    VStack(spacing: 12) {
                        ForEach(stats) { row($0) }
                    }
                }
            }
        }
    }

    private func tint(_ s: BodyStat) -> Color {
        switch s.label {
        case "체중": WatchTint.distance
        case "골격근량", "SMI": Palette.strength
        case "체지방량", "체지방률", "내장지방": WatchTint.energy
        case "인바디 점수": WatchTint.time
        default: WatchTint.pace
        }
    }

    private func row(_ s: BodyStat) -> some View {
        let c = tint(s)
        return VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(s.label).font(.rounded(12, .bold)).foregroundStyle(c.opacity(0.9))
                    .frame(width: 70, alignment: .leading)
                Text(Fmt.num(s.latest, s.decimals))
                    .font(.rounded(20, .bold)).monospacedDigit().foregroundStyle(.white)
                Text(s.unit).font(.rounded(10, .bold)).foregroundStyle(Palette.dimmer)
                Spacer()
                DeltaText(delta: s.deltaPrev, better: s.better, decimals: s.decimals, size: 12)
                Text("/").font(.rounded(11)).foregroundStyle(Palette.dimmer)
                    .opacity(s.deltaPrev == nil ? 0 : 1)
                DeltaText(delta: s.deltaFirst, better: s.better, decimals: s.decimals, size: 12)
            }
            if s.gauge != nil {
                HStack(spacing: 8) {
                    SegmentBar(value: s.gauge, tint: c, height: 4)
                    LevelTag(gauge: s.gauge, tint: c).frame(width: 48, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - 3. 유산소 능력

private struct CardioSection: View {
    let vitals: [VitalStat]
    let summary: CardioSummary

    var body: some View {
        let have = vitals.filter(\.hasData)
        let missing = vitals.filter { !$0.hasData }
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink { VitalsView() } label: {
                SectionHeader(title: "운동 능력 · 유산소", symbol: "heart.fill",
                              tint: Palette.interval, more: true)
            }
            .buttonStyle(.plain)
            CardBox {
                HStack(spacing: 0) {
                    mini("\(summary.sessions)", "회", "4주 세션")
                    mini(Fmt.num(summary.km, 1), "km", "거리")
                    mini("\(summary.minutes)", "분", "시간")
                    mini(summary.bestPace?.clockString ?? "–", "/km", "최고 페이스")
                }
                Divider().overlay(Palette.cardStroke)
                if have.isEmpty {
                    EmptyLine(text: "눌러서 건강 앱 지표를 가져오세요")
                } else {
                    VStack(spacing: 12) {
                        ForEach(have) { row($0) }
                    }
                }
                if !missing.isEmpty {
                    Text("측정 안 됨 · " + missing.map(\.kind.label).joined(separator: " · "))
                        .font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)
                }
            }
        }
    }

    private func mini(_ v: String, _ unit: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(v).font(.rounded(18, .bold)).monospacedDigit().foregroundStyle(.white)
                Text(unit).font(.rounded(9, .bold)).foregroundStyle(Palette.dimmer)
            }
            Text(label).font(.rounded(10, .semibold)).foregroundStyle(Palette.dim)
        }
        .frame(maxWidth: .infinity)
    }

    private func tint(_ k: VitalKind) -> Color {
        switch k {
        case .vo2Max: WatchTint.pace
        case .restingHR, .hrRecovery, .walkingHR: WatchTint.heart
        case .hrv: WatchTint.distance
        case .respiratory: Palette.strength
        case .oxygen: WatchTint.time
        case .wristTemp: WatchTint.energy
        }
    }

    private func decimals(_ k: VitalKind) -> Int {
        switch k {
        case .vo2Max, .wristTemp, .hrv, .respiratory: 1
        default: 0
        }
    }

    private func row(_ v: VitalStat) -> some View {
        let c = tint(v.kind)
        let d = decimals(v.kind)
        return VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(v.kind.label).font(.rounded(12, .bold)).foregroundStyle(c.opacity(0.9))
                    .frame(width: 70, alignment: .leading)
                Text(Fmt.num(v.value ?? 0, d))
                    .font(.rounded(20, .bold)).monospacedDigit().foregroundStyle(.white)
                Text(v.kind.unit).font(.rounded(10, .bold)).foregroundStyle(Palette.dimmer)
                Spacer()
                DeltaText(delta: v.delta, better: v.kind.higherIsBetter ? .higher : .lower,
                          decimals: d, size: 12)
                if let date = v.lastDate {
                    Text(date.monthDay).font(.rounded(10, .semibold)).foregroundStyle(Palette.dimmer)
                }
            }
            if v.gauge != nil {
                HStack(spacing: 8) {
                    SegmentBar(value: v.gauge, tint: c, height: 4)
                    LevelTag(gauge: v.gauge, tint: c).frame(width: 48, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - 4. 근력

private struct StrengthSection: View {
    let snap: StatusSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "근력", symbol: "dumbbell.fill", tint: Palette.strength)
            CardBox {
                if snap.lifts.isEmpty {
                    EmptyLine(text: "중량 운동 기록이 쌓이면 RM 이 추정됩니다")
                } else {
                    header
                    VStack(spacing: 0) {
                        ForEach(Array(snap.lifts.enumerated()), id: \.element.id) { i, l in
                            if i > 0 { Divider().overlay(Palette.cardStroke) }
                            NavigationLink {
                                LiftHistoryView(stat: l)
                            } label: {
                                liftRow(l)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("종목").frame(maxWidth: .infinity, alignment: .leading)
            Text("1RM").frame(width: 70, alignment: .trailing)
            Color.clear.frame(width: 16)
        }
        .font(.rounded(10, .bold)).foregroundStyle(Palette.dimmer)
    }

    private func liftRow(_ l: LiftStat) -> some View {
        HStack(spacing: 0) {
            let d = StatusEngine.display(l.name)
            HStack(spacing: 5) {
                Text(d.name).font(.rounded(14, .bold)).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                LiftBadges(badges: d.badges, size: 9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 상세 화면과 같은 값(0.5kg 반올림)을 쓴다
            Text(Fmt.kg(l.rms.first?.weight ?? l.e1RM))
                .font(.rounded(18, .heavy)).monospacedDigit()
                .foregroundStyle(Palette.strength)
                .frame(width: 70, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.dimmer)
                .frame(width: 16, alignment: .trailing)
        }
        .padding(.vertical, 11)
        .contentShape(.rect)
    }
}

// MARK: - 종목 상세: 날짜별 기록

private struct LiftHistoryView: View {
    let stat: LiftStat
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    private struct Entry: Identifiable {
        let id: UUID
        let day: Date
        let lift: LiftEntry
        let e1RM: Double?
    }

    private var entries: [Entry] {
        sessions.flatMap { s in
            s.lifts
                .filter { StatusEngine.statName($0) == stat.name }
                .map { l in
                    Entry(id: l.id, day: s.logicalDay, lift: l,
                          e1RM: l.isBW || l.weight <= 0 ? nil : StatusEngine.e1RM(of: l))
                }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CardBox {
                    HStack(spacing: 0) {
                        ForEach(stat.rms) { rm in
                            VStack(spacing: 3) {
                                Text("\(rm.reps)RM")
                                    .font(.rounded(11, .bold)).foregroundStyle(Palette.dimmer)
                                Text(Fmt.kg(rm.weight))
                                    .font(.rounded(rm.reps == 1 ? 24 : 19, .heavy)).monospacedDigit()
                                    .foregroundStyle(rm.reps == 1 ? Palette.strength : .white)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                VStack(spacing: 10) {
                    ForEach(entries) { e in
                        HStack(alignment: .center, spacing: 14) {
                            VStack(spacing: 2) {
                                Text(e.day.monthDay)
                                    .font(.rounded(15, .bold)).monospacedDigit()
                                    .foregroundStyle(.white)
                                Text(e.day.weekdayShort)
                                    .font(.rounded(11, .semibold))
                                    .foregroundStyle(Palette.dimmer)
                            }
                            .frame(width: 46)
                            Rectangle().fill(Palette.strength.opacity(0.5)).frame(width: 2)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 5) {
                                    Text(e.lift.weightLabel)
                                        .font(.rounded(17, .heavy)).monospacedDigit()
                                        .foregroundStyle(Palette.strength)
                                    LiftBadges(e.lift, size: 10)
                                }
                                Text(e.lift.repsDetail)
                                    .font(.rounded(13, .semibold)).monospacedDigit()
                                    .foregroundStyle(Palette.dim)
                            }
                            Spacer()
                            if let v = e.e1RM {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("1RM").font(.rounded(10, .bold)).foregroundStyle(Palette.dimmer)
                                    Text(Fmt.kg(v))
                                        .font(.rounded(17, .bold)).monospacedDigit()
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(14)
                        .background(Palette.card, in: .rect(cornerRadius: 16))
                    }
                }
            }
            .padding(18).padding(.bottom, 40)
        }
        .background(Palette.bg)
        .navigationTitle(StatusEngine.display(stat.name).name)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.bg, for: .navigationBar)
    }
}

private struct BalanceCard: View {
    let volumes: [PatternVolume]
    let recent: Bool
    let flags: [BalanceFlag]

    var body: some View {
        CardBox {
            HStack {
                Text("밸런스 분석").font(.rounded(12, .bold)).foregroundStyle(Palette.dim)
                Spacer()
                Text(recent ? "최근 4주 세트 수" : "전체 기록 세트 수")
                    .font(.rounded(10, .semibold)).foregroundStyle(Palette.dimmer)
            }
            if volumes.allSatisfy({ $0.sets == 0 }) {
                EmptyLine(text: "근력 기록이 없어 분석할 수 없습니다")
            } else {
                let top = max(1, volumes.map(\.sets).max() ?? 1)
                VStack(spacing: 7) {
                    ForEach(volumes) { v in
                        HStack(spacing: 10) {
                            Text(v.pattern.label).font(.rounded(12, .semibold))
                                .foregroundStyle(v.sets == 0 ? StatTint.warn : Palette.dim)
                                .frame(width: 56, alignment: .leading)
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.07))
                                    Capsule().fill(Palette.strength.opacity(0.8))
                                        .frame(width: g.size.width * Double(v.sets) / Double(top))
                                }
                            }
                            .frame(height: 6)
                            Text("\(v.sets)").font(.rounded(12, .bold)).monospacedDigit()
                                .foregroundStyle(.white).frame(width: 28, alignment: .trailing)
                        }
                    }
                }
                Divider().overlay(Palette.cardStroke)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(flags) { f in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: symbol(f.level))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(color(f.level))
                            Text(f.text).font(.rounded(12, .medium))
                                .foregroundStyle(f.level == .ok ? Palette.dim : .white)
                        }
                    }
                }
            }
        }
    }

    private func symbol(_ l: FlagLevel) -> String {
        switch l {
        case .ok: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        case .warn: "exclamationmark.triangle.fill"
        }
    }

    private func color(_ l: FlagLevel) -> Color {
        switch l {
        case .ok: Palette.strength
        case .info: WatchTint.distance
        case .warn: StatTint.warn
        }
    }
}
