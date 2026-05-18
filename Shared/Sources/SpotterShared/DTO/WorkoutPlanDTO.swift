import Foundation

public struct WorkoutPlanDTO: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var description: String
    public var goal: String
    public var days: [WorkoutDayDTO]
    public var isActive: Bool
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        name: String,
        description: String,
        goal: String,
        days: [WorkoutDayDTO],
        isActive: Bool,
        isArchived: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.goal = goal
        self.days = days
        self.isActive = isActive
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct WorkoutDayDTO: Codable, Identifiable, Hashable {
    public var id: UUID
    public var planId: UUID
    public var name: String
    public var orderIndex: Int
    public var notes: String
    public var exercises: [WorkoutExerciseDTO]

    public init(
        id: UUID,
        planId: UUID,
        name: String,
        orderIndex: Int,
        notes: String,
        exercises: [WorkoutExerciseDTO]
    ) {
        self.id = id
        self.planId = planId
        self.name = name
        self.orderIndex = orderIndex
        self.notes = notes
        self.exercises = exercises
    }
}

public struct WorkoutExerciseDTO: Codable, Identifiable, Hashable {
    public var id: UUID
    public var workoutDayId: UUID
    public var exerciseId: UUID
    public var orderIndex: Int

    public var numberOfSets: Int
    public var warmupSets: Int

    public var targetType: SetTargetType
    public var targetReps: Int?
    public var targetRepsMin: Int?
    public var targetRepsMax: Int?
    public var targetDurationSeconds: Int?
    public var targetDurationMinSeconds: Int?
    public var targetDurationMaxSeconds: Int?

    public var startingLoad: Double?
    public var loadUnit: LoadUnit
    public var suggestedIncrement: Double?
    public var restSeconds: Int

    public var rpeTarget: Double?
    public var rirTarget: Int?
    public var tempo: String?
    public var notes: String

    public var supersetGroupId: UUID?
    public var autoProgressionEnabled: Bool

    public init(
        id: UUID,
        workoutDayId: UUID,
        exerciseId: UUID,
        orderIndex: Int,
        numberOfSets: Int,
        warmupSets: Int,
        targetType: SetTargetType,
        targetReps: Int?,
        targetRepsMin: Int?,
        targetRepsMax: Int?,
        targetDurationSeconds: Int?,
        targetDurationMinSeconds: Int?,
        targetDurationMaxSeconds: Int?,
        startingLoad: Double?,
        loadUnit: LoadUnit,
        suggestedIncrement: Double?,
        restSeconds: Int,
        rpeTarget: Double?,
        rirTarget: Int?,
        tempo: String?,
        notes: String,
        supersetGroupId: UUID?,
        autoProgressionEnabled: Bool
    ) {
        self.id = id
        self.workoutDayId = workoutDayId
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        self.numberOfSets = numberOfSets
        self.warmupSets = warmupSets
        self.targetType = targetType
        self.targetReps = targetReps
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.targetDurationSeconds = targetDurationSeconds
        self.targetDurationMinSeconds = targetDurationMinSeconds
        self.targetDurationMaxSeconds = targetDurationMaxSeconds
        self.startingLoad = startingLoad
        self.loadUnit = loadUnit
        self.suggestedIncrement = suggestedIncrement
        self.restSeconds = restSeconds
        self.rpeTarget = rpeTarget
        self.rirTarget = rirTarget
        self.tempo = tempo
        self.notes = notes
        self.supersetGroupId = supersetGroupId
        self.autoProgressionEnabled = autoProgressionEnabled
    }
}
