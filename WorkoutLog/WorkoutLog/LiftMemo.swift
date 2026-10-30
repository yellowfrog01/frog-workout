import SwiftUI

// MARK: - 종목 메모

/// 운동 중 남기는 종목 메모 ("삼두에 힘 더 주기"). 어느 세트 시점에 쓴 건지 같이 남긴다.
struct LiftMemo: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    /// 쓴 시점까지 끝낸 세트 수. 0 이면 시작 전
    var afterSet: Int
    var at: Date = .now

    var setLabel: String { afterSet == 0 ? "시작 전" : "\(afterSet)세트" }
}

extension LiftEntry {
    /// memoData(JSON 문자열)에 담는다 — 기존 기록 구조를 건드리지 않으려고 문자열 한 칸만 쓴다
    var memos: [LiftMemo] {
        get {
            guard let s = memoData, let d = s.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([LiftMemo].self, from: d)) ?? []
        }
        set {
            guard !newValue.isEmpty, let d = try? JSONEncoder().encode(newValue) else { memoData = nil; return }
            memoData = String(data: d, encoding: .utf8)
        }
    }
}

/// 메모 목록. 마커: 날짜 · 종목 · 세트
struct LiftMemoLines: View {
    let memos: [LiftMemo]
    let liftName: String
    var onDelete: ((LiftMemo) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(memos) { m in
                let day = Session.logicalDay(for: m.at)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.strength.opacity(0.8))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(day.monthDay)(\(day.weekdayShort)) · \(liftName) · \(m.setLabel)")
                            .font(.rounded(11, .semibold)).monospacedDigit()
                            .foregroundStyle(Palette.dimmer)
                        Text(m.text)
                            .font(.rounded(13, .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
                .contextMenu {
                    if let onDelete {
                        Button("메모 삭제", systemImage: "trash", role: .destructive) { onDelete(m) }
                    }
                }
            }
        }
        .padding(.horizontal, 6)
    }
}
