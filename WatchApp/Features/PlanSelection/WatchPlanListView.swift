import SpotterShared
import SwiftUI

struct WatchPlanListView: View {
    private let plans = DemoSeedData.plans

    var body: some View {
        NavigationStack {
            List(plans) { plan in
                NavigationLink {
                    WatchDayListView(plan: plan)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.name)
                            .font(.headline)
                        Text("\(plan.days.count) days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Spotter")
        }
    }
}

#Preview {
    WatchPlanListView()
}
