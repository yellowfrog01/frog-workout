import SwiftUI
import SwiftData
import Charts

struct VitalsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Vital.date, order: .reverse) private var vitals: [Vital]
    @State private var note = ""
    @State private var busy = false

    private var byKind: [VitalKind: [Vital]] {
        Dictionary(grouping: vitals, by: \.kind)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if vitals.isEmpty { empty }
                ForEach(VitalKind.allCases) { k in
                    if let list = byKind[k], !list.isEmpty { card(k, list) }
                }
            }
            .padding(18).padding(.bottom, 40)
        }
        .background(Palette.bg)
        .navigationTitle("지표")
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { load() } label: {
                    if busy { ProgressView().tint(Palette.strength) }
                    else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Palette.strength)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottom) {
            if !note.isEmpty {
                Text(note).font(.rounded(12, .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Palette.card, in: .capsule)
                    .foregroundStyle(.white).padding(.bottom, 30)
                    .multilineTextAlignment(.center)
            }
        }
        .task { if vitals.isEmpty { load() } }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 40, weight: .semibold)).foregroundStyle(Palette.dimmer)
            Text("건강 앱에서 지표를 가져오세요")
                .font(.rounded(15, .semibold)).foregroundStyle(Palette.dim)
            Text("심폐 체력(VO₂max) · 안정시 심박 · HRV · 심박 회복\n호흡수 · 혈중 산소 · 손목 온도")
                .font(.rounded(12, .medium)).foregroundStyle(Palette.dimmer)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }

    private func color(_ k: VitalKind) -> Color {
        switch k {
        case .vo2Max:      WatchTint.pace
        case .restingHR, .hrRecovery, .walkingHR: WatchTint.heart
        case .hrv:         WatchTint.distance
        case .respiratory: Palette.strength
        case .oxygen:      WatchTint.time
        case .wristTemp:   WatchTint.energy
        }
    }

    private func card(_ k: VitalKind, _ list: [Vital]) -> some View {
        let sorted = list.sorted { $0.date < $1.date }
        let c = color(k)
        let latest = sorted.last!
        let first = sorted.first!
        let delta = latest.value - first.value
        let good = k.higherIsBetter ? delta >= 0 : delta <= 0
        return CardBox {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: -1) {
                    Text(k.label).font(.rounded(12, .bold)).foregroundStyle(c.opacity(0.85))
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(fmt(latest.value, k))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit().foregroundStyle(c)
                        Text(k.unit).font(.rounded(11, .bold)).foregroundStyle(c.opacity(0.6))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(sorted.count)건").font(.rounded(11, .semibold))
                        .foregroundStyle(Palette.dimmer)
                    if sorted.count > 1 {
                        Text("\(delta >= 0 ? "+" : "")\(fmt(delta, k))")
                            .font(.rounded(13, .bold)).monospacedDigit()
                            .foregroundStyle(good ? Palette.strength : WatchTint.energy)
                    }
                    Text(latest.date.monthDay).font(.rounded(10, .semibold))
                        .foregroundStyle(Palette.dimmer)
                }
            }
            if sorted.count > 1 {
                Chart(sorted) { v in
                    LineMark(x: .value("날짜", v.date), y: .value(k.label, v.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(c).lineStyle(.init(lineWidth: 2, lineCap: .round))
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.07))
                        AxisValueLabel().foregroundStyle(Palette.dimmer).font(.rounded(9, .semibold))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                            .foregroundStyle(Palette.dimmer).font(.rounded(9, .semibold))
                    }
                }
                .frame(height: 90)
            }
        }
    }

    private func fmt(_ v: Double, _ k: VitalKind) -> String {
        switch k {
        case .vo2Max, .wristTemp, .hrv: String(format: "%.1f", v)
        case .oxygen: String(format: "%.0f", v)
        default: String(Int(v.rounded()))
        }
    }

    private func load() {
        busy = true
        let have = Set(vitals.map(\.key))
        VitalsImporter.importAll(existing: have, insert: { ctx.insert($0) }) { n, kinds in
            busy = false
            note = kinds.isEmpty
                ? "건강 앱에 지표가 없습니다"
                : "\(n)건 추가 · " + kinds.joined(separator: ", ")
            Task { try? await Task.sleep(for: .seconds(4)); note = "" }
        }
    }
}
