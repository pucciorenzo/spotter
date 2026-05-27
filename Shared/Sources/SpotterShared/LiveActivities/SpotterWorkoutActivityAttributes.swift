#if os(iOS) && canImport(ActivityKit)
    import ActivityKit
    import Foundation

    public struct SpotterWorkoutActivityAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            public var exerciseName: String
            public var setLabel: String
            public var compactSetLabel: String
            public var restStartedAt: Date?
            public var restDurationSeconds: Int
            public var restRemainingSeconds: Int
            public var isPaused: Bool
            public var isEnded: Bool

            public init(
                exerciseName: String,
                setLabel: String,
                compactSetLabel: String,
                restStartedAt: Date?,
                restDurationSeconds: Int,
                restRemainingSeconds: Int,
                isPaused: Bool,
                isEnded: Bool
            ) {
                self.exerciseName = exerciseName
                self.setLabel = setLabel
                self.compactSetLabel = compactSetLabel
                self.restStartedAt = restStartedAt
                self.restDurationSeconds = restDurationSeconds
                self.restRemainingSeconds = restRemainingSeconds
                self.isPaused = isPaused
                self.isEnded = isEnded
            }
        }

        public var sessionId: UUID
        public var workoutName: String

        public init(sessionId: UUID, workoutName: String) {
            self.sessionId = sessionId
            self.workoutName = workoutName
        }
    }
#endif
