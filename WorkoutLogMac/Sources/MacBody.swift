import SwiftUI
import SwiftData
import Charts

/// 체성분: 추이 차트 3개 + 기록 표
struct MacBodyView: View {
    @Query(sort: \BodyRecord.date) private var records: [BodyRecord]

    private var useFatMass: Bool { !records.contains { $0.bodyFatPercent != nil } }

    var body: some View {
        if records.isEmpty {
            Text("체성분 기록이 없습니다. 동기화 또는 인바디 가져오기 후 표시됩니다.")
                .font(.rounded(15)).foregroundStyle(Palette.dim)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    trendCard("체중", unit: "kg", color: Palette.strength,
                              points: records.map { ($0.date, $0.weight) })
                    trendCard("골격근량", unit: "kg", color: Palette.activity,
                              points: records.compactMap { r in r.skeletalMuscle.map { (r.date, $0) } })
                    if useFatMass {
                        trendCard("체지방량", unit: "kg", color: Palette.interval,
                                  points: records.compactMap { r in r.bodyFatMass.map { (r.date, $0) } })
                    } else {
                        trendCard("체지방률", unit: "%", color: Palette.interval,
                                  points: records.compactMap { r in r.bodyFatPercent.map { (r.date, $0) } })
                    }
                }
                .frame(height: 230)
                table
            }
            .padding(20)
        }
    }

    private func trendCard(_ title: String, unit: String, color: Color,
                           points: [(Date, Double)]) -> some View {
        let latest = points.last?.1
        let delta: Double? = points.count >= 2 ? points[points.count - 1].1 - points[points.count - 2].1 : nil
        return CardBox {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.rounded(14)).foregroundStyle(Palette.dim)
                Spacer()
                if let latest {
                    Text(String(format: "%.1f%@", latest, unit)).font(.rounded(20, .bold))
                }
                if let delta {
                    Text(String(format: "%+.1f", delta))
                        .font(.rounded(13)).foregroundStyle(color)
                }
            }
            if points.isEmpty {
                Text("데이터 없음").font(.rounded(13)).foregroundStyle(Palette.dim)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    ForEach(points.indices, id: \.self) { i in
                        LineMark(x: .value("날짜", points[i].0), y: .value(title, points[i].1))
                            .foregroundStyle(color)
                        PointMark(x: .value("날짜", points[i].0), y: .value(title, points[i].1))
                            .foregroundStyle(color)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
            }
        }
    }

    private func f(_ v: Double?, _ digits: Int = 1) -> String {
        v.map { String(format: "%.\(digits)f", $0) } ?? "–"
    }

    private var table: some View {
        Table(records.reversed()) {
            TableColumn("날짜") { r in
                Text(r.date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ko_KR"))))
            }
            TableColumn("체중") { r in Text(f(r.weight)) }
            TableColumn("골격근량") { r in Text(f(r.skeletalMuscle)) }
            TableColumn("체지방량") { r in Text(f(r.bodyFatMass)) }
            TableColumn("체지방률") { r in Text(f(r.bodyFatPercent)) }
            TableColumn("BMI") { r in Text(f(r.bmi)) }
            TableColumn("SMI") { r in Text(f(r.smi, 2)) }
            TableColumn("내장지방") { r in Text(f(r.visceralLevel, 0)) }
            TableColumn("점수") { r in Text(f(r.score, 0)) }
        }
    }
}
