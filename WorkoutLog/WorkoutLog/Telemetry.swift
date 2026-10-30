import Foundation

/// 시계열 한 점. t = 세션 시작 후 경과 초.
struct MetricPoint: Codable, Hashable, Identifiable {
    var t: Double
    var v: Double
    var id: Double { t }
}

/// 1km 구간 기록 (애플 피트니스의 "스플릿")
struct Split: Codable, Hashable, Identifiable {
    var index: Int          // 1, 2, 3...
    var seconds: Int        // 이 구간 소요 시간
    var meters: Double      // 보통 1000
    var avgHR: Int
    var elevationDelta: Double
    var id: Int { index }
    /// 초/km
    var pace: Int { meters > 0 ? Int(Double(seconds) * 1000 / meters) : 0 }
}

/// 세션에서 수집한 모든 지표.
/// 워치(HealthKit) + 아이폰(GPS·모션) 양쪽에서 채운다.
struct Telemetry: Codable, Hashable {
    // ── 시계열 (워치) ──
    var hr: [MetricPoint] = []                 // bpm
    var speed: [MetricPoint] = []              // m/s
    var power: [MetricPoint] = []              // W
    var strideLength: [MetricPoint] = []       // m
    var verticalOscillation: [MetricPoint] = []// cm
    var groundContactTime: [MetricPoint] = []  // ms

    // ── 시계열 (아이폰) ──
    var altitude: [MetricPoint] = []           // m
    var cadence: [MetricPoint] = []            // spm
    var gpsSpeed: [MetricPoint] = []           // m/s

    // ── 누적·요약 ──
    var activeKcal: Double = 0
    var basalKcal: Double = 0
    var steps: Int = 0
    var watchDistance: Double = 0              // m, 워치 측정
    var gpsDistance: Double = 0                // m, 아이폰 GPS
    var elevationGain: Double = 0
    var elevationLoss: Double = 0
    var splits: [Split] = []

    // ── 파생 ──
    var totalKcal: Double { activeKcal + basalKcal }
    var distance: Double { watchDistance > 0 ? watchDistance : gpsDistance }

    var avgHR: Int { avg(hr) }
    var maxHR: Int { Int(hr.map(\.v).max() ?? 0) }
    var minHR: Int { Int(hr.map(\.v).filter { $0 > 0 }.min() ?? 0) }
    var avgPower: Int { avg(power) }
    var avgCadence: Int { avg(cadence) }
    var avgStride: Double { avgD(strideLength) }
    var avgVertOsc: Double { avgD(verticalOscillation) }
    var avgGCT: Double { avgD(groundContactTime) }

    private func avg(_ a: [MetricPoint]) -> Int {
        let v = a.map(\.v).filter { $0 > 0 }
        return v.isEmpty ? 0 : Int(v.reduce(0,+) / Double(v.count))
    }
    private func avgD(_ a: [MetricPoint]) -> Double {
        let v = a.map(\.v).filter { $0 > 0 }
        return v.isEmpty ? 0 : v.reduce(0,+) / Double(v.count)
    }

    /// 심박 구간 (최대심박 추정치 대비 %). 각 구간에 머문 초.
    func hrZones(maxHR estMax: Int) -> [(zone: Int, label: String, seconds: Int)] {
        guard estMax > 0, hr.count > 1 else { return [] }
        var acc = [0, 0, 0, 0, 0]
        for i in 1..<hr.count {
            let dt = max(0, hr[i].t - hr[i-1].t)
            let pct = hr[i].v / Double(estMax)
            let z: Int
            switch pct {
            case ..<0.60: z = 0
            case ..<0.70: z = 1
            case ..<0.80: z = 2
            case ..<0.90: z = 3
            default:      z = 4
            }
            acc[z] += Int(dt)
        }
        let names = ["1 준비", "2 지방연소", "3 유산소", "4 무산소", "5 최대"]
        return (0..<5).map { (zone: $0 + 1, label: names[$0], seconds: acc[$0]) }
    }

    var isEmpty: Bool {
        hr.isEmpty && speed.isEmpty && cadence.isEmpty
            && activeKcal == 0 && distance == 0
    }
}

/// 워치 목록에 보낼 압축 요약
struct SessionBrief: Codable, Hashable, Identifiable {
    var id: String
    var date: Date
    var kind: String        // "근력" / "인터벌" / "일반"
    var seconds: Int
    var distanceKm: Double
    var avgHR: Int
    var volumeKg: Int
    var detail: String
}
