import Foundation
import SpotterShared
import SwiftData

enum SeedData {
    @MainActor
    static func insertDemoDataIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<ExerciseModel>()
        let existingExercises = (try? context.fetchCount(descriptor)) ?? 0
        guard existingExercises == 0 else { return }

        for exercise in DemoSeedData.exercises {
            context.insert(ExerciseModel(dto: exercise))
        }

        for plan in DemoSeedData.plans {
            context.insert(WorkoutPlanModel(dto: plan))
        }

        try? context.save()
    }
}
