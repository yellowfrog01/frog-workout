import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject var m: WatchWorkoutManager
    @State private var outdoor = true

    var body: some View {
        NavigationStack {
            if m.running { live } else { idle }
        }
        .onAppear { m.prepare() }
    }

    // MARK: - 시작 전

    private var idle: some View {
        ScrollView {
            VStack(spacing: 10) {
                Toggle(isOn: $outdoor) {
                    Text(outdoor ? "야외" : "실내")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .tint(.green)

                Button {
                    m.start(outdoor: outdoor)
                } label: {
                    Label("러닝 시작", systemImage: "figure.run")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)
                .disabled(!m.authorized)

                if !m.message.isEmpty {
                    Text(m.message)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                } else if !m.authorized {
                    Text("건강 권한 요청 중…")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("운동로그")
    }

    // MARK: - 운동 중

    private var live: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let s = m.startedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(hms(max(0, Int(ctx.date.timeIntervalSince(s)))))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color(red: 0.85, green: 0.98, blue: 0.20))
                    }
                }
                metric("심박수", m.heartRate > 0 ? "\(m.heartRate)" : "--", "BPM",
                       Color(red: 1.0, green: 0.22, blue: 0.37))
                metric("활동 칼로리", "\(m.activeKcal)", "KCAL",
                       Color(red: 0.98, green: 0.25, blue: 0.35))
                metric("거리", String(format: "%.2f", m.distanceMeters / 1000), "KM",
                       Color(red: 0.20, green: 0.82, blue: 0.94))

                Button(role: .destructive) { m.stop() } label: {
                    Label("종료", systemImage: "stop.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("러닝 중")
    }

    private func metric(_ label: String, _ value: String, _ unit: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: -1) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(c.opacity(0.85))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(c)
                Text(unit)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(c.opacity(0.6))
            }
        }
    }

    private func hms(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec)
                     : String(format: "%d:%02d", m, sec)
    }
}
