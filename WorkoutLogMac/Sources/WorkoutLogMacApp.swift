import SwiftUI
import SwiftData

@main
struct WorkoutLogMacApp: App {
    let container: ModelContainer
    @State private var nav = MacNav()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        container = Self.makeContainer()
        SyncService.shared.start(container: container)
    }

    /// 맥은 근력·유산소 기록, 체성분, 계획, 지표만 쓴다. 스키마가 깨지면 저장소를 새로 만든다(동기화로 복구).
    private static func makeContainer() -> ModelContainer {
        let types: [any PersistentModel.Type] = [Session.self, BodyRecord.self, Vital.self, PlannedWorkout.self]
        let schema = Schema(types)
        do {
            return try ModelContainer(for: schema)
        } catch {
            let fm = FileManager.default
            if let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                for name in ["default.store", "default.store-shm", "default.store-wal"] {
                    try? fm.removeItem(at: dir.appendingPathComponent(name))
                }
            }
            if let c = try? ModelContainer(for: schema) { return c }
            let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: cfg)
        }
    }

    var body: some Scene {
        WindowGroup {
            MacRootView()
                .environment(nav)
                .frame(minWidth: 1100, minHeight: 720)
                .preferredColorScheme(.dark)
                .tint(Palette.strength)
                .onChange(of: scenePhase) { _, p in
                    if p == .active { SyncService.shared.kick() }
                }
        }
        .modelContainer(container)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("새 기록") { nav.newRecordDay = Date() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("동기화") { SyncService.shared.kick() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
