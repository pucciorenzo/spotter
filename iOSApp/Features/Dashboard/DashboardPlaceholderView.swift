import SwiftUI

struct DashboardPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Dashboard",
            systemImage: "chart.xyaxis.line",
            description: Text("Training metrics are planned for a later milestone.")
        )
        .navigationTitle("Dashboard")
    }
}

#Preview {
    NavigationStack {
        DashboardPlaceholderView()
    }
}
