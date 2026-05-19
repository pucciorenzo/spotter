import SpotterShared
import SwiftUI

struct WatchPlanListView: View {
    @EnvironmentObject private var syncManager: WatchPhoneSyncManager

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.title2)
                        Text("No Plans")
                            .font(.headline)
                        Text("Open Spotter on iPhone to sync active plans.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
                }
            }
            .navigationTitle("Spotter")
            .toolbar {
                Button {
                    syncManager.requestSnapshot()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh Plans")
            }
        }
    }

    private var plans: [WorkoutPlanDTO] {
        syncManager.snapshot?.activePlans ?? []
    }
}

#Preview {
    WatchPlanListView()
        .environmentObject(WatchPhoneSyncManager(cacheStore: WatchCacheStore()))
}
