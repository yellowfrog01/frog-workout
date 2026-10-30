import SwiftUI

// MARK: - 종목별 소요 시간 (세트 체크 시각 기준)

enum LiftTiming {
    /// 종목별 소요 시간(초).
    /// 구간 = 웜업 시작(있으면) 또는 이 종목 첫 세트 직전의 체크(다른 종목 포함, 없으면 운동 시작) ~ 이 종목 마지막 세트 체크.
    /// 웜업 시작이 있으면 그 앞의 종목 간 휴식은 빠진다.
    /// 그래서 첫 세트 수행 시간과 세트 사이 휴식이 포함되고, 마지막 세트 뒤 휴식은 다음 종목으로 넘어간다.
    /// 세트 체크 기록이 없는 종목은 빠진다.
    static func durations(_ lifts: [LiftEntry], start: Date?) -> [UUID: Int] {
        let all = lifts.flatMap { $0.doneAt ?? [] }.sorted()
        let t0 = start?.timeIntervalSince1970
        var out: [UUID: Int] = [:]
        for l in lifts {
            guard let ts = l.doneAt, let first = ts.min(), let last = ts.max() else { continue }
            let prev = l.warmupAt ?? all.last(where: { $0 < first }) ?? t0
            guard let from = prev, last >= from else { continue }
            out[l.id] = Int(last - from)
        }
        return out
    }
}

extension LiftTiming {
    /// 종목 간 휴식(초), 뒤 종목 id 기준.
    /// = 이 종목 시작(웜업 시작, 없으면 첫 세트 체크) − 그 직전에 끝난 다른 종목의 마지막 세트 체크.
    static func transitions(_ lifts: [LiftEntry]) -> [UUID: Int] {
        var out: [UUID: Int] = [:]
        for l in lifts {
            guard let s = l.warmupAt ?? l.doneAt?.min() else { continue }
            let prevEnd = lifts.filter { $0.id != l.id }
                .compactMap { $0.doneAt?.filter { $0 < s }.max() }.max()
            guard let p = prevEnd, s > p else { continue }
            out[l.id] = Int(s - p)
        }
        return out
    }
}

/// 종목 사이에 넣는 "종목 간 휴식 3:12" 한 줄
struct TransitionGapLine: View {
    let seconds: Int

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(Palette.cardStroke).frame(height: 1)
            Label("종목 간 휴식 \(seconds.hmsString)", systemImage: "pause.circle")
                .font(.rounded(11, .semibold)).monospacedDigit()
                .foregroundStyle(Palette.dimmer)
                .fixedSize()
            Rectangle().fill(Palette.cardStroke).frame(height: 1)
        }
    }
}

/// "⏱ 12:05" 한 줄
struct LiftDurationLabel: View {
    let seconds: Int
    var size: CGFloat = 12

    var body: some View {
        Label(seconds.hmsString, systemImage: "stopwatch")
            .font(.rounded(size, .semibold)).monospacedDigit()
            .foregroundStyle(Palette.dim)
            .labelStyle(.titleAndIcon)
    }
}
