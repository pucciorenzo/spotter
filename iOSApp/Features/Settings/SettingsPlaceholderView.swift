import SwiftUI

struct SettingsPlaceholderView: View {
    @EnvironmentObject private var watchSyncManager: PhoneWatchSyncManager

    var body: some View {
        List {
            Section("Defaults") {
                LabeledContent("Units", value: "kg")
                LabeledContent("Default Rest", value: "120s")
            }

            Section("Sync") {
                LabeledContent("Watch", value: watchSyncManager.activationStateDescription)
                if let lastSnapshotSentAt = watchSyncManager.lastSnapshotSentAt {
                    LabeledContent("Last Snapshot", value: lastSnapshotSentAt.formatted(date: .omitted, time: .shortened))
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
