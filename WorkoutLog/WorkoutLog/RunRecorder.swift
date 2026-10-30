import Foundation
import Observation

/// 아이폰 쪽 수집(GPS·모션)을 화면 수명과 분리한다.
/// 워치에서 시작해도, 아이폰 세션 화면을 안 열어도 러닝 내내 기록된다.
@Observable
final class RunRecorder {
    static let shared = RunRecorder()

    private(set) var gps = LocationTracker()
    private(set) var motion = MotionTracker()
    private(set) var running = false
    private(set) var startedAt: Date?

    private init() {}

    /// 같은 시작 시각으로 중복 호출되면 무시한다.
    func begin(at date: Date) {
        if running, let s = startedAt, abs(s.timeIntervalSince(date)) < 1 { return }
        if running { end() }
        gps = LocationTracker()
        motion = MotionTracker()
        startedAt = date
        running = true
        gps.begin(at: date)
        motion.begin(at: date)
    }

    func end() {
        guard running else { return }
        gps.end()
        motion.end()
        running = false
    }

    /// 저장 후 초기화
    func reset() {
        end()
        gps = LocationTracker()
        motion = MotionTracker()
        startedAt = nil
    }
}
