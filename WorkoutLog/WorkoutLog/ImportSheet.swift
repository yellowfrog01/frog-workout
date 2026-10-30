import SwiftUI
import SwiftData
import HealthKit

/// 애플 운동 앱 기록 가져오기
struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var existing: [Session]
    @State private var imp = HealthImporter.shared
    @State private var importing: Set<UUID> = []
    @State private var done: Set<UUID> = []

    private var alreadyImported: Set<String> {
        Set(existing.compactMap(\.healthKitUUID))
            .union(existing.compactMap { $0.intervalDetail?.warmup?.healthKitUUID })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if imp.busy {
                        ProgressView().tint(Palette.strength).padding(.top, 40)
                    }
                    if !imp.note.isEmpty {
                        Text(imp.note)
                            .font(.rounded(13, .semibold))
                            .foregroundStyle(Palette.dim)
                            .multilineTextAlignment(.center)
                            .padding(.top, 30)
                    }
                    ForEach(imp.found) { c in row(c) }
                }
                .padding(18)
            }
            .background(Palette.bg)
            .navigationTitle("애플 운동 가져오기")
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }.foregroundStyle(Palette.dim)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("새로고침") { imp.scan() }
                        .font(.rounded(15, .semibold)).foregroundStyle(Palette.strength)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { if imp.found.isEmpty { imp.scan() } }
    }

    private func row(_ c: HealthImporter.Candidate) -> some View {
        let isDone = done.contains(c.id) || alreadyImported.contains(c.id.uuidString)
        let isBusy = importing.contains(c.id)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(c.activity)
                        .font(.rounded(15, .bold)).foregroundStyle(Palette.interval)
                    if IntervalImporter.isInterval(c.workout) {
                        Text("인터벌 \(c.workout.workoutActivities.count)구간")
                            .font(.rounded(10, .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Palette.interval.opacity(0.18), in: .capsule)
                            .foregroundStyle(Palette.interval)
                    }
                    Text(c.sourceName)
                        .font(.rounded(10, .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.white.opacity(0.1), in: .capsule)
                        .foregroundStyle(Palette.dimmer)
                }
                Text("\(c.start.monthDay) \(c.start.hmShort) · \(c.seconds.hmsString)")
                    .font(.rounded(13, .medium)).monospacedDigit()
                    .foregroundStyle(Palette.dim)
                HStack(spacing: 10) {
                    if c.distanceKm > 0.01 {
                        Text(String(format: "%.2fkm", c.distanceKm))
                            .foregroundStyle(WatchTint.distance)
                    }
                    if c.kcal > 0 {
                        Text("\(c.kcal)kcal").foregroundStyle(WatchTint.energy)
                    }
                }
                .font(.rounded(12, .bold)).monospacedDigit()
            }
            Spacer()
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22)).foregroundStyle(Palette.strength)
            } else if isBusy {
                ProgressView().tint(Palette.strength)
            } else {
                Button("가져오기") { importOne(c) }
                    .font(.rounded(13, .bold)).foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Palette.strength, in: .capsule)
                    .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Palette.card, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.cardStroke, lineWidth: 1))
    }

    private func importOne(_ c: HealthImporter.Candidate) {
        importing.insert(c.id)
        imp.load(c.workout) { tele, route in
            IntervalImporter.load(c.workout) { detail in
                let w = c.workout
                let strength = [HKWorkoutActivityType.traditionalStrengthTraining,
                                .functionalStrengthTraining].contains(w.workoutActivityType)
                let s = Session(
                    date: w.startDate,
                    kind: strength ? .strength : .interval,
                    condition: .normal,
                    startAt: w.startDate, endAt: w.endDate,
                    cardioMode: strength ? nil : (detail == nil ? .steady : .interval),
                    route: route,
                    hr: tele.hr.map { HRPoint(bpm: $0.v, t: $0.t) },
                    distanceMeters: tele.distance,
                    telemetry: tele)
                s.healthKitUUID = w.uuid.uuidString
                s.note = HealthImporter.label(w.workoutActivityType) + " · " + w.sourceRevision.source.name
                if let detail {
                    s.intervalDetail = detail
                    // 워밍업을 따로 가져온 기록이 있으면 이 세션으로 합친다
                    if let wu = detail.warmup?.healthKitUUID {
                        for old in existing where old.healthKitUUID == wu { ctx.delete(old) }
                        if let id = UUID(uuidString: wu) { done.insert(id) }
                    }
                }
                ctx.insert(s)
                importing.remove(c.id)
                done.insert(c.id)
                Haptics.success()
            }
        }
    }
}
