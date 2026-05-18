import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        List {
            Section("Defaults") {
                LabeledContent("Units", value: "kg")
                LabeledContent("Default Rest", value: "120s")
            }

            Section("Sync") {
                LabeledContent("Watch", value: "Not configured")
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsPlaceholderView()
    }
}
