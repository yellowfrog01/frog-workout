import SwiftUI

/// 운동 탭 목록에서 작성 중·진행 중인 근력 운동을 기록 행(SessionRow)과 같은 모양으로 보여준다.
/// 저장되면 이 자리에 실제 기록이 들어간다.
/// - 작성 중: 점선 테두리·회색, 시간 없음
/// - 진행 중: 근력 색 테두리, 경과 시간·휴식이 초 단위로 흐름
struct DraftSessionRow: View {
    let draft: StrengthDraft
    private var live: Bool { draft.start != nil }
    private var tint: Color { live ? Palette.strength : Palette.dim }
    private var day: Date { Session.logicalDay(for: draft.start ?? draft.updatedAt) }

    /// 진행 중이면 완료한 세트만, 작성 중이면 계획 전체 볼륨
    private var volume: Double {
        draft.lifts.reduce(0) { sum, l in
            let reps = live ? Array(l.repsList.prefix(l.done)) : l.repsList
            let load = reps.enumerated().reduce(0.0) { $0 + l.weightAt($1.offset) * Double($1.element) }
            return sum + load * (l.isUnilateral ? 2 : 1)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 2) {
                Text(day.monthDay)
                    .font(.rounded(15, .bold)).monospacedDigit()
                    .foregroundStyle(.white)
                Text(day.weekdayShort)
                    .font(.rounded(11, .semibold))
                    .foregroundStyle(Palette.dimmer)
            }
            .frame(width: 46)

            // 진행 중은 실선, 작성 중은 점선
            Group {
                if live {
                    Rectangle().fill(tint.opacity(0.8))
                } else {
                    Rectangle().stroke(style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                        .foregroundStyle(tint.opacity(0.6))
                }
            }
            .frame(width: 2)

            VStack(alignment: .leading, spacing: 7) {
                header
                if let re = draft.restEnd, live { restLine(re) }
                if draft.lifts.isEmpty {
                    Text("종목 없음")
                        .font(.rounded(13, .medium)).foregroundStyle(Palette.dimmer)
                }
                ForEach(draft.lifts) { l in
                    HStack(spacing: 6) {
                        LiftNameLine(lift: l, size: 13, weight: .medium, color: Palette.dim)
                        Spacer(minLength: 4)
                        Text("\(l.weightLabel) \(l.repsLabel)")
                            .font(.rounded(13, .semibold)).monospacedDigit()
                            .foregroundStyle(.white.opacity(0.75))
                        if live {
                            Text("\(l.done)/\(l.sets)")
                                .font(.rounded(11, .bold)).monospacedDigit()
                                .foregroundStyle(l.done >= l.sets && l.sets > 0 ? Palette.strength : Palette.dimmer)
                        }
                    }
                }
                if volume > 0 {
                    Text("\(live ? "현재" : "계획") \(Int(volume).formatted()) kg")
                        .font(.rounded(12, .bold)).monospacedDigit()
                        .foregroundStyle(tint.opacity(0.85))
                        .padding(.top, 1)
                }
            }
        }
        .padding(14)
        .background(live ? Palette.strength.opacity(0.06) : Palette.card, in: .rect(cornerRadius: 18))
        .overlay {
            if live {
                RoundedRectangle(cornerRadius: 18).stroke(Palette.strength.opacity(0.45), lineWidth: 1)
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(Color.white.opacity(0.22))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: WorkoutKind.strength.symbol)
                .font(.system(size: 11, weight: .bold))
            Text(WorkoutKind.strength.label)
                .font(.rounded(13, .bold))
            statusPill
            if let st = draft.start {
                Text(Self.hm(st))
                    .font(.rounded(11, .semibold)).monospacedDigit()
                    .foregroundStyle(Palette.dim)
                TimelineView(.periodic(from: .now, by: 1)) { t in
                    Text(max(0, Int(t.date.timeIntervalSince(st))).hmsString)
                        .font(.rounded(11, .semibold)).monospacedDigit()
                        .lineLimit(1).fixedSize()
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Palette.strength.opacity(0.18), in: .capsule)
                        .foregroundStyle(Palette.strength)
                }
            } else {
                Text("\(Self.hm(draft.updatedAt)) 수정")
                    .font(.rounded(11, .semibold)).monospacedDigit()
                    .foregroundStyle(Palette.dimmer)
            }
            Spacer(minLength: 0)
            if let c = draft.condition {
                Image(systemName: c.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.condition(c))
            }
        }
        .foregroundStyle(tint)
    }

    /// 남은 휴식 (끝나면 주황 "휴식 끝")
    private func restLine(_ re: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { t in
            let left = Int(re.timeIntervalSince(t.date).rounded(.up))
            Label(left > 0 ? "휴식 \(left.clockString)" : "휴식 끝", systemImage: "timer")
                .font(.rounded(12, .bold)).monospacedDigit()
                .foregroundStyle(left > 0 ? .white : .orange)
        }
    }

    private static func hm(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    private var statusPill: some View {
        HStack(spacing: 4) {
            if live { Circle().fill(Palette.strength).frame(width: 5, height: 5) }
            Text(live ? "진행 중" : "작성 중")
        }
        .font(.rounded(10, .bold))
        .padding(.horizontal, 6).padding(.vertical, 2)
        .foregroundStyle(live ? .black : Palette.dim)
        .background {
            if live {
                Capsule().fill(Palette.strength)
            } else {
                Capsule().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .foregroundStyle(Palette.dim)
            }
        }
    }
}
