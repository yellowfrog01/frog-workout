import Foundation
import ActivityKit

/// 잠금화면 상황판에 들어가는 값. 앱과 위젯이 공유한다.
struct RunActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startedAt: Date
        var bpm: Int
        var distanceKm: Double
        var paceSeconds: Int      // 초/km, 0 이면 미정
        var kcal: Int
        var watchLive: Bool
    }
    var mode: String              // "인터벌" / "일반"
}
