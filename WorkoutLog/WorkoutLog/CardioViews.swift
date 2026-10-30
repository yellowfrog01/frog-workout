import SwiftUI
import MapKit
import Charts

// MARK: - 경로 지도

struct RouteMap: View {
    let points: [RoutePoint]
    var height: CGFloat = 220
    var follow: Bool = false

    @State private var camera: MapCameraPosition = .automatic

    private var coords: [CLLocationCoordinate2D] { points.map(\.coord) }

    var body: some View {
        Map(position: $camera, interactionModes: follow ? [] : .all) {
            if coords.count > 1 {
                MapPolyline(coordinates: coords)
                    .stroke(WatchTint.distance, style: .init(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            if let first = coords.first {
                Annotation("시작", coordinate: first) {
                    Circle().fill(.green).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            if let last = coords.last, coords.count > 1 {
                Annotation("현재", coordinate: last) {
                    Circle().fill(WatchTint.energy).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .frame(height: height)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.cardStroke, lineWidth: 1))
        .onChange(of: points.count) { _, _ in fit() }
        .onAppear { fit() }
        .overlay {
            if coords.isEmpty {
                ZStack {
                    Color.black.opacity(0.55)
                    VStack(spacing: 6) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 22, weight: .semibold))
                        Text("위치 수신 대기 중")
                            .font(.rounded(13, .semibold))
                    }
                    .foregroundStyle(Palette.dim)
                }
                .clipShape(.rect(cornerRadius: 16))
            }
        }
    }

    private func fit() {
        guard !coords.isEmpty else { return }
        if coords.count < 3, let last = coords.last {
            camera = .region(MKCoordinateRegion(center: last,
                latitudinalMeters: 500, longitudinalMeters: 500))
            return
        }
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        // 경로가 비정상적으로 넓으면(좌표 튐) 마지막 위치 기준으로 본다
        if maxLat - minLat > 1 || maxLon - minLon > 1, let last = coords.last {
            camera = .region(MKCoordinateRegion(center: last,
                latitudinalMeters: 800, longitudinalMeters: 800))
            return
        }
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.4, 0.003),
                                    longitudeDelta: max((maxLon - minLon) * 1.4, 0.003))
        camera = .region(MKCoordinateRegion(center: center, span: span))
    }
}

// MARK: - 심박수 그래프

struct HRChart: View {
    let samples: [HRPoint]
    var height: CGFloat = 150

    /// Y 도메인. 항상 lo < hi 보장.
    private var yDomain: ClosedRange<Double> {
        let vals = samples.map(\.bpm).filter { $0 > 0 && $0.isFinite }
        guard let mn = vals.min(), let mx = vals.max() else { return 50...190 }
        let lo = max(30, mn - 10)
        let hi = min(230, mx + 10)
        return hi - lo < 15 ? lo...(lo + 15) : lo...hi
    }
    /// X 도메인. 샘플 시각이 모두 같아도 붕괴하지 않게.
    private var xDomain: ClosedRange<Double> {
        let ts = samples.map(\.t).filter { $0.isFinite }
        guard let mn = ts.min(), let mx = ts.max() else { return 0...60 }
        return mx - mn < 5 ? mn...(mn + 5) : mn...mx
    }
    /// 시각 역행·중복이 있으면 선이 되돌아가 겹쳐 보인다. 항상 정렬해서 그린다.
    private var clean: [HRPoint] {
        let ok = samples.filter { $0.bpm > 0 && $0.bpm.isFinite && $0.t.isFinite }
                        .sorted { $0.t < $1.t }
        var seen = Set<Int>()
        return ok.filter { seen.insert(Int($0.t * 10)).inserted }
    }

    var body: some View {
        Group {
            if clean.count < 2 {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
                    VStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 22, weight: .semibold))
                        Text("심박 데이터 수신 대기 중")
                            .font(.rounded(13, .semibold))
                    }
                    .foregroundStyle(Palette.dimmer)
                }
                .frame(height: height)
            } else {
                Chart(clean) { s in
                    LineMark(x: .value("시간", s.t), y: .value("BPM", s.bpm))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(WatchTint.heart)
                        .lineStyle(.init(lineWidth: 2.2, lineCap: .round))
                    // yStart 를 도메인 하한에 고정해야 카드 밖으로 새지 않는다
                    AreaMark(x: .value("시간", s.t),
                             yStart: .value("기준", yDomain.lowerBound),
                             yEnd: .value("BPM", s.bpm))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.linearGradient(
                            colors: [WatchTint.heart.opacity(0.30), WatchTint.heart.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom))
                }
                .chartYScale(domain: yDomain)
                .chartXScale(domain: xDomain)
                .chartPlotStyle { $0.clipped() }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { v in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel().foregroundStyle(Palette.dimmer)
                            .font(.rounded(10, .semibold))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { v in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel {
                            if let t = v.as(Double.self) {
                                Text(Int(t).clockString)
                                    .font(.rounded(10, .semibold))
                                    .foregroundStyle(Palette.dimmer)
                            }
                        }
                    }
                }
                .frame(height: height)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

// MARK: - 큰 지표 한 줄 (애플워치 스타일)

struct BigMetric: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    var size: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            Text(label)
                .font(.rounded(12, .bold))
                .foregroundStyle(color.opacity(0.85))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.rounded(13, .bold))
                    .foregroundStyle(color.opacity(0.6))
            }
        }
    }
}

/// 애플워치 운동 화면 색상
enum WatchTint {
    static let time     = Color(red: 0.85, green: 0.98, blue: 0.20)
    static let energy   = Color(red: 0.98, green: 0.25, blue: 0.35)
    static let distance = Color(red: 0.20, green: 0.82, blue: 0.94)
    static let pace     = Color(red: 0.60, green: 0.95, blue: 0.30)
    static let heart    = Color(red: 1.00, green: 0.22, blue: 0.37)
}
