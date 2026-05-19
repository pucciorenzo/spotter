import Foundation

public struct WorkoutSessionDTO: Codable, Identifiable, Hashable {
    public var id: UUID
    public var planId: UUID?
    public var dayId: UUID?
    public var planNameSnapshot: String
    public var dayNameSnapshot: String
    public var startedAt: Date
    public var endedAt: Date?
    public var durationSeconds: Int
    public var source: WorkoutSource
    public var status: WorkoutStatus
    public var setLogs: [WorkoutSetLogDTO]
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        planId: UUID?,
        dayId: UUID?,
        planNameSnapshot: String,
        dayNameSnapshot: String,
        startedAt: Date,
        endedAt: Date?,
        durationSeconds: Int,
        source: WorkoutSource,
        status: WorkoutStatus,
        setLogs: [WorkoutSetLogDTO],
        notes: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.planId = planId
        self.dayId = dayId
        self.planNameSnapshot = planNameSnapshot
        self.dayNameSnapshot = dayNameSnapshot
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.source = source
        self.status = status
        self.setLogs = setLogs
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct WorkoutSetLogDTO: Codable, Identifiable, Hashable {
    public var id: UUID
    public var sessionId: UUID
    public var exerciseId: UUID
    public var originalExerciseId: UUID?
    public var workoutExerciseId: UUID?
    public var exerciseNameSnapshot: String
    public var setIndex: Int
    public var isWarmup: Bool
    public var completionType: WorkoutSetCompletionType?
    public var targetReps: Int?
    public var targetDurationSeconds: Int?
    public var targetLoad: Double?
    public var targetLoadUnit: LoadUnit
    public var completedReps: Int?
    public var completedDurationSeconds: Int?
    public var completedLoad: Double?
    public var completedLoadUnit: LoadUnit
    public var restPlannedSeconds: Int
    public var restActualSeconds: Int?
    public var rpe: Double?
    public var rir: Int?
    public var notes: String
    public var completedAt: Date

    public init(
        id: UUID,
        sessionId: UUID,
        exerciseId: UUID,
        originalExerciseId: UUID? = nil,
        workoutExerciseId: UUID?,
        exerciseNameSnapshot: String,
        setIndex: Int,
        isWarmup: Bool,
        completionType: WorkoutSetCompletionType? = .completed,
        targetReps: Int?,
        targetDurationSeconds: Int?,
        targetLoad: Double?,
        targetLoadUnit: LoadUnit,
        completedReps: Int?,
        completedDurationSeconds: Int?,
        completedLoad: Double?,
        completedLoadUnit: LoadUnit,
        restPlannedSeconds: Int,
        restActualSeconds: Int?,
        rpe: Double?,
        rir: Int?,
        notes: String,
        completedAt: Date
    ) {
        self.id = id
        self.sessionId = sessionId
        self.exerciseId = exerciseId
        self.originalExerciseId = originalExerciseId
        self.workoutExerciseId = workoutExerciseId
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.setIndex = setIndex
        self.isWarmup = isWarmup
        self.completionType = completionType
        self.targetReps = targetReps
        self.targetDurationSeconds = targetDurationSeconds
        self.targetLoad = targetLoad
        self.targetLoadUnit = targetLoadUnit
        self.completedReps = completedReps
        self.completedDurationSeconds = completedDurationSeconds
        self.completedLoad = completedLoad
        self.completedLoadUnit = completedLoadUnit
        self.restPlannedSeconds = restPlannedSeconds
        self.restActualSeconds = restActualSeconds
        self.rpe = rpe
        self.rir = rir
        self.notes = notes
        self.completedAt = completedAt
    }
}
