import SpotterShared
import Foundation
import SwiftUI

struct PlanListPlaceholderView: View {
    private let plans = DemoSeedData.plans

    var body: some View {
        List(plans) { plan in
            NavigationLink {
                PlanDetailPlaceholderView(plan: plan)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.headline)
                    Text("\(plan.days.count) days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Plans")
    }
}

private struct PlanDetailPlaceholderView: View {
    let plan: WorkoutPlanDTO

    var body: some View {
        List(plan.days) { day in
            Section(day.name) {
                ForEach(day.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exerciseName(for: exercise.exerciseId))
                            .font(.headline)
                        Text(targetText(for: exercise))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(plan.name)
    }

    private func exerciseName(for id: UUID) -> String {
        DemoSeedData.exercises.first(where: { $0.id == id })?.name ?? "Exercise"
    }

    private func targetText(for exercise: WorkoutExerciseDTO) -> String {
        if let seconds = exercise.targetDurationSeconds {
            return "\(exercise.numberOfSets) sets • \(seconds)s • \(exercise.restSeconds)s rest"
        }

        if let min = exercise.targetRepsMin, let max = exercise.targetRepsMax {
            return "\(exercise.numberOfSets) sets • \(min)-\(max) reps • \(exercise.restSeconds)s rest"
        }

        return "\(exercise.numberOfSets) sets • \(exercise.restSeconds)s rest"
    }
}

#Preview {
    NavigationStack {
        PlanListPlaceholderView()
    }
}
