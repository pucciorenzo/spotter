import SwiftUI

@main
struct SpotterWatchApp: App {
    @StateObject private var syncManager = WatchPhoneSyncManager()

    var body: some Scene {
        WindowGroup {
            WatchPlanListView()
                .environmentObject(syncManager)
        }
    }
}
