import SwiftUI
import SwiftData

@main
struct SpotterApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerProvider.make()
        } catch {
            fatalError("Unable to create SwiftData model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
