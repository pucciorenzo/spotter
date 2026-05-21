import Foundation

public struct PersistedWorkoutExecutionState: Equatable {
    public var state: WorkoutExecutionState
    public var planSnapshot: WorkoutPlanDTO?
    public var daySnapshot: WorkoutDayDTO?
    public var lastAutosavedAt: Date

    public init(
        state: WorkoutExecutionState,
        planSnapshot: WorkoutPlanDTO?,
        daySnapshot: WorkoutDayDTO?,
        lastAutosavedAt: Date
    ) {
        self.state = state
        self.planSnapshot = planSnapshot
        self.daySnapshot = daySnapshot
        self.lastAutosavedAt = lastAutosavedAt
    }
}

public protocol ExerciseRepository {
    func fetchExercises(includeArchived: Bool) throws -> [ExerciseDTO]
    func saveExercise(_ exercise: ExerciseDTO) throws
}

public protocol WorkoutPlanRepository {
    func fetchPlans(includeArchived: Bool) throws -> [WorkoutPlanDTO]
    func savePlan(_ plan: WorkoutPlanDTO) throws
    func snapshotPlan(_ plan: WorkoutPlanDTO) throws -> WorkoutPlanDTO
}

public protocol WorkoutSessionRepository {
    func fetchSessions() throws -> [WorkoutSessionDTO]
    func saveActiveSession(_ session: WorkoutSessionDTO) throws
    func saveCompletedSession(_ session: WorkoutSessionDTO) throws
}

public protocol ProgressHistoryRepository {
    func latestSetLogs(for exerciseId: UUID, limit: Int) throws -> [WorkoutSetLogDTO]
    func completedSessions() throws -> [WorkoutSessionDTO]
}

public protocol ActiveWorkoutStateRepository {
    func loadActiveWorkout() throws -> PersistedWorkoutExecutionState?
    func saveActiveWorkout(
        _ state: WorkoutExecutionState,
        planSnapshot: WorkoutPlanDTO?,
        daySnapshot: WorkoutDayDTO?
    ) throws
    func clearActiveWorkout() throws
}
