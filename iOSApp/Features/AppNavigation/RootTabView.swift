import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ExerciseListPlaceholderView()
            }
            .tabItem {
                Label("Exercises", systemImage: "figure.strengthtraining.traditional")
            }

            NavigationStack {
                PlanListPlaceholderView()
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
    }
}

#Preview {
    RootTabView()
}
