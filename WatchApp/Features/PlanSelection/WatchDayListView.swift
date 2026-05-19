import Foundation
import SpotterShared
import SwiftUI

struct WatchDayListView: View {
    @EnvironmentObject private var syncManager: WatchPhoneSyncManager
    let plan: WorkoutPlanDTO

    var body: some View {
        List(plan.days) { day in
            Section {
                NavigationLink {
                    WatchWorkoutView(plan: plan, day: day)
                } label: {
                    Label("Start \(day.name)", systemImage: "play.circle.fill")
                }

                ForEach(day.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exerciseName(for: exercise.exerciseId))
                            .font(.headline)
                        Text(targetText(for: exercise))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.name)
                    Text("\(day.exercises.count) exercises")
                }
            }
        }
        .navigationTitle(plan.name)
    }

    private func exerciseName(for id: UUID) -> String {
        syncManager.snapshot?.exercises.first(where: { $0.id == id })?.name ?? "Exercise"
    }

    private func targetText(for exercise: WorkoutExerciseDTO) -> String {
        if let seconds = exercise.targetDurationSeconds {
            return "\(exercise.numberOfSets) sets • \(seconds)s"
        }

        if let min = exercise.targetRepsMin, let max = exercise.targetRepsMax {
            return "\(exercise.numberOfSets) sets • \(min)-\(max) reps"
        }

        return "\(exercise.numberOfSets) sets"
    }
}

#Preview {
    NavigationStack {
        WatchDayListView(plan: DemoSeedData.plans[0])
    }
    .environmentObject(WatchPhoneSyncManager(cacheStore: WatchCacheStore()))
}
