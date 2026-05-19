import SwiftUI

struct SettingsPlaceholderView: View {
    @EnvironmentObject private var watchSyncManager: PhoneWatchSyncManager
    @AppStorage("workout.promptForSetResults") private var promptForSetResults = true

    var body: some View {
        List {
            Section("Defaults") {
                LabeledContent("Units", value: "kg")
                LabeledContent("Default Rest", value: "120s")
                Toggle("Prompt for Set Results", isOn: $promptForSetResults)
            }

            Section("Sync") {
                LabeledContent("Watch", value: watchSyncManager.activationStateDescription)
                if let lastSnapshotSentAt = watchSyncManager.lastSnapshotSentAt {
                    LabeledContent("Last Snapshot", value: lastSnapshotSentAt.formatted(date: .omitted, time: .shortened))
                }
                if let lastWorkoutImportedAt = watchSyncManager.lastWorkoutImportedAt {
                    LabeledContent("Last Watch Workout", value: lastWorkoutImportedAt.formatted(date: .omitted, time: .shortened))
                }
                if let lastErrorMessage = watchSyncManager.lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsPlaceholderView()
    }
    .environmentObject(PhoneWatchSyncManager())
}
