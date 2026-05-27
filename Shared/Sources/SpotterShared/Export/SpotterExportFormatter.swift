import Foundation

public struct SpotterExportSnapshot: Codable, Equatable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var generatedBy: String
    public var exercises: [ExerciseDTO]
    public var workoutPlans: [WorkoutPlanDTO]
    public var workoutSessions: [WorkoutSessionDTO]
    public var progressHistory: [WorkoutSetLogDTO]

    public init(
        schemaVersion: Int = 1,
        exportedAt: Date,
        generatedBy: String = "Spotter",
        exercises: [ExerciseDTO],
        workoutPlans: [WorkoutPlanDTO],
        workoutSessions: [WorkoutSessionDTO],
        progressHistory: [WorkoutSetLogDTO]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.generatedBy = generatedBy
        self.exercises = exercises
        self.workoutPlans = workoutPlans
        self.workoutSessions = workoutSessions
        self.progressHistory = progressHistory
    }
}

public enum SpotterExportFormatter {
    public static func jsonData(for snapshot: SpotterExportSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    public static func exercisesCSV(_ exercises: [ExerciseDTO]) -> String {
        var rows = [[
            "id",
            "name",
            "primary_muscle_group",
            "category",
            "tracking_type",
            "default_rest_seconds",
            "default_load_unit",
        ]]

        rows += exercises.map { exercise in
            [
                exercise.id.uuidString,
                exercise.name,
                exercise.primaryMuscleGroup,
                exercise.category.rawValue,
                exercise.defaultMeasurementType.rawValue,
                "\(exercise.defaultRestSeconds)",
                exercise.defaultLoadUnit.rawValue,
            ]
        }

        return csv(rows)
    }

    public static func workoutSessionsCSV(_ sessions: [WorkoutSessionDTO]) -> String {
        var rows = [[
            "session_id",
            "plan_name",
            "day_name",
            "started_at",
            "duration_seconds",
            "status",
            "set_count",
            "total_volume",
        ]]

        rows += sessions.map { session in
            [
                session.id.uuidString,
                session.planNameSnapshot,
                session.dayNameSnapshot,
                formatDate(session.startedAt),
                "\(session.durationSeconds)",
                session.status.rawValue,
                "\(session.setLogs.count)",
                format(totalVolume(session.setLogs)),
            ]
        }

        return csv(rows)
    }

    public static func progressHistoryCSV(_ logs: [WorkoutSetLogDTO]) -> String {
        var rows = [[
            "set_log_id",
            "session_id",
            "exercise_name",
            "set_index",
            "is_warmup",
            "completed_reps",
            "completed_duration_seconds",
            "completed_load",
            "completed_load_unit",
            "rpe",
            "rir",
            "completed_at",
        ]]

        rows += logs.map { log in
            [
                log.id.uuidString,
                log.sessionId.uuidString,
                log.exerciseNameSnapshot,
                "\(log.setIndex)",
                "\(log.isWarmup)",
                string(log.completedReps),
                string(log.completedDurationSeconds),
                string(log.completedLoad),
                log.completedLoadUnit.rawValue,
                string(log.rpe),
                string(log.rir),
                formatDate(log.completedAt),
            ]
        }

        return csv(rows)
    }

    private static func csv(_ rows: [[String]]) -> String {
        rows
            .map { row in row.map(escape).joined(separator: ",") }
            .joined(separator: "\n") + "\n"
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }

        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func string(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }

    private static func string(_ value: Double?) -> String {
        value.map(format) ?? ""
    }

    private static func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.2f", value)
    }

    private static func volume(_ log: WorkoutSetLogDTO) -> Double {
        guard log.completionType == .completed,
              let reps = log.completedReps,
              let load = log.completedLoad else {
            return 0
        }

        return Double(reps) * load
    }

    private static func totalVolume(_ logs: [WorkoutSetLogDTO]) -> Double {
        logs.reduce(0) { $0 + volume($1) }
    }
}
