import Foundation
import CoreLocation
import HealthKit
import Observation

// MARK: - 저장용 값 타입

struct RoutePoint: Codable, Hashable {
    var lat: Double
    var lon: Double
    var t: Double            // 시작 후 경과 초
    var coord: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
}

struct HRPoint: Codable, Hashable, Identifiable {
    var bpm: Double
    var t: Double            // 시작 후 경과 초
    var id: Double { t }
}

// MARK: - GPS 경로 추적 (아이폰 단독. 애플워치 불필요)

@Observable
final class LocationTracker: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var start: Date?
    private var last: CLLocation?

    var points: [RoutePoint] = []
    var distanceMeters: Double = 0
    var authorized = false
    var denied = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = 5
    }

    func begin(at date: Date) {
        start = date
        manager.requestWhenInUseAuthorization()
        // 화면이 꺼져도 경로가 끊기지 않게
        if manager.authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
        }
        manager.startUpdatingLocation()
    }

    func end() { manager.stopUpdatingLocation() }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        switch m.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            authorized = true; denied = false
            m.startUpdatingLocation()
        case .denied, .restricted:
            authorized = false; denied = true
        default:
            authorized = false; denied = false
        }
    }

    /// 사람이 낼 수 없는 속도(m/s). 넘으면 GPS 점프로 보고 거리에서 제외한다.
    private let maxSpeed: Double = 12.0   // 43km/h

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let start else { return }
        for loc in locs {
            // 정확도 낮은 샘플은 버린다
            guard loc.horizontalAccuracy > 0, loc.horizontalAccuracy < 50 else { continue }

            if let last {
                let d = loc.distance(from: last)
                let dt = loc.timestamp.timeIntervalSince(last.timestamp)
                if dt > 0, d / dt > maxSpeed {
                    // 순간이동(시뮬레이터 워프·GPS 튐). 경로를 끊고 새로 시작한다.
                    self.last = loc
                    points.removeAll()
                    distanceMeters = 0
                    points.append(point(loc, start))
                    continue
                }
                if d > 1 { distanceMeters += d }   // 정지 중 드리프트 무시
            }
            last = loc
            points.append(point(loc, start))
        }
    }

    private func point(_ loc: CLLocation, _ start: Date) -> RoutePoint {
        RoutePoint(lat: loc.coordinate.latitude,
                   lon: loc.coordinate.longitude,
                   t: loc.timestamp.timeIntervalSince(start))
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) { }
}

// MARK: - 실시간 심박수 (HealthKit)

@Observable
final class HeartRateMonitor {
    private let store = HKHealthStore()
    private var query: HKAnchoredObjectQuery?
    private var start: Date?

    var current: Int = 0
    var samples: [HRPoint] = []
    var available = HKHealthStore.isHealthDataAvailable()
    var authorized = false
    var note: String = ""

    private let unit = HKUnit.count().unitDivided(by: .minute())

    var average: Int {
        guard !samples.isEmpty else { return 0 }
        return Int(samples.map(\.bpm).reduce(0, +) / Double(samples.count))
    }
    var peak: Int { Int(samples.map(\.bpm).max() ?? 0) }

    func begin(at date: Date) {
        guard available else { note = "이 기기는 건강 데이터를 지원하지 않습니다"; return }
        start = date
        let type = HKQuantityType(.heartRate)
        store.requestAuthorization(toShare: [], read: [type]) { [weak self] ok, _ in
            guard let self else { return }
            Task { @MainActor in
                self.authorized = ok
                if ok { self.run(type: type, from: date) }
                else { self.note = "건강 접근 권한이 필요합니다" }
            }
        }
    }

    private func run(type: HKQuantityType, from date: Date) {
        let pred = HKQuery.predicateForSamples(withStart: date, end: nil, options: .strictStartDate)
        let handler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = {
            [weak self] _, new, _, _, _ in
            guard let self, let new = new as? [HKQuantitySample], !new.isEmpty else { return }
            Task { @MainActor in self.ingest(new) }
        }
        let q = HKAnchoredObjectQuery(type: type, predicate: pred, anchor: nil,
                                      limit: HKObjectQueryNoLimit, resultsHandler: handler)
        q.updateHandler = handler
        query = q
        store.execute(q)
    }

    @MainActor
    private func ingest(_ new: [HKQuantitySample]) {
        guard let start else { return }
        for s in new.sorted(by: { $0.startDate < $1.startDate }) {
            let bpm = s.quantity.doubleValue(for: unit)
            samples.append(HRPoint(bpm: bpm, t: s.startDate.timeIntervalSince(start)))
            current = Int(bpm)
        }
        if note.isEmpty == false { note = "" }
    }

    func end() {
        if let query { store.stop(query) }
        query = nil
    }
}
