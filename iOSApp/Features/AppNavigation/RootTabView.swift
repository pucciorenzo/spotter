import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            NavigationStack {
                ExerciseListView()
            }
            .tabItem {
                Label("Exercises", systemImage: "figure.strengthtraining.traditional")
            }

            NavigationStack {
                PlanListView()
            }
            .tabItem {
                Label("Plans", systemImage: "list.clipboard")
            }

            NavigationStack {
                WorkoutHistoryPlaceholderView()
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }

            NavigationStack {
                DashboardPlaceholderView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.bar")
            }

            NavigationStack {
                SettingsPlaceholderView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .task {
            SeedData.insertDemoDataIfNeeded(in: modelContext)
        }
    }
}

#Preview {
    RootTabView()
}
