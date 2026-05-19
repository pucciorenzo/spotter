import SpotterShared
import SwiftUI

struct WatchDayListView: View {
    let plan: WorkoutPlanDTO

    var body: some View {
        List(plan.days) { day in
            VStack(alignment: .leading, spacing: 4) {
                Text(day.name)
                    .font(.headline)
                Text("\(day.exercises.count) exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(plan.name)
    }
}

#Preview {
    NavigationStack {
        WatchDayListView(plan: DemoSeedData.plans[0])
    }
}
