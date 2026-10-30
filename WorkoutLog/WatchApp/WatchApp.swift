import SwiftUI

@main
struct WorkoutLogWatchApp: App {
    @StateObject private var manager = WatchWorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(manager)
        }
    }
}
