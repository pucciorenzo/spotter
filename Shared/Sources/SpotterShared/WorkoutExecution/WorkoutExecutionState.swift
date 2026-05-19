import Foundation

public struct WorkoutExecutionState: Codable, Identifiable, Hashable {
    public var id: UUID { session.id }
    public var session: WorkoutSessionDTO
    public var currentExerciseIndex: Int
    public var rest: RestTimerState?
    public var exerciseOrder: [UUID]
    public var substitutions: [WorkoutExerciseSubstitution]

    public init(
        session: WorkoutSessionDTO,
        currentExerciseIndex: Int,
        rest: RestTimerState?,
        exerciseOrder: [UUID] = [],
        substitutions: [WorkoutExerciseSubstitution] = []
    ) {
        self.session = session
        self.currentExerciseIndex = currentExerciseIndex
        self.rest = rest
        self.exerciseOrder = exerciseOrder
        self.substitutions = substitutions
    }

    private enum CodingKeys: String, CodingKey {
        case session
        case currentExerciseIndex
        case rest
        case exerciseOrder
        case substitutions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decode(WorkoutSessionDTO.self, forKey: .session)
        currentExerciseIndex = try container.decode(Int.self, forKey: .currentExerciseIndex)
        rest = try container.decodeIfPresent(RestTimerState.self, forKey: .rest)
        exerciseOrder = try container.decodeIfPresent([UUID].self, forKey: .exerciseOrder) ?? []
        substitutions = try container.decodeIfPresent([WorkoutExerciseSubstitution].self, forKey: .substitutions) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(session, forKey: .session)
        try container.encode(currentExerciseIndex, forKey: .currentExerciseIndex)
        try container.encodeIfPresent(rest, forKey: .rest)
        try container.encode(exerciseOrder, forKey: .exerciseOrder)
        try container.encode(substitutions, forKey: .substitutions)
    }
}

public struct WorkoutExerciseSubstitution: Codable, Identifiable, Hashable {
    public var id: UUID { workoutExerciseId }
    public var workoutExerciseId: UUID
    public var originalExerciseId: UUID
    public var replacementExerciseId: UUID
    public var replacementExerciseName: String
    public var changedAt: Date

    public init(
        workoutExerciseId: UUID,
        originalExerciseId: UUID,
        replacementExerciseId: UUID,
        replacementExerciseName: String,
        changedAt: Date
    ) {
        self.workoutExerciseId = workoutExerciseId
        self.originalExerciseId = originalExerciseId
        self.replacementExerciseId = replacementExerciseId
        self.replacementExerciseName = replacementExerciseName
        self.changedAt = changedAt
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
        source: WorkoutSource = .watch,
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
            source: source,
            status: .inProgress,
            setLogs: [],
            notes: "",
            createdAt: date,
            updatedAt: date
        )

        return WorkoutExecutionState(
            session: session,
            currentExerciseIndex: 0,
            rest: nil,
            exerciseOrder: sortedExercises(in: day).map(\.id)
        )
    }

    public static func sortedExercises(in day: WorkoutDayDTO) -> [WorkoutExerciseDTO] {
        day.exercises.sorted { lhs, rhs in
            lhs.orderIndex < rhs.orderIndex
        }
    }

    public static func orderedExercises(
        in day: WorkoutDayDTO,
        state: WorkoutExecutionState
    ) -> [WorkoutExerciseDTO] {
        let sortedExercises = sortedExercises(in: day)
        guard !state.exerciseOrder.isEmpty else {
            return sortedExercises
        }

        let exerciseById = Dictionary(uniqueKeysWithValues: sortedExercises.map { ($0.id, $0) })
        let ordered = state.exerciseOrder.compactMap { exerciseById[$0] }
        let missing = sortedExercises.filter { !state.exerciseOrder.contains($0.id) }
        return ordered + missing
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
        rpe: Double? = nil,
        rir: Int? = nil,
        completedAt date: Date = Date()
    ) {
        let setIndex = nextSetIndex(for: exercise, in: state)
        let log = WorkoutSetLogDTO(
            id: UUID(),
            sessionId: state.session.id,
            exerciseId: effectiveExerciseId(for: exercise, in: state),
            originalExerciseId: originalExerciseId(for: exercise, in: state),
            workoutExerciseId: exercise.id,
            exerciseNameSnapshot: exerciseName,
            setIndex: setIndex,
            isWarmup: setIndex <= exercise.warmupSets,
            completionType: .completed,
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
            rpe: rpe,
            rir: rir,
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

    public static func updateSetLog(
        in state: inout WorkoutExecutionState,
        logId: UUID,
        completedReps: Int?,
        completedDurationSeconds: Int?,
        completedLoad: Double?,
        rpe: Double? = nil,
        rir: Int? = nil,
        at date: Date = Date()
    ) {
        guard let index = state.session.setLogs.firstIndex(where: { $0.id == logId }) else {
            return
        }

        state.session.setLogs[index].completedReps = completedReps
        state.session.setLogs[index].completedDurationSeconds = completedDurationSeconds
        state.session.setLogs[index].completedLoad = completedLoad
        state.session.setLogs[index].rpe = rpe
        state.session.setLogs[index].rir = rir
        state.session.setLogs[index].completedAt = date
        state.session.updatedAt = date
    }

    public static func appendSkippedSet(
        to state: inout WorkoutExecutionState,
        day: WorkoutDayDTO,
        exercise: WorkoutExerciseDTO,
        exerciseName: String,
        reason: String,
        skippedAt date: Date = Date()
    ) {
        appendSkippedSetLog(
            to: &state,
            day: day,
            exercise: exercise,
            exerciseName: exerciseName,
            reason: reason,
            skippedAt: date
        )
    }

    public static func skipExercise(
        in state: inout WorkoutExecutionState,
        day: WorkoutDayDTO,
        exercise: WorkoutExerciseDTO,
        exerciseName: String,
        skippedAt date: Date = Date()
    ) {
        while completedSetCount(for: exercise, in: state) < totalSetCount(for: exercise) {
            appendSkippedSetLog(
                to: &state,
                day: day,
                exercise: exercise,
                exerciseName: exerciseName,
                reason: "Skipped exercise",
                skippedAt: date
            )
        }
    }

    public static func moveCurrentExercise(
        in state: inout WorkoutExecutionState,
        day: WorkoutDayDTO,
        by offset: Int,
        at date: Date = Date()
    ) {
        var order = orderedExercises(in: day, state: state).map(\.id)
        guard order.indices.contains(state.currentExerciseIndex) else {
            return
        }

        let targetIndex = state.currentExerciseIndex + offset
        guard order.indices.contains(targetIndex) else {
            return
        }

        order.swapAt(state.currentExerciseIndex, targetIndex)
        state.exerciseOrder = order
        state.currentExerciseIndex = targetIndex
        state.session.updatedAt = date
    }

    public static func substituteExercise(
        in state: inout WorkoutExecutionState,
        workoutExercise: WorkoutExerciseDTO,
        replacementExercise: ExerciseDTO,
        at date: Date = Date()
    ) {
        state.substitutions.removeAll { $0.workoutExerciseId == workoutExercise.id }
        guard replacementExercise.id != workoutExercise.exerciseId else {
            state.session.updatedAt = date
            return
        }

        let substitution = WorkoutExerciseSubstitution(
            workoutExerciseId: workoutExercise.id,
            originalExerciseId: workoutExercise.exerciseId,
            replacementExerciseId: replacementExercise.id,
            replacementExerciseName: replacementExercise.name,
            changedAt: date
        )

        state.substitutions.append(substitution)
        state.session.updatedAt = date
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
        let exercises = orderedExercises(in: day, state: state)
        return exercises.firstIndex { exercise in
            completedSetCount(for: exercise, in: state) < totalSetCount(for: exercise)
        }
    }

    private static func appendSkippedSetLog(
        to state: inout WorkoutExecutionState,
        day: WorkoutDayDTO,
        exercise: WorkoutExerciseDTO,
        exerciseName: String,
        reason: String,
        skippedAt date: Date
    ) {
        let setIndex = nextSetIndex(for: exercise, in: state)
        let log = WorkoutSetLogDTO(
            id: UUID(),
            sessionId: state.session.id,
            exerciseId: effectiveExerciseId(for: exercise, in: state),
            originalExerciseId: originalExerciseId(for: exercise, in: state),
            workoutExerciseId: exercise.id,
            exerciseNameSnapshot: exerciseName,
            setIndex: setIndex,
            isWarmup: setIndex <= exercise.warmupSets,
            completionType: .skipped,
            targetReps: targetReps(for: exercise),
            targetDurationSeconds: targetDurationSeconds(for: exercise),
            targetLoad: exercise.startingLoad,
            targetLoadUnit: exercise.loadUnit,
            completedReps: nil,
            completedDurationSeconds: nil,
            completedLoad: nil,
            completedLoadUnit: exercise.loadUnit,
            restPlannedSeconds: exercise.restSeconds,
            restActualSeconds: nil,
            rpe: nil,
            rir: nil,
            notes: reason,
            completedAt: date
        )

        state.session.setLogs.append(log)
        state.session.durationSeconds = max(0, Int(date.timeIntervalSince(state.session.startedAt)))
        state.session.updatedAt = date
        state.rest = nil

        if let nextIndex = nextIncompleteExerciseIndex(in: day, state: state) {
            state.currentExerciseIndex = nextIndex
        }
    }

    private static func effectiveExerciseId(
        for exercise: WorkoutExerciseDTO,
        in state: WorkoutExecutionState
    ) -> UUID {
        state.substitutions
            .first { $0.workoutExerciseId == exercise.id }?
            .replacementExerciseId ?? exercise.exerciseId
    }

    private static func originalExerciseId(
        for exercise: WorkoutExerciseDTO,
        in state: WorkoutExecutionState
    ) -> UUID? {
        guard effectiveExerciseId(for: exercise, in: state) != exercise.exerciseId else {
            return nil
        }

        return exercise.exerciseId
    }

    private static func targetReps(for exercise: WorkoutExerciseDTO) -> Int? {
        exercise.targetReps ?? exercise.targetRepsMax ?? exercise.targetRepsMin
    }

    private static func targetDurationSeconds(for exercise: WorkoutExerciseDTO) -> Int? {
        exercise.targetDurationSeconds ?? exercise.targetDurationMaxSeconds ?? exercise.targetDurationMinSeconds
    }
}
