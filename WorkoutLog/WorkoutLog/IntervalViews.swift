import SwiftUI
import SwiftData
import Charts

// 인터벌 세션 전용 화면. 질주 = 인터벌 핑크, 회복 = 시안, 워밍업 = 라임.
private enum ITint {
    static let work = Palette.interval
    static let recovery = WatchTint.distance
    static let warmup = WatchTint.time
    static let cooldown = Color.white.opacity(0.35)
    static let good = Palette.condition(.good)
    static let mid = Palette.condition(.normal)
    static let bad = Palette.condition(.bad)
}

private func paceText(_ p: Int?) -> String { p.map { $0.clockString } ?? "--:--" }

// MARK: - 운동 목록 한 줄 요약

struct IntervalRowSummary: View {
    let detail: IntervalDetail
    let hr: [MetricPoint]
    private var r: IntervalReport { IntervalAnalysis.report(detail, hr: hr) }

    var body: some View {
        let r = r
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                if let n = detail.planName, !n.isEmpty {
                    Text(n).font(.rounded(13, .bold)).foregroundStyle(.white)
                }
                Text(detail.planSummary)
                    .font(.rounded(12, .semibold)).foregroundStyle(Palette.dim)
            }
            FlowBar(detail: detail, height: 8)
            HStack(spacing: 10) {
                Label("\(paceText(r.workPace))/km", systemImage: "bolt.fill")
                    .foregroundStyle(ITint.work)
                if r.workPower > 0 {
                    Text("\(Int(r.workPower))W").foregroundStyle(WatchTint.energy)
                }
                Label("\(Int(r.workPeakHR))", systemImage: "heart.fill")
                    .foregroundStyle(WatchTint.heart)
                if let d = r.avgDrop60 {
                    Text(String(format: "회복 %+.0f", -d))
                        .foregroundStyle(ITint.recovery)
                }
            }
            .font(.rounded(12, .bold)).monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.8)
            if let w = detail.warmup {
                Label("워밍업 \(Int(w.seconds).hmsString) · \(String(format: "%.2fkm", w.meters / 1000))",
                      systemImage: "flame")
                    .font(.rounded(11, .semibold)).monospacedDigit()
                    .foregroundStyle(ITint.warmup.opacity(0.8))
            }
        }
    }
}

/// 구간 흐름 막대 (질주·회복·쿨다운 비율대로)
struct FlowBar: View {
    let detail: IntervalDetail
    var height: CGFloat = 10

    var body: some View {
        let segs = detail.segments.sorted { $0.start < $1.start }
        let total = max(1, segs.reduce(0) { $0 + $1.seconds })
        GeometryReader { g in
            HStack(spacing: 2) {
                ForEach(segs) { s in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(s.kind).opacity(s.completed || s.kind == .cooldown ? 1 : 0.45))
                        .frame(width: max(2, (g.size.width - CGFloat(segs.count) * 2) * s.seconds / total))
                }
            }
        }
        .frame(height: height)
    }

    private func color(_ k: IntervalSegment.Kind) -> Color {
        switch k {
        case .work: ITint.work
        case .recovery: ITint.recovery
        case .warmup: ITint.warmup
        case .cooldown: ITint.cooldown
        }
    }
}

// MARK: - 상세 화면 섹션

struct IntervalSections: View {
    let session: Session
    let detail: IntervalDetail
    let estMax: Int
    @Query(sort: \Session.date) private var all: [Session]

    private var hr: [MetricPoint] { session.telemetry.hr }
    private var report: IntervalReport { IntervalAnalysis.report(detail, hr: hr) }

    /// 이 세션보다 앞선 워밍업들 (컨디션 비교 기준)
    private var pastWarmups: [WarmupRun] {
        all.filter { $0.date < session.date && $0.intervalDetailData != nil }
            .compactMap { $0.intervalDetail?.warmup }
    }

    var body: some View {
        let r = report
        overview(r)
        if let w = detail.warmup {
            WarmupCard(warmup: w,
                       report: IntervalAnalysis.warmup(w, mainStart: session.startAt,
                                                       history: pastWarmups, estMax: Double(estMax)))
        }
        if hr.count > 1 {
            CardBox {
                SectionLabel(text: "심박 흐름 · 질주 구간 표시")
                IntervalHRChart(hr: hr, segments: detail.segments, height: 180)
                legend
            }
        }
        WorkCard(report: r)
        RecoveryCard(report: r, estMax: estMax)
        QualityCard(report: r, detail: detail, estMax: estMax)
    }

    // MARK: 종합

    private func overview(_ r: IntervalReport) -> some View {
        CardBox {
            HStack {
                SectionLabel(text: "인터벌 종합")
                Spacer()
                Text("\(r.completedSets)/\(detail.plannedSets ?? r.reps.count) 완료")
                    .font(.rounded(12, .bold)).monospacedDigit()
                    .foregroundStyle(r.completedSets >= (detail.plannedSets ?? r.reps.count) ? ITint.good : ITint.mid)
            }
            VStack(alignment: .leading, spacing: 4) {
                if let n = detail.planName, !n.isEmpty {
                    Text(n).font(.rounded(20, .bold)).foregroundStyle(.white)
                }
                Text(detail.planSummary).font(.rounded(14, .semibold)).foregroundStyle(Palette.dim)
            }
            FlowBar(detail: detail, height: 12)

            HStack(alignment: .top, spacing: 12) {
                column("질주", ITint.work, [
                    ("시간 · 거리", "\(Int(r.workSeconds).clockString) · \(Int(r.workMeters))m"),
                    ("평균 페이스", "\(paceText(r.workPace))/km"),
                    ("평균 파워", r.workPower > 0 ? "\(Int(r.workPower))W (최고 \(Int(r.workMaxPower)))" : "-"),
                    ("평균 · 최고 심박", "\(Int(r.workHR)) · \(Int(r.workPeakHR))"),
                ])
                column("회복", ITint.recovery, [
                    ("시간", Int(r.recoverySeconds).clockString),
                    ("평균 페이스", "\(paceText(r.recoveryPace))/km"),
                    ("60초 심박 하락", r.avgDrop60.map { String(format: "%.0f bpm", $0) } ?? "-"),
                    ("다음 질주 전", r.avgHRBeforeNext.map { "\(Int($0)) bpm" } ?? "-"),
                ])
            }
        }
    }

    private func column(_ title: String, _ c: Color, _ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.rounded(13, .heavy)).foregroundStyle(c)
            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.0).font(.rounded(10, .bold)).foregroundStyle(Palette.dimmer)
                    Text(row.1).font(.rounded(15, .bold)).monospacedDigit().foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(c.opacity(0.08), in: .rect(cornerRadius: 14))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            dot(ITint.work, "질주")
            dot(ITint.recovery, "회복")
            dot(WatchTint.heart, "심박")
        }
    }

    private func dot(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text(t).font(.rounded(11, .semibold)).foregroundStyle(Palette.dim)
        }
    }
}

// MARK: - 심박 + 구간 차트

struct IntervalHRChart: View {
    let hr: [MetricPoint]
    let segments: [IntervalSegment]
    var height: CGFloat = 180

    private var clean: [MetricPoint] { hr.filter { $0.v > 0 }.sorted { $0.t < $1.t } }
    private var yDomain: ClosedRange<Double> {
        let v = clean.map(\.v)
        guard let lo = v.min(), let hi = v.max() else { return 60...200 }
        return (lo - 8)...(hi + 5)
    }

    var body: some View {
        let y = yDomain
        Chart {
            ForEach(segments.filter { $0.kind == .work }) { s in
                RectangleMark(xStart: .value("시작", s.start), xEnd: .value("끝", s.end),
                              yStart: .value("하", y.lowerBound), yEnd: .value("상", y.upperBound))
                    .foregroundStyle(ITint.work.opacity(0.22))
            }
            ForEach(segments.filter { $0.kind == .cooldown }) { s in
                RectangleMark(xStart: .value("시작", s.start), xEnd: .value("끝", s.end),
                              yStart: .value("하", y.lowerBound), yEnd: .value("상", y.upperBound))
                    .foregroundStyle(Color.white.opacity(0.05))
            }
            ForEach(clean) { p in
                LineMark(x: .value("시간", p.t), y: .value("BPM", p.v))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(WatchTint.heart)
                    .lineStyle(.init(lineWidth: 2, lineCap: .round))
            }
        }
        .chartYScale(domain: y)
        .chartPlotStyle { $0.clipped() }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel().foregroundStyle(Palette.dimmer).font(.rounded(10, .semibold))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { v in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel {
                    if let t = v.as(Double.self) {
                        Text(Int(t).clockString).font(.rounded(10, .semibold)).foregroundStyle(Palette.dimmer)
                    }
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - 질주 구간

private struct WorkCard: View {
    let report: IntervalReport

    var body: some View {
        let reps = report.reps
        let bestPower = reps.map(\.work.avgPower).max() ?? 0
        let bestPace = reps.compactMap(\.work.pace).min()
        CardBox {
            SectionLabel(text: "질주 구간 · 강도")
            if reps.contains(where: { $0.work.avgPower > 0 }) {
                Chart(reps) { r in
                    BarMark(x: .value("회차", "\(r.round)"), y: .value("파워", r.work.avgPower), width: .ratio(0.55))
                        .foregroundStyle(r.work.avgPower == bestPower ? ITint.work : ITint.work.opacity(0.55))
                        .cornerRadius(4)
                        .annotation(position: .top, spacing: 3) {
                            Text("\(Int(r.work.avgPower))")
                                .font(.rounded(10, .bold)).monospacedDigit().foregroundStyle(Palette.dim)
                        }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().font(.rounded(11, .bold)).foregroundStyle(Palette.dim) }
                }
                .frame(height: 110)
            }
            header
            ForEach(reps) { r in
                HStack(spacing: 0) {
                    Text("\(r.round)").frame(width: 22, alignment: .leading).foregroundStyle(Palette.dim)
                    Text(paceText(r.work.pace))
                        .foregroundStyle(r.work.pace == bestPace ? WatchTint.pace : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(r.work.avgPower > 0 ? "\(Int(r.work.avgPower))/\(Int(r.work.maxPower))" : "-")
                        .foregroundStyle(WatchTint.energy)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(Int(r.work.avgHR))/\(Int(r.peakHR))")
                        .foregroundStyle(WatchTint.heart)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(Int(r.work.meters))m")
                        .foregroundStyle(WatchTint.distance)
                        .frame(width: 50, alignment: .trailing)
                    Text(r.work.cadence > 0 ? "\(r.work.cadence)" : "-")
                        .foregroundStyle(Palette.dim)
                        .frame(width: 38, alignment: .trailing)
                }
                .font(.rounded(14, .bold)).monospacedDigit()
                .opacity(r.work.completed ? 1 : 0.5)
            }
            Text("파워·심박은 평균/최고. 최고 심박은 질주 후 25초까지 포함 (심박은 늦게 오른다).")
                .font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 22, alignment: .leading)
            Text("페이스").frame(maxWidth: .infinity, alignment: .leading)
            Text("파워 W").frame(maxWidth: .infinity, alignment: .leading)
            Text("심박").frame(maxWidth: .infinity, alignment: .leading)
            Text("거리").frame(width: 50, alignment: .trailing)
            Text("spm").frame(width: 38, alignment: .trailing)
        }
        .font(.rounded(10, .bold)).foregroundStyle(Palette.dimmer)
    }
}

// MARK: - 회복 구간

private struct RecoveryCard: View {
    let report: IntervalReport
    let estMax: Int

    private var reps: [IntervalRep] { report.reps.filter { $0.recovery != nil } }

    var body: some View {
        CardBox {
            SectionLabel(text: "회복 구간 · 회복력")
            Chart(reps) { r in
                BarMark(x: .value("회차", "\(r.round)"),
                        yStart: .value("회복 끝", r.hrBeforeNext ?? r.peakHR),
                        yEnd: .value("최고", r.peakHR), width: .ratio(0.45))
                    .foregroundStyle(dropColor(r.drop60).opacity(0.85))
                    .cornerRadius(4)
                PointMark(x: .value("회차", "\(r.round)"), y: .value("최고", r.peakHR))
                    .foregroundStyle(WatchTint.heart).symbolSize(30)
                if let b = r.hrBeforeNext {
                    PointMark(x: .value("회차", "\(r.round)"), y: .value("회복 끝", b))
                        .foregroundStyle(ITint.recovery).symbolSize(30)
                }
            }
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel().foregroundStyle(Palette.dimmer).font(.rounded(10, .semibold))
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().font(.rounded(11, .bold)).foregroundStyle(Palette.dim) }
            }
            .frame(height: 140)
            (Text("● ").foregroundStyle(WatchTint.heart) + Text("질주 최고 심박   ")
                + Text("● ").foregroundStyle(ITint.recovery) + Text("다음 질주 직전 심박. 막대가 길수록 많이 내려온 것."))
                .font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)

            header
            ForEach(reps) { r in
                HStack(spacing: 0) {
                    Text("\(r.round)").frame(width: 22, alignment: .leading).foregroundStyle(Palette.dim)
                    Text(paceText(r.recovery?.pace))
                        .foregroundStyle(ITint.recovery)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(Int(r.peakHR))→\(r.hrBeforeNext.map { "\(Int($0))" } ?? "-")")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(r.drop60.map { $0 >= 0 ? "−\(Int($0.rounded()))" : "+\(Int((-$0).rounded()))" } ?? "-")
                        .foregroundStyle(dropColor(r.drop60))
                        .frame(width: 56, alignment: .trailing)
                    Text(r.hrBeforeNext.map { "\(Int($0 / Double(estMax) * 100))%" } ?? "-")
                        .foregroundStyle(Palette.dim)
                        .frame(width: 50, alignment: .trailing)
                }
                .font(.rounded(14, .bold)).monospacedDigit()
            }
            Text("60초 하락: 최고 심박에서 60초 뒤 떨어진 bpm. +면 회복 중 오히려 오른 것 (회복 조깅이 빠름). %는 다음 질주 직전 심박 ÷ 최대 \(estMax).")
                .font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)
        }
    }

    private var yDomain: ClosedRange<Double> {
        let v = reps.flatMap { [$0.peakHR] + ($0.hrBeforeNext.map { [$0] } ?? []) }
        guard let lo = v.min(), let hi = v.max() else { return 100...200 }
        return (lo - 6)...(hi + 4)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 22, alignment: .leading)
            Text("페이스").frame(maxWidth: .infinity, alignment: .leading)
            Text("심박 최고→끝").frame(maxWidth: .infinity, alignment: .leading)
            Text("60초").frame(width: 56, alignment: .trailing)
            Text("끝/최대").frame(width: 50, alignment: .trailing)
        }
        .font(.rounded(10, .bold)).foregroundStyle(Palette.dimmer)
    }

    /// 인터벌 회복 60초 하락 기준: 20↑ 좋음, 10~20 보통, 10↓ 부족
    private func dropColor(_ d: Double?) -> Color {
        guard let d else { return Palette.dim }
        return d >= 20 ? ITint.good : d >= 10 ? ITint.mid : ITint.bad
    }
}

// MARK: - 인터벌 품질 지표

private struct QualityCard: View {
    let report: IntervalReport
    let detail: IntervalDetail
    let estMax: Int

    var body: some View {
        CardBox {
            SectionLabel(text: "인터벌 품질")
            if let h = report.powerHold {
                row("파워 유지율", String(format: "%.0f%%", h),
                    "마지막 질주 파워 ÷ 첫 질주. 95%↑면 끝까지 강도 유지",
                    h >= 95 ? ITint.good : h >= 85 ? ITint.mid : ITint.bad)
            }
            if let cv = report.speedCV {
                row("질주 속도 편차", String(format: "%.1f%%", cv),
                    "회차별 질주 속도의 변동계수. 5%↓면 고르게 뜀",
                    cv <= 5 ? ITint.good : cv <= 10 ? ITint.mid : ITint.bad)
            }
            if let d = report.peakHRDrift {
                row("최고 심박 변화", String(format: "%+.0f bpm", d),
                    "첫 질주 대비 마지막 질주 최고 심박. 크면 피로 누적",
                    d <= 5 ? ITint.good : d <= 12 ? ITint.mid : ITint.bad)
            }
            if let f = report.recoveryFade {
                row("회복 저하", String(format: "%+.0f bpm", f),
                    "첫 회복 대비 마지막 회복의 60초 하락 감소폭. +면 뒤로 갈수록 회복이 느려짐",
                    f <= 3 ? ITint.good : f <= 8 ? ITint.mid : ITint.bad)
            }
            if let b = report.avgHRBeforeNext {
                let pct = b / Double(estMax) * 100
                row("질주 직전 심박", String(format: "%.0f%%", pct),
                    "다음 질주 시작 전 평균 심박 \(Int(b)) ÷ 최대. 85%↑면 덜 회복된 채 출발",
                    pct < 80 ? ITint.good : pct < 88 ? ITint.mid : ITint.bad)
            }
            if report.workSeconds > 0 {
                let ratio = report.recoverySeconds / report.workSeconds
                row("질주 : 회복", String(format: "1 : %.1f", ratio),
                    "시간 비율. 30초 전력 질주는 보통 1:3~1:5", Palette.dim)
            }
            if report.workMaxSpeed > 0 {
                row("최고 속도", String(format: "%.1f km/h", report.workMaxSpeed * 3.6),
                    "전체 질주 중 순간 최고 (\(paceText(Int(1000 / report.workMaxSpeed)))/km)", WatchTint.pace)
            }
        }
    }

    private func row(_ title: String, _ value: String, _ desc: String, _ c: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.rounded(14, .bold)).foregroundStyle(.white)
                Text(desc).font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            Text(value).font(.rounded(18, .bold)).monospacedDigit().foregroundStyle(c)
        }
    }
}

// MARK: - 워밍업

private struct WarmupCard: View {
    let warmup: WarmupRun
    let report: WarmupReport

    private var verdict: (String, Color, String) {
        switch report.verdict {
        case .good: ("좋음", ITint.good, "flame.fill")
        case .normal: ("보통", ITint.mid, "equal.circle.fill")
        case .heavy: ("무거움", ITint.bad, "battery.25percent")
        }
    }

    var body: some View {
        let v = verdict
        CardBox {
            HStack {
                SectionLabel(text: "워밍업")
                Spacer()
                Text("\(warmup.startAt.hmShort)–\(warmup.endAt.hmShort)")
                    .font(.rounded(12, .semibold)).monospacedDigit().foregroundStyle(Palette.dim)
            }
            HStack(spacing: 8) {
                Image(systemName: v.2).foregroundStyle(v.1)
                Text("컨디션 \(v.0)").font(.rounded(18, .bold)).foregroundStyle(v.1)
            }
            VStack(alignment: .leading, spacing: 5) {
                ForEach(report.reasons, id: \.self) { t in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle().fill(Palette.dim).frame(width: 4, height: 4)
                        Text(t).font(.rounded(12, .medium)).foregroundStyle(Palette.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      alignment: .leading, spacing: 12) {
                cell("시간", Int(report.seconds).hmsString, WatchTint.time)
                cell("거리", String(format: "%.2fkm", report.meters / 1000), WatchTint.distance)
                cell("페이스", "\(paceText(report.pace))/km", WatchTint.pace)
                cell("평균 심박", "\(Int(report.avgHR))", WatchTint.heart)
                cell("끝 심박", report.endHR.map { "\(Int($0))" } ?? "-", WatchTint.heart)
                cell("평균 파워", report.avgPower > 0 ? "\(Int(report.avgPower))W" : "-", WatchTint.energy)
            }
            if warmup.hr.count > 1 {
                warmupChart
            }
            if let g = report.gapToMain, g > 0 {
                Text("워밍업 끝 → 본운동 시작 \(Int(g).hmsString)")
                    .font(.rounded(12, .semibold)).monospacedDigit().foregroundStyle(Palette.dim)
            }
        }
    }

    private func cell(_ l: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(l).font(.rounded(10, .bold)).foregroundStyle(c.opacity(0.75))
            Text(v).font(.rounded(17, .bold)).monospacedDigit().foregroundStyle(c)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private var warmupChart: some View {
        let pts = warmup.hr.filter { $0.v > 0 }.sorted { $0.t < $1.t }
        let lo = (pts.map(\.v).min() ?? 60) - 5, hi = (pts.map(\.v).max() ?? 180) + 5
        return Chart {
            ForEach(warmup.pauses, id: \.from) { p in
                RectangleMark(xStart: .value("정지", p.from), xEnd: .value("재개", p.to),
                              yStart: .value("하", lo), yEnd: .value("상", hi))
                    .foregroundStyle(Color.white.opacity(0.06))
            }
            // 정지 구간은 선을 끊는다
            ForEach(pts) { p in
                LineMark(x: .value("시간", p.t), y: .value("BPM", p.v),
                         series: .value("구간", warmup.pauses.filter { $0.to <= p.t }.count))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(WatchTint.heart)
            }
        }
        .chartYScale(domain: lo...hi)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel().foregroundStyle(Palette.dimmer).font(.rounded(10, .semibold))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { v in
                AxisValueLabel {
                    if let t = v.as(Double.self) {
                        Text(Int(t).clockString).font(.rounded(10, .semibold)).foregroundStyle(Palette.dimmer)
                    }
                }
            }
        }
        .frame(height: 110)
    }
}
