import SwiftUI

// MARK: - 종목 단계 (세트 / 종목 간 휴식 / 웜업)

/// 운동 진행 단계. 세트 사이 휴식(카운트다운)은 restEnd 로 따로 다룬다.
/// - 종목 간 휴식: 한 종목의 마지막 세트 뒤, 다음 종목 "시작"을 누르기 전 (경과 시간).
///   남은 종목이 없으면 next = nil (다음 운동을 추가하기 전)
/// - 웜업: "다음 운동 시작"을 누른 뒤 그 종목 첫 세트를 체크하기 전 (경과 시간)
enum LiftPhase: Equatable {
    case sets
    case transition(since: Date, next: Int?)
    case warmup(since: Date, lift: Int)
    case done
}

extension Array where Element == LiftEntry {
    var phase: LiftPhase {
        let lastSet = flatMap({ $0.doneAt ?? [] }).max().map { Date(timeIntervalSince1970: $0) }
        guard let i = firstIndex(where: { $0.done < $0.sets }) else {
            // 목록의 종목을 다 끝냄: 다음 운동을 추가할 때까지 종목 간 휴식
            if let t = lastSet { return .transition(since: t, next: nil) }
            return .done
        }
        let l = self[i]
        if l.done > 0 { return .sets }
        if let w = l.warmupAt { return .warmup(since: Date(timeIntervalSince1970: w), lift: i) }
        if let t = lastSet { return .transition(since: t, next: i) }
        return .sets
    }
}

/// 종목 간 휴식 바: 쉰 시간(증가) + 다음 운동 시작 버튼 (다음 종목이 없으면 추가 버튼)
struct TransitionBar: View {
    let since: Date
    let next: LiftEntry?
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("종목 간 휴식").font(.rounded(12, .bold)).foregroundStyle(Palette.dim)
                Text(since, style: .timer)
                    .font(.rounded(30, .heavy)).monospacedDigit().foregroundStyle(.white)
            }
            Spacer(minLength: 4)
            Button(action: { onStart(); Haptics.success() }) {
                VStack(alignment: .trailing, spacing: 1) {
                    if let next {
                        Text("다음 운동 시작").font(.rounded(15, .bold))
                        Text("\(next.name) \(next.weightText(at: next.done))").font(.rounded(11, .semibold)).lineLimit(1)
                            .opacity(0.7)
                    } else {
                        Label("다음 운동 추가", systemImage: "plus").font(.rounded(15, .bold))
                    }
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Palette.strength, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.cardStroke, lineWidth: 1))
    }
}

/// 웜업 바: 웜업 경과 시간. 첫 세트를 체크하면 사라진다.
struct WarmupBar: View {
    let since: Date
    let lift: LiftEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(lift.name) 웜업").font(.rounded(12, .bold)).foregroundStyle(Palette.dim)
                Text(since, style: .timer)
                    .font(.rounded(26, .heavy)).monospacedDigit().foregroundStyle(.white)
            }
            Spacer()
            Text("첫 세트를 체크하면 본 세트 시작")
                .font(.rounded(11, .semibold)).foregroundStyle(Palette.dimmer)
                .multilineTextAlignment(.trailing)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.cardStroke, lineWidth: 1))
    }
}
