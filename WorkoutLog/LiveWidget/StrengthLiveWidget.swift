import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

private let lime = Color(red: 0.69, green: 0.96, blue: 0.17)

/// 근력 운동 잠금화면: 다음 세트 · 휴식 카운트다운 · 세트 완료 버튼
struct StrengthLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StrengthActivityAttributes.self) { ctx in
            lockScreen(ctx.state, restOver: ctx.isStale)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(lime)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(ctx.state.lift.isEmpty ? "완료" : "\(ctx.state.lift) \(ctx.state.setNo)/\(ctx.state.sets)")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    restOrElapsed(ctx.state, restOver: ctx.isStale, size: 18)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if ctx.state.phase == "transition" {
                        Button(intent: StartNextLiftIntent()) { Label("다음 운동 시작", systemImage: "play.fill") }
                    } else if !ctx.state.lift.isEmpty {
                        Button(intent: CompleteSetIntent()) { setDots(ctx.state) }.buttonStyle(.plain)
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundStyle(lime)
            } compactTrailing: {
                restOrElapsed(ctx.state, restOver: ctx.isStale, size: 13).frame(width: 44)
            } minimal: {
                Image(systemName: "dumbbell.fill").foregroundStyle(lime)
            }
        }
    }

    /// restOver: 휴식 끝 시각이 지나 시스템이 다시 그린 상태 (staleDate)
    private func lockScreen(_ s: StrengthActivityAttributes.ContentState, restOver: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill").font(.system(size: 12, weight: .bold))
                Text("근력 운동 중").font(.system(size: 13, weight: .bold, design: .rounded))
                Text("\(s.doneSets)/\(s.totalSets)세트")
                    .font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Text(s.startedAt, style: .timer)
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(lime)

            HStack(alignment: .center, spacing: 12) {
                // 왼쪽: 종목·무게 + 세트 동그라미. 동그라미 줄을 누르면 다음 세트 완료 (앱 운동 화면과 같은 조작)
                VStack(alignment: .leading, spacing: 4) {
                    if s.lift.isEmpty && s.phase == "transition" {
                        Text("종목 완료")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("다음 운동은 앱에서 추가")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else if s.lift.isEmpty {
                        Text("모든 세트 완료")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    } else if s.phase == "transition" {
                        // 종목 간 휴식: 다음 종목 + 시작 버튼 (누르면 웜업 시작)
                        Text("다음: \(s.lift) \(s.weight)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Button(intent: StartNextLiftIntent()) {
                            Label("다음 운동 시작", systemImage: "play.fill")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(lime, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("\(s.lift) \(s.weight)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Button(intent: CompleteSetIntent()) { setDots(s) }
                            .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 4)
                // 오른쪽: 상태 (휴식 남은 시간 / 휴식 끝 / 세트 중)
                status(s, restOver: restOver)
            }
        }
        .padding(16)
        .foregroundStyle(.white)
    }

    /// 앱 운동 화면의 세트 동그라미와 같은 모양: 완료 = 채움, 다음 세트 = 테두리 강조, 숫자 = 그 세트 횟수
    private func setDots(_ s: StrengthActivityAttributes.ContentState) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(s.repsList.enumerated()), id: \.offset) { i, n in
                let done = i < s.liftDone
                let next = i == s.liftDone
                Text("\(n)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded)).monospacedDigit()
                    .foregroundStyle(done ? .black : .white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(done ? lime : .clear))
                    .overlay(Circle().strokeBorder(done ? lime : (next ? lime.opacity(0.9) : Color.white.opacity(0.25)),
                                                   lineWidth: next ? 2 : 1.5))
            }
        }
        .padding(.top, 2)
    }

    /// 오른쪽 상태 표시
    @ViewBuilder
    private func status(_ s: StrengthActivityAttributes.ContentState, restOver: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            if (s.phase == "transition" || s.phase == "warmup"), let t = s.phaseSince {
                Text(s.phase == "warmup" ? "웜업" : "종목 휴식")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(s.phase == "warmup" ? Color.orange : .secondary)
                Text(t, style: .timer)
                    .font(.system(size: 28, weight: .heavy, design: .rounded)).monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 92, alignment: .trailing)
            } else if s.lift.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .bold)).foregroundStyle(lime)
            } else if let end = s.restEnd, !(restOver || end <= .now) {
                Text("휴식").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(lime.opacity(0.8))
                Text(timerInterval: Date.now...end, countsDown: true)
                    .font(.system(size: 30, weight: .heavy, design: .rounded)).monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(lime)
                    .frame(width: 92, alignment: .trailing)
            } else if s.restEnd != nil {
                Image(systemName: "bell.fill").font(.system(size: 18, weight: .bold))
                Text("휴식 끝").font(.system(size: 16, weight: .heavy, design: .rounded))
            } else {
                Text("세트").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                Text("\(s.setNo)/\(s.sets)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded)).monospacedDigit()
            }
        }
        .foregroundStyle(s.restEnd != nil && (restOver || (s.restEnd ?? .now) <= .now) ? .orange : .white)
    }

    @ViewBuilder
    private func restOrElapsed(_ s: StrengthActivityAttributes.ContentState, restOver: Bool, size: CGFloat) -> some View {
        if let end = s.restEnd, restOver || end <= .now {
            Image(systemName: "bell.fill").foregroundStyle(.orange)
        } else if let end = s.restEnd {
            Text(timerInterval: Date.now...max(end, Date.now), countsDown: true)
                .font(.system(size: size, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(lime)
        } else {
            Text(s.startedAt, style: .timer)
                .font(.system(size: size, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}
