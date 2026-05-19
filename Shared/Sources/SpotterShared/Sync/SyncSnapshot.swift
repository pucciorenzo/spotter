import Foundation

public struct SyncSnapshot: Codable, Hashable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var generatedAt: Date
    public var exercises: [ExerciseDTO]
    public var activePlans: [WorkoutPlanDTO]
    public var recentSessions: [WorkoutSessionDTO]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        generatedAt: Date,
        exercises: [ExerciseDTO],
        activePlans: [WorkoutPlanDTO],
        recentSessions: [WorkoutSessionDTO]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.exercises = exercises
        self.activePlans = activePlans
        self.recentSessions = recentSessions
    }
}

public struct SyncWorkoutPayload: Codable, Hashable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var sentAt: Date
    public var session: WorkoutSessionDTO

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        sentAt: Date,
        session: WorkoutSessionDTO
    ) {
        self.schemaVersion = schemaVersion
        self.sentAt = sentAt
        self.session = session
    }
}
