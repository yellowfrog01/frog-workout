import Foundation
import SwiftData
import Observation

/// 작성 중인 근력 운동 (준비 중이거나 진행 중).
/// 화면을 나가도, 앱이 재설치·재실행돼도 이어서 할 수 있게 UserDefaults 에 둔다.
struct StrengthDraft: Codable {
    var lifts: [LiftEntry] = []
    var condition: Condition?
    /// "운동 시작"을 누른 시각. nil 이면 준비 중
    var start: Date?
    /// 계획에서 시작했으면 그 계획 (저장 시 소진 처리)
    var planID: PersistentIdentifier?
    /// 진행 중인 휴식 (나갔다 와도 이어서 센다)
    var restEnd: Date?
    var restTotal: Int?
    var restNext: String?
    /// 지금 휴식이 어느 종목 세트 뒤인지 (휴식 조정이 그 종목 목표 휴식을 바꾼다)
    var restLiftID: UUID?
    /// 이미 저장된 기록을 다시 연 경우 그 기록 (완료 시 새로 만들지 않고 덮어쓴다)
    var resumeID: PersistentIdentifier?
    var updatedAt: Date = .now
}

@Observable
final class StrengthDraftStore {
    static let shared = StrengthDraftStore()
    private static let key = "strength.draft"

    private(set) var draft: StrengthDraft?
    /// 앱 화면 밖(잠금화면 버튼)에서 초안을 바꿨을 때 올린다. 열린 운동 화면이 다시 읽는다.
    var externalRevision = 0

    private init() {
        if let d = UserDefaults.standard.data(forKey: Self.key) {
            draft = try? JSONDecoder().decode(StrengthDraft.self, from: d)
        }
    }

    func save(_ d: StrengthDraft) {
        var d = d
        d.updatedAt = .now
        draft = d
        if let data = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
        StrengthLive.sync(d)
    }

    func clear() {
        draft = nil
        UserDefaults.standard.removeObject(forKey: Self.key)
        StrengthLive.end()
    }
}
