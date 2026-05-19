import SwiftData

enum ModelContainerProvider {
    static func make() throws -> ModelContainer {
        let schema = Schema([
            ExerciseModel.self,
            WorkoutPlanModel.self,
            WorkoutDayModel.self,
            WorkoutExerciseModel.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
