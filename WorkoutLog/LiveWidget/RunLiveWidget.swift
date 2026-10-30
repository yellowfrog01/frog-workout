import SwiftUI
import WidgetKit
import ActivityKit

@main
struct LiveWidgetBundle: WidgetBundle {
    var body: some Widget {
        RunLiveWidget()
        StrengthLiveWidget()
    }
}

private let lime  = Color(red: 0.85, green: 0.98, blue: 0.20)
private let pink  = Color(red: 0.98, green: 0.07, blue: 0.31)
private let cyan  = Color(red: 0.20, green: 0.82, blue: 0.94)
private let heart = Color(red: 1.00, green: 0.22, blue: 0.37)

struct RunLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { ctx in
            lockScreen(ctx.state, mode: ctx.attributes.mode)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(lime)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    metric("심박", ctx.state.bpm > 0 ? "\(ctx.state.bpm)" : "--", "BPM", heart)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    metric("거리", String(format: "%.2f", ctx.state.distanceKm), "KM", cyan)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(ctx.state.startedAt, style: .timer)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit().foregroundStyle(lime)
                        Spacer()
                        Text(paceText(ctx.state.paceSeconds))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.run").foregroundStyle(pink)
            } compactTrailing: {
                Text(ctx.state.startedAt, style: .timer)
                    .monospacedDigit().frame(width: 44).foregroundStyle(lime)
            } minimal: {
                Image(systemName: "figure.run").foregroundStyle(pink)
            }
        }
    }

    private func lockScreen(_ s: RunActivityAttributes.ContentState, mode: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "figure.run")
                    .font(.system(size: 12, weight: .bold))
                Text("\(mode) 러닝")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
                if s.watchLive {
                    Image(systemName: "applewatch.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(lime)
                }
            }
            .foregroundStyle(pink)

            Text(s.startedAt, style: .timer)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(lime)

            HStack(spacing: 0) {
                metric("심박", s.bpm > 0 ? "\(s.bpm)" : "--", "BPM", heart)
                Spacer()
                metric("거리", String(format: "%.2f", s.distanceKm), "KM", cyan)
                Spacer()
                metric("페이스", paceText(s.paceSeconds), "/KM", lime)
                Spacer()
                metric("칼로리", "\(s.kcal)", "KCAL", pink)
            }
        }
        .padding(16)
    }

    private func metric(_ l: String, _ v: String, _ u: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: -1) {
            Text(l).font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(c.opacity(0.8))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(v).font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundStyle(c)
                Text(u).font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(c.opacity(0.6))
            }
        }
    }

    private func paceText(_ s: Int) -> String {
        s <= 0 ? "--:--" : String(format: "%d:%02d", s / 60, s % 60)
    }
}
