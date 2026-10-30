import Foundation
import ActivityKit
import AppIntents

/// 근력 운동 잠금화면 상황판에 들어가는 값. 앱과 위젯이 공유한다 (두 타깃에 같은 정의).
struct StrengthActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startedAt: Date
        /// 다음에 할 종목. 전부 끝났으면 ""
        var lift: String
        /// 다음 세트 번호 (1부터) / 그 종목 세트 수
        var setNo: Int
        var sets: Int
        /// "62.5kg × 5"
        var load: String
        /// 휴식 끝나는 시각. 휴식 중이 아니면 nil
        var restEnd: Date?
        var doneSets: Int
        var totalSets: Int
        /// 다음 종목의 세트별 횟수 · 그중 완료한 세트 수 (앱의 세트 동그라미와 같은 표시)
        var repsList: [Int] = []
        var liftDone: Int = 0
        /// "65kg" (맨몸이면 "BW +5kg")
        var weight: String = ""
        /// "set" / "transition"(종목 간 휴식) / "warmup" / "done"
        var phase: String = "set"
        /// 종목 간 휴식·웜업이 시작된 시각 (경과 시간 표시용)
        var phaseSince: Date? = nil
    }
}

/// 잠금화면 "다음 운동 시작" 버튼: 종목 간 휴식을 끝내고 다음 종목 웜업을 시작한다.
struct StartNextLiftIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "다음 운동 시작"
    nonisolated(unsafe) static var handler: (@MainActor () -> Void)?

    func perform() async throws -> some IntentResult {
        await MainActor.run { StartNextLiftIntent.handler?() }
        return .result()
    }
}

/// 잠금화면 "세트 완료" 버튼. LiveActivityIntent 라 앱 프로세스에서 실행된다.
/// 실제 처리는 앱이 handler 에 연결한다 (위젯 쪽 정의는 형식만 맞춘다).
struct CompleteSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "세트 완료"
    nonisolated(unsafe) static var handler: (@MainActor () -> Void)?

    func perform() async throws -> some IntentResult {
        await MainActor.run { CompleteSetIntent.handler?() }
        return .result()
    }
}
