import SwiftUI

struct WorkoutHistoryPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "No Workouts Yet",
            systemImage: "calendar.badge.clock",
            description: Text("Workout history will appear here after logging is implemented.")
        )
        .navigationTitle("History")
    }
}

#Preview {
    NavigationStack {
        WorkoutHistoryPlaceholderView()
    }
}
