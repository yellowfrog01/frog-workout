import SwiftUI
import SwiftData

// MARK: - 근력 준비 중 참고용 지난 기록

private func liftKey(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespaces).lowercased()
}

/// 종목 카드 아래 한 줄: 같은 종목의 가장 최근 기록
struct LiftLastLine: View {
    let name: String
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    private var last: (day: Date, lift: LiftEntry)? {
        let key = liftKey(name)
        guard !key.isEmpty else { return nil }
        for s in sessions where s.kind == .strength {
            if let l = s.lifts.first(where: { liftKey($0.name) == key }) { return (s.logicalDay, l) }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            lastLine
            // 지난번에 이 종목에 남긴 메모
            if let r = last, !r.lift.memos.isEmpty {
                LiftMemoLines(memos: r.lift.memos, liftName: r.lift.name)
            }
        }
    }

    private var lastLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
            if let r = last {
                Text("지난 \(r.day.monthDay)(\(r.day.weekdayShort))")
                Text(r.lift.weightText).foregroundStyle(Palette.strength.opacity(0.8))
                Text(r.lift.repsDetail).lineLimit(1).minimumScaleFactor(0.8)
                if let rir = r.lift.rir { Text("RIR \(rir)") }
            } else {
                Text("지난 기록 없음")
            }
            Spacer(minLength: 0)
        }
        .font(.rounded(12, .semibold)).monospacedDigit()
        .foregroundStyle(Palette.dim)
        .padding(.horizontal, 6)
    }
}

/// 최근 근력 세션 목록 — 준비 화면 아래에 바로 펼친다 (참고만, 수정 없음)
struct StrengthHistoryList: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    private var recent: [Session] {
        Array(sessions.filter { $0.kind == .strength && !$0.lifts.isEmpty }.prefix(10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "지난 근력 기록")
                .padding(.horizontal, 4)
            if recent.isEmpty {
                Text("근력 기록이 없습니다")
                    .font(.rounded(14, .semibold)).foregroundStyle(Palette.dim)
                    .padding(.horizontal, 4)
            }
            ForEach(recent) { s in card(s) }
        }
    }

    private func card(_ s: Session) -> some View {
        CardBox {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(s.logicalDay.monthDay) (\(s.logicalDay.weekdayShort))")
                    .font(.rounded(16, .bold)).monospacedDigit()
                    .foregroundStyle(.white)
                if let bp = s.bodyPart {
                    Text(bp.label).font(.rounded(13, .semibold)).foregroundStyle(Palette.strength)
                }
                Text(s.condition.label).font(.rounded(13, .semibold)).foregroundStyle(Palette.dim)
                Spacer(minLength: 6)
                if let d = s.durationSeconds {
                    Text("\(d / 60)분").font(.rounded(13, .semibold)).monospacedDigit()
                        .foregroundStyle(Palette.dim)
                }
                Text("\(Int(s.totalVolume).formatted())kg")
                    .font(.rounded(13, .semibold)).monospacedDigit()
                    .foregroundStyle(Palette.dim)
            }
            let times = LiftTiming.durations(s.lifts, start: s.startAt)
            ForEach(s.lifts) { l in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(l.name)
                        .font(.rounded(14, .semibold)).foregroundStyle(.white)
                        .lineLimit(1)
                    if let sec = times[l.id] { LiftDurationLabel(seconds: sec, size: 11) }
                    Spacer(minLength: 6)
                    Text(l.weightText)
                        .font(.rounded(14, .heavy)).monospacedDigit()
                        .foregroundStyle(Palette.strength)
                    Text(l.repsDetail)
                        .font(.rounded(13, .semibold)).monospacedDigit()
                        .foregroundStyle(Palette.dim)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if let rir = l.rir {
                        Text("RIR \(rir)").font(.rounded(12, .semibold))
                            .foregroundStyle(Palette.dimmer)
                    }
                }
                if !l.memos.isEmpty { LiftMemoLines(memos: l.memos, liftName: l.name) }
            }
        }
    }
}
