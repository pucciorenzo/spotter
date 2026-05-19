import Foundation

public enum MeasurementType: String, Codable, CaseIterable, Identifiable, Hashable {
    case repetitions
    case duration

    public var id: String { rawValue }
}

public enum ExerciseCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case strength
    case cardio
    case mobility
    case warmup
    case other

    public var id: String { rawValue }
}

public enum EquipmentType: String, Codable, CaseIterable, Identifiable, Hashable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case kettlebell
    case cardioMachine
    case other

    public var id: String { rawValue }
}

public enum LoadUnit: String, Codable, CaseIterable, Identifiable, Hashable {
    case kg
    case lb
    case bodyweight

    public var id: String { rawValue }
}

public enum SetTargetType: String, Codable, CaseIterable, Identifiable, Hashable {
    case fixedReps
    case repRange
    case fixedDuration
    case durationRange
    case amrap

    public var id: String { rawValue }
}

public enum WorkoutSource: String, Codable, CaseIterable, Identifiable, Hashable {
    case iphone
    case watch

    public var id: String { rawValue }
}

public enum WorkoutStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case inProgress
    case completed
    case cancelled

    public var id: String { rawValue }
}

public enum WorkoutSetCompletionType: String, Codable, CaseIterable, Identifiable, Hashable {
    case completed
    case skipped

    public var id: String { rawValue }
}
