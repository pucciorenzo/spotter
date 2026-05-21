import Foundation
import SpotterShared

enum SnapshotBuilder {
    static func makeSnapshot(
        exercises: [ExerciseModel],
        plans: [WorkoutPlanModel],
        sessions: [WorkoutSessionModel] = [],
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
            recentSessions: sessions
                .filter { $0.status == .completed }
                .sorted { $0.startedAt > $1.startedAt }
                .prefix(20)
                .map { $0.toDTO() }
        )
    }
}
