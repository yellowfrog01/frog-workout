import SwiftUI
import SwiftData
import Charts
import HealthKit
import UniformTypeIdentifiers

struct BodyView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \BodyRecord.date, order: .reverse) private var records: [BodyRecord]
    @State private var picking = false
    @State private var note = ""
    @State private var metric: Metric = .weight

    enum Metric: String, CaseIterable, Identifiable {
        case weight, muscle, fat, score
        var id: String { rawValue }
        var label: String {
            switch self {
            case .weight: "체중"
            case .muscle: "골격근"
            case .fat: "체지방률"
            case .score: "점수"
            }
        }
        var unit: String {
            switch self {
            case .weight, .muscle: "kg"
            case .fat: "%"
            case .score: ""
            }
        }
        var color: Color {
            switch self {
            case .weight: WatchTint.distance
            case .muscle: Palette.strength
            case .fat: WatchTint.energy
            case .score: WatchTint.time
            }
        }
        func value(_ r: BodyRecord) -> Double? {
            switch self {
            case .weight: r.weight > 0 ? r.weight : nil
            case .muscle: r.skeletalMuscle
            case .fat: r.bodyFatPercent
            case .score: r.score
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if records.isEmpty { empty } else { latest; trend; history }
            }
            .padding(18).padding(.bottom, 40)
        }
        .background(Palette.bg)
        .navigationTitle("체성분")
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("인바디 CSV 가져오기", systemImage: "doc.text") { picking = true }
                    Button("건강 앱에서 가져오기", systemImage: "heart") { importHealth() }
                    Button("앱에 넣어둔 CSV", systemImage: "tray.and.arrow.down") { importBundled() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.strength)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $picking,
                      allowedContentTypes: [.commaSeparatedText, .plainText, .data]) { res in
            handle(res)
        }
        .overlay(alignment: .bottom) {
            if !note.isEmpty {
                Text(note).font(.rounded(13, .semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Palette.card, in: .capsule)
                    .foregroundStyle(.white).padding(.bottom, 30)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.stand").font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Palette.dimmer)
            Text("체성분 기록이 없습니다").font(.rounded(16, .semibold)).foregroundStyle(Palette.dim)
            Text("우측 상단에서 인바디 CSV 또는 건강 앱에서 가져오세요")
                .font(.rounded(12, .medium)).foregroundStyle(Palette.dimmer)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 90)
    }

    // MARK: - 최신

    @ViewBuilder
    private var latest: some View {
        if let r = records.first {
            CardBox {
                HStack {
                    Text(r.date.fullKorean).font(.rounded(16, .bold)).foregroundStyle(.white)
                    Spacer()
                    Text(r.source).font(.rounded(11, .semibold))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.white.opacity(0.1), in: .capsule)
                        .foregroundStyle(Palette.dim)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                    GridItem(.flexible())], spacing: 16) {
                    big("체중", r.weight, "kg", WatchTint.distance)
                    if let v = r.skeletalMuscle { big("골격근", v, "kg", Palette.strength) }
                    if let v = r.bodyFatPercent { big("체지방", v, "%", WatchTint.energy) }
                    if let v = r.bmi { big("BMI", v, "", Palette.dim) }
                    if let v = r.bmr { big("기초대사", v, "kcal", WatchTint.pace) }
                    if let v = r.score { big("점수", v, "", WatchTint.time) }
                }
                let extras: [(String, Double?, String)] = [
                    ("내장지방", r.visceralLevel, "레벨"), ("복부지방률", r.abdominalFatRatio, ""),
                    ("체수분", r.totalWater, "L"), ("단백질", r.protein, "kg"),
                    ("무기질", r.mineral, "kg"), ("체지방량", r.bodyFatMass, "kg")
                ].filter { $0.1 != nil }
                if !extras.isEmpty {
                    Divider().overlay(Palette.cardStroke)
                    ForEach(extras, id: \.0) { e in
                        HStack {
                            Text(e.0).font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                            Spacer()
                            Text("\(fmt(e.1!)) \(e.2)").font(.rounded(14, .bold))
                                .monospacedDigit().foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    private func big(_ l: String, _ v: Double, _ u: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: -1) {
            Text(l).font(.rounded(11, .bold)).foregroundStyle(c.opacity(0.8))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(fmt(v)).font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundStyle(c)
                if !u.isEmpty {
                    Text(u).font(.rounded(10, .bold)).foregroundStyle(c.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    // MARK: - 추이

    private var trend: some View {
        CardBox {
            PillPicker(items: Metric.allCases, selection: $metric,
                       title: \.label, tint: { $0.color })
            let pts = records.compactMap { r -> (Date, Double)? in
                metric.value(r).map { (r.date, $0) }
            }.sorted { $0.0 < $1.0 }
            if pts.count > 1 {
                Chart(pts, id: \.0) { p in
                    LineMark(x: .value("날짜", p.0), y: .value(metric.label, p.1))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(metric.color)
                        .lineStyle(.init(lineWidth: 2.4, lineCap: .round))
                    PointMark(x: .value("날짜", p.0), y: .value(metric.label, p.1))
                        .foregroundStyle(metric.color).symbolSize(18)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks(position: .trailing) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel().foregroundStyle(Palette.dimmer)
                            .font(.rounded(10, .semibold))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel(format: .dateTime.year(.twoDigits).month())
                            .foregroundStyle(Palette.dimmer).font(.rounded(10, .semibold))
                    }
                }
                .frame(height: 200)
                if let f = pts.first, let l = pts.last {
                    let d = l.1 - f.1
                    HStack {
                        Text("\(pts.count)회 · \(f.0.monthDay) → \(l.0.monthDay)")
                            .font(.rounded(12, .medium)).foregroundStyle(Palette.dimmer)
                        Spacer()
                        Text("\(d >= 0 ? "+" : "")\(fmt(d)) \(metric.unit)")
                            .font(.rounded(14, .bold)).monospacedDigit()
                            .foregroundStyle(d >= 0 ? metric.color : WatchTint.distance)
                    }
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "측정 기록 \(records.count)회")
            ForEach(records) { r in
                HStack {
                    Text(r.date.monthDay).font(.rounded(13, .bold)).monospacedDigit()
                        .foregroundStyle(.white).frame(width: 48, alignment: .leading)
                    Text(String(r.date.formatted(.dateTime.year())))
                        .font(.rounded(11, .semibold)).foregroundStyle(Palette.dimmer)
                    Spacer()
                    Text("\(fmt(r.weight))kg").font(.rounded(14, .bold)).monospacedDigit()
                        .foregroundStyle(WatchTint.distance)
                    if let m = r.skeletalMuscle {
                        Text("\(fmt(m))").font(.rounded(14, .bold)).monospacedDigit()
                            .foregroundStyle(Palette.strength)
                    }
                    if let f = r.bodyFatPercent {
                        Text("\(fmt(f))%").font(.rounded(14, .bold)).monospacedDigit()
                            .foregroundStyle(WatchTint.energy)
                    }
                }
                .padding(12)
                .background(Palette.card, in: .rect(cornerRadius: 12))
                .contextMenu {
                    Button("삭제", systemImage: "trash", role: .destructive) { ctx.delete(r) }
                }
            }
        }
    }

    // MARK: - 가져오기

    private func handle(_ res: Result<URL, Error>) {
        guard case .success(let url) = res else { return }
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { flash("파일을 읽지 못했습니다"); return }
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .init(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)))) ?? ""
        let parsed = InBodyCSV.parse(text)
        guard !parsed.isEmpty else { flash("인식된 측정이 없습니다"); return }
        let have = Set(records.map(\.key))
        var n = 0
        for r in parsed where !have.contains(r.key) { ctx.insert(r); n += 1 }
        flash(n > 0 ? "\(n)건 가져왔습니다" : "이미 모두 있습니다")
    }

    /// 앱 Documents 에 들어있는 CSV 를 전부 읽는다 (맥에서 밀어넣은 것)
    private func importBundled() {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
              let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { flash("Documents 를 읽지 못했습니다"); return }
        let csvs = files.filter { $0.pathExtension.lowercased() == "csv" }
        guard !csvs.isEmpty else { flash("앱 안에 CSV 가 없습니다"); return }
        var n = 0
        let have = Set(records.map(\.key))
        var seen = have
        for f in csvs {
            guard let d = try? Data(contentsOf: f) else { continue }
            let text = String(data: d, encoding: .utf8) ?? ""
            for r in InBodyCSV.parse(text) where !seen.contains(r.key) {
                ctx.insert(r); seen.insert(r.key); n += 1
            }
        }
        flash(n > 0 ? "\(n)건 가져왔습니다" : "이미 모두 있습니다")
    }

    /// 건강 앱의 체성분을 전부 읽어 같은 시각끼리 묶는다.
    private func importHealth() {
        let store = HKHealthStore()
        let want: [(HKQuantityTypeIdentifier, HKUnit, String)] = [
            (.bodyMass,           .gramUnit(with: .kilo), "weight"),
            (.bodyFatPercentage,  .percent(),             "fat"),
            (.leanBodyMass,       .gramUnit(with: .kilo), "lean"),
            (.bodyMassIndex,      .count(),               "bmi")
        ]
        let types = Set(want.map { HKQuantityType($0.0) as HKObjectType })
        store.requestAuthorization(toShare: [], read: types) { ok, _ in
            guard ok else { DispatchQueue.main.async { flash("건강 권한이 필요합니다") }; return }
            var buckets: [Int: [String: (Double, Date, String)]] = [:]   // 분 단위 키
            let group = DispatchGroup()
            for (id, unit, name) in want {
                group.enter()
                let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                let q = HKSampleQuery(sampleType: HKQuantityType(id), predicate: nil,
                                      limit: 500, sortDescriptors: [sort]) { _, samples, _ in
                    let ss = (samples as? [HKQuantitySample]) ?? []
                    DispatchQueue.main.async {
                        for x in ss {
                            let k = Int(x.startDate.timeIntervalSince1970 / 60)
                            var b = buckets[k] ?? [:]
                            b[name] = (x.quantity.doubleValue(for: unit), x.startDate,
                                       x.sourceRevision.source.name)
                            buckets[k] = b
                        }
                        group.leave()
                    }
                }
                store.execute(q)
            }
            group.notify(queue: .main) {
                let have = Set(records.map(\.key))
                var n = 0
                var sources = Set<String>()
                for (k, b) in buckets {
                    let key = "HK-\(k)"
                    guard !have.contains(key) else { continue }
                    guard let anchor = b["weight"] ?? b["fat"] ?? b["lean"] ?? b["bmi"] else { continue }
                    let r = BodyRecord(date: anchor.1, source: anchor.2, key: key)
                    r.weight = b["weight"]?.0 ?? 0
                    if let f = b["fat"]?.0 { r.bodyFatPercent = f * 100 }
                    if let l = b["lean"]?.0 {
                        r.skeletalMuscle = l
                        if r.weight > 0 { r.bodyFatMass = r.weight - l }
                    }
                    r.bmi = b["bmi"]?.0
                    sources.insert(anchor.2)
                    ctx.insert(r); n += 1
                }
                if buckets.isEmpty { flash("건강 앱에 체성분 데이터가 없습니다") }
                else if n == 0 { flash("이미 모두 있음 · 출처: \(sources.sorted().joined(separator: ", "))") }
                else { flash("\(n)건 · 출처: \(sources.sorted().joined(separator: ", "))") }
            }
        }
    }

    private func flash(_ s: String) {
        note = s
        Task { try? await Task.sleep(for: .seconds(2.5)); note = "" }
    }
}
