import Foundation
import SpotterShared
import SwiftData

enum SeedData {
    @MainActor
    static func insertDemoDataIfNeeded(in context: ModelContext) {
        let exerciseDescriptor = FetchDescriptor<ExerciseModel>()
        let existingExerciseIds = Set((try? context.fetch(exerciseDescriptor).map(\.id)) ?? [])

        for exercise in DemoSeedData.exercises {
            if !existingExerciseIds.contains(exercise.id) {
                context.insert(ExerciseModel(dto: exercise))
            }
        }

        let planDescriptor = FetchDescriptor<WorkoutPlanModel>()
        let existingPlanIds = Set((try? context.fetch(planDescriptor).map(\.id)) ?? [])

        for plan in DemoSeedData.plans {
            if !existingPlanIds.contains(plan.id) {
                context.insert(WorkoutPlanModel(dto: plan))
            }
        }

        try? context.save()
    }
}
