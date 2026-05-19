import Foundation

public struct WorkoutExecutionState: Codable, Identifiable, Hashable {
    public var id: UUID { session.id }
    public var session: WorkoutSessionDTO
    public var currentExerciseIndex: Int
    public var rest: RestTimerState?

    public init(
        session: WorkoutSessionDTO,
        currentExerciseIndex: Int,
        rest: RestTimerState?
    ) {
        self.session = session
        self.currentExerciseIndex = currentExerciseIndex
        self.rest = rest
    }
}

public struct RestTimerState: Codable, Hashable {
    public var startedAt: Date
    public var plannedSeconds: Int
    public var completionHapticSent: Bool

    public init(
        startedAt: Date,
        plannedSeconds: Int,
        completionHapticSent: Bool = false
    ) {
        self.startedAt = startedAt
        self.plannedSeconds = plannedSeconds
        self.completionHapticSent = completionHapticSent
    }
}

public enum WorkoutExecutionEngine {
    public static func start(
        plan: WorkoutPlanDTO,
        day: WorkoutDayDTO,
        at date: Date = Date()
    ) -> WorkoutExecutionState {
        let session = WorkoutSessionDTO(
            id: UUID(),
            planId: plan.id,
            dayId: day.id,
            planNameSnapshot: plan.name,
            dayNameSnapshot: day.name,
            startedAt: date,
            endedAt: nil,
            durationSeconds: 0,
            source: .watch,
            status: .inProgress,
            setLogs: [],
            notes: "",
            createdAt: date,
            updatedAt: date
        )

        return WorkoutExecutionState(
            session: session,
            currentExerciseIndex: 0,
            rest: nil
        )
    }

    public static func sortedExercises(in day: WorkoutDayDTO) -> [WorkoutExerciseDTO] {
        day.exercises.sorted { lhs, rhs in
            lhs.orderIndex < rhs.orderIndex
        }
    }

    public static func totalSetCount(for exercise: WorkoutExerciseDTO) -> Int {
        max(0, exercise.warmupSets) + max(0, exercise.numberOfSets)
    }

    public static func completedSetCount(
        for exercise: WorkoutExerciseDTO,
        in state: WorkoutExecutionState
    ) -> Int {
        state.session.setLogs.filter { $0.workoutExerciseId == exercise.id }.count
    }

    public static func nextSetIndex(
        for exercise: WorkoutExerciseDTO,
        in state: WorkoutExecutionState
    ) -> Int {
        completedSetCount(for: exercise, in: state) + 1
    }

    public static func appendCompletedSet(
        to state: inout WorkoutExecutionState,
        day: WorkoutDayDTO,
        exercise: WorkoutExerciseDTO,
        exerciseName: String,
        completedReps: Int?,
        completedDurationSeconds: Int?,
        completedLoad: Double?,
        completedAt date: Date = Date()
    ) {
        let setIndex = nextSetIndex(for: exercise, in: state)
        let log = WorkoutSetLogDTO(
            id: UUID(),
            sessionId: state.session.id,
            exerciseId: exercise.exerciseId,
            workoutExerciseId: exercise.id,
            exerciseNameSnapshot: exerciseName,
            setIndex: setIndex,
            isWarmup: setIndex <= exercise.warmupSets,
            targetReps: targetReps(for: exercise),
            targetDurationSeconds: targetDurationSeconds(for: exercise),
            targetLoad: exercise.startingLoad,
            targetLoadUnit: exercise.loadUnit,
            completedReps: completedReps,
            completedDurationSeconds: completedDurationSeconds,
            completedLoad: completedLoad,
            completedLoadUnit: exercise.loadUnit,
            restPlannedSeconds: exercise.restSeconds,
            restActualSeconds: nil,
            rpe: nil,
            rir: nil,
            notes: "",
            completedAt: date
        )

        state.session.setLogs.append(log)
        state.session.durationSeconds = max(0, Int(date.timeIntervalSince(state.session.startedAt)))
        state.session.updatedAt = date
        state.rest = RestTimerState(startedAt: date, plannedSeconds: exercise.restSeconds)

        if let nextIndex = nextIncompleteExerciseIndex(in: day, state: state) {
            state.currentExerciseIndex = nextIndex
        }
    }

    public static func finish(
        _ state: inout WorkoutExecutionState,
        at date: Date = Date()
    ) {
        state.session.status = .completed
        state.session.endedAt = date
        state.session.durationSeconds = max(0, Int(date.timeIntervalSince(state.session.startedAt)))
        state.session.updatedAt = date
        state.rest = nil
    }

    public static func cancel(
        _ state: inout WorkoutExecutionState,
        at date: Date = Date()
    ) {
        state.session.status = .cancelled
        state.session.endedAt = date
        state.session.durationSeconds = max(0, Int(date.timeIntervalSince(state.session.startedAt)))
        state.session.updatedAt = date
        state.rest = nil
    }

    public static func nextIncompleteExerciseIndex(
        in day: WorkoutDayDTO,
        state: WorkoutExecutionState
    ) -> Int? {
        let exercises = sortedExercises(in: day)
        return exercises.firstIndex { exercise in
            completedSetCount(for: exercise, in: state) < totalSetCount(for: exercise)
        }
    }

    private static func targetReps(for exercise: WorkoutExerciseDTO) -> Int? {
        exercise.targetReps ?? exercise.targetRepsMax ?? exercise.targetRepsMin
    }

    private static func targetDurationSeconds(for exercise: WorkoutExerciseDTO) -> Int? {
        exercise.targetDurationSeconds ?? exercise.targetDurationMaxSeconds ?? exercise.targetDurationMinSeconds
    }
}
