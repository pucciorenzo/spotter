import Foundation
import SpotterShared

enum SnapshotBuilder {
    static func makeSnapshot(
        exercises: [ExerciseModel],
        plans: [WorkoutPlanModel],
        generatedAt: Date = Date()
    ) -> SyncSnapshot {
        SyncSnapshot(
            generatedAt: generatedAt,
            exercises: exercises
                .filter { !$0.isArchived }
                .map { $0.toDTO() }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            activePlans: plans
                .filter { $0.isActive && !$0.isArchived }
                .map { $0.toDTO() }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            recentSessions: []
        )
    }
}
