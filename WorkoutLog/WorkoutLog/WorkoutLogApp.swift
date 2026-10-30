import SwiftUI
import SwiftData

@main
struct WorkoutLogApp: App {
    let container: ModelContainer

    init() {
        container = Self.makeContainer()
        WatchLink.shared.recordsProvider = Self.makeRecordsProvider(container)
        StrengthLive.install()
        StrengthLive.sync(StrengthDraftStore.shared.draft)
        SyncService.shared.start(container: container)
    }

    /// 워치 기록 화면용 요약. 워치는 SwiftData 저장소를 못 보므로 아이폰이 만들어 보낸다.
    private static func makeRecordsProvider(_ container: ModelContainer) -> () -> [[String: Any]] {
        { 
            var fd = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            fd.fetchLimit = 15
            let list = (try? container.mainContext.fetch(fd)) ?? []
            return list.map { s in
                var parts: [String] = []
                let title: String
                if s.kind == .strength {
                    title = s.bodyPart?.label ?? "근력"
                    if !s.lifts.isEmpty { parts.append("\(s.lifts.count)종목") }
                    if s.totalVolume > 0 { parts.append("\(Int(s.totalVolume))kg") }
                } else {
                    title = s.kind == .activity ? (s.activityName ?? s.kind.label) : (s.cardioMode?.label ?? s.kind.label)
                    if s.distanceKm > 0.01 { parts.append(String(format: "%.2fkm", s.distanceKm)) }
                    if s.avgHR > 0 { parts.append("\(s.avgHR)bpm") }
                }
                if let d = s.durationSeconds, d > 0 { parts.append(d.hmsString) }
                return [
                    "d": s.logicalDay.timeIntervalSince1970,
                    "kind": s.kindRaw,
                    "cond": s.conditionRaw,
                    "title": title,
                    "sub": parts.joined(separator: " · ")
                ]
            }
        }
    }

    /// 스키마가 바뀌어 마이그레이션이 실패하면 저장소를 새로 만든다.
    /// (개발 중 앱이 아예 안 켜지는 상황을 막는다)
    private static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: Session.self, BodyRecord.self, Vital.self, PlannedWorkout.self)
        } catch {
            let fm = FileManager.default
            if let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                for name in ["default.store", "default.store-shm", "default.store-wal"] {
                    try? fm.removeItem(at: dir.appendingPathComponent(name))
                }
            }
            if let c = try? ModelContainer(for: Session.self, BodyRecord.self, Vital.self, PlannedWorkout.self) { return c }
            // 그래도 안 되면 메모리에서라도 동작시킨다
            let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: Session.self, BodyRecord.self, Vital.self, PlannedWorkout.self, configurations: cfg)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabs()
        }
        .modelContainer(container)
    }
}
