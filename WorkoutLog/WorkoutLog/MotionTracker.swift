import Foundation
import CoreMotion
import CoreLocation
import Observation

/// 아이폰이 단독으로 모을 수 있는 지표 — 케이던스·걸음·고도.
/// 워치 없이도 동작한다.
@Observable
final class MotionTracker {
    private let pedometer = CMPedometer()
    private let altimeter = CMAltimeter()
    private var start: Date?

    var steps: Int = 0
    var cadenceSPM: Double = 0          // 분당 걸음
    var pedometerDistance: Double = 0   // m
    var floorsUp: Int = 0
    var relativeAltitude: Double = 0    // m, 시작점 대비

    var cadenceSeries: [MetricPoint] = []
    var altitudeSeries: [MetricPoint] = []

    var available = CMPedometer.isStepCountingAvailable()
    var altimeterAvailable = CMAltimeter.isRelativeAltitudeAvailable()

    func begin(at date: Date) {
        start = date
        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: date) { [weak self] data, _ in
                guard let self, let d = data else { return }
                Task { @MainActor in
                    self.steps = d.numberOfSteps.intValue
                    if let dist = d.distance { self.pedometerDistance = dist.doubleValue }
                    if let c = d.currentCadence {
                        self.cadenceSPM = c.doubleValue * 60
                        self.push(&self.cadenceSeries, self.cadenceSPM)
                    }
                    if let f = d.floorsAscended { self.floorsUp = f.intValue }
                }
            }
        }
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let self, let d = data else { return }
                self.relativeAltitude = d.relativeAltitude.doubleValue
                self.push(&self.altitudeSeries, self.relativeAltitude, allowZero: true)
            }
        }
    }

    func end() {
        pedometer.stopUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }

    private func push(_ arr: inout [MetricPoint], _ v: Double, allowZero: Bool = false) {
        guard let s = start, v.isFinite, allowZero || v > 0 else { return }
        arr.append(MetricPoint(t: Date().timeIntervalSince(s), v: v))
    }
}

// MARK: - 경로에서 파생 지표 계산

enum RouteAnalysis {
    /// 1km 단위 스플릿.
    /// GPS 가 일부 구간만 잡혔으면(워치 거리와 차이가 크면) 스플릿을 만들지 않는다 —
    /// 잘못된 페이스를 보여주는 것보다 비우는 편이 낫다.
    static func splits(route: [RoutePoint], hr: [MetricPoint],
                       totalMeters: Double = 0, every meters: Double = 1000) -> [Split] {
        guard route.count > 1 else { return [] }
        if totalMeters > 0 {
            let covered = routeDistance(route)
            if covered < totalMeters * 0.8 { return [] }
        }
        var out: [Split] = []
        var acc = 0.0
        var segStartT = route[0].t
        var segStartIdx = 0
        var idx = 1

        for i in 1..<route.count {
            let a = CLLocation(latitude: route[i-1].lat, longitude: route[i-1].lon)
            let b = CLLocation(latitude: route[i].lat, longitude: route[i].lon)
            acc += b.distance(from: a)
            if acc >= meters {
                let segEndT = route[i].t
                out.append(Split(
                    index: idx,
                    seconds: Int(segEndT - segStartT),
                    meters: acc,
                    avgHR: avgHR(hr, from: segStartT, to: segEndT),
                    elevationDelta: 0
                ))
                idx += 1
                acc = 0
                segStartT = segEndT
                segStartIdx = i
            }
        }
        // 남은 구간
        if acc > 50, let last = route.last {
            out.append(Split(index: idx, seconds: Int(last.t - segStartT), meters: acc,
                             avgHR: avgHR(hr, from: segStartT, to: last.t), elevationDelta: 0))
        }
        _ = segStartIdx
        return out
    }

    static func routeDistance(_ route: [RoutePoint]) -> Double {
        guard route.count > 1 else { return 0 }
        var d = 0.0
        for i in 1..<route.count {
            d += CLLocation(latitude: route[i].lat, longitude: route[i].lon)
                .distance(from: CLLocation(latitude: route[i-1].lat, longitude: route[i-1].lon))
        }
        return d
    }

    private static func avgHR(_ hr: [MetricPoint], from: Double, to: Double) -> Int {
        let v = hr.filter { $0.t >= from && $0.t <= to }.map(\.v).filter { $0 > 0 }
        return v.isEmpty ? 0 : Int(v.reduce(0,+) / Double(v.count))
    }

    /// 고도 상승/하강 누적 (노이즈 제거용 임계 3m)
    static func elevation(_ series: [MetricPoint], threshold: Double = 3) -> (gain: Double, loss: Double) {
        guard series.count > 1 else { return (0, 0) }
        var gain = 0.0, loss = 0.0
        var ref = series[0].v
        for p in series.dropFirst() {
            let d = p.v - ref
            if d > threshold { gain += d; ref = p.v }
            else if d < -threshold { loss += -d; ref = p.v }
        }
        return (gain, loss)
    }
}
