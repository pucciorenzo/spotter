import Foundation
import SpotterShared
import SwiftData

struct SpotterExportSnapshot: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let generatedBy: String
    let aiUsageHint: String
    let exercises: [ExerciseDTO]
    let workoutPlans: [WorkoutPlanDTO]
    let workoutSessions: [WorkoutSessionDTO]
    let progressHistory: [WorkoutSetLogDTO]
}

@MainActor
enum SpotterExportService {
    static func makeJSONExport(context: ModelContext) throws -> [URL] {
        let snapshot = try makeSnapshot(context: context)
        let directory = try makeExportDirectory()
        let url = directory.appending(path: "spotter-export.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic])
        return [url]
    }

    static func makeCSVExport(context: ModelContext) throws -> [URL] {
        let snapshot = try makeSnapshot(context: context)
        let directory = try makeExportDirectory()
        let files: [(String, String)] = [
            ("spotter-exercises.csv", exercisesCSV(snapshot.exercises)),
            ("spotter-workout-plans.csv", workoutPlansCSV(snapshot.workoutPlans)),
            ("spotter-workout-sessions.csv", workoutSessionsCSV(snapshot.workoutSessions)),
            ("spotter-progress-history.csv", progressHistoryCSV(snapshot.workoutSessions))
        ]

        return try files.map { fileName, contents in
            let url = directory.appending(path: fileName)
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        }
    }

    private static func makeSnapshot(context: ModelContext) throws -> SpotterExportSnapshot {
        let exercises = try SwiftDataExerciseRepository(context: context)
            .fetchExercises(includeArchived: true)
        let plans = try SwiftDataWorkoutPlanRepository(context: context)
            .fetchPlans(includeArchived: true)
        let sessions = try SwiftDataWorkoutSessionRepository(context: context)
            .fetchSessions()
        let setLogs = sessions
            .flatMap(\.setLogs)
            .sorted { $0.completedAt < $1.completedAt }

        return SpotterExportSnapshot(
            schemaVersion: 1,
            exportedAt: Date(),
            generatedBy: "Spotter iOS",
            aiUsageHint: "Local, user-initiated export. Safe to paste into an AI tool if the user chooses.",
            exercises: exercises,
            workoutPlans: plans,
            workoutSessions: sessions,
            progressHistory: setLogs
        )
    }

    private static func makeExportDirectory() throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let safeTimestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SpotterExport-\(safeTimestamp)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func exercisesCSV(_ exercises: [ExerciseDTO]) -> String {
        var rows = [[
            "id",
            "name",
            "primary_muscle_group",
            "secondary_muscle_groups",
            "category",
            "equipment",
            "tracking_type",
            "default_rest_seconds",
            "default_load_unit",
            "is_unilateral",
            "is_warmup",
            "is_archived",
            "notes",
            "created_at",
            "updated_at"
        ]]

        rows += exercises.map { exercise in
            [
                exercise.id.uuidString,
                exercise.name,
                exercise.primaryMuscleGroup,
                exercise.secondaryMuscleGroups.joined(separator: "; "),
                exercise.category.rawValue,
                exercise.equipment.rawValue,
                exercise.defaultMeasurementType.rawValue,
                "\(exercise.defaultRestSeconds)",
                exercise.defaultLoadUnit.rawValue,
                "\(exercise.isUnilateral)",
                "\(exercise.isWarmup)",
                "\(exercise.isArchived)",
                exercise.notes,
                formatDate(exercise.createdAt),
                formatDate(exercise.updatedAt)
            ]
        }

        return csv(rows)
    }

    private static func workoutPlansCSV(_ plans: [WorkoutPlanDTO]) -> String {
        var rows = [[
            "plan_id",
            "plan_name",
            "plan_goal",
            "plan_is_active",
            "day_id",
            "day_name",
            "day_order",
            "planned_exercise_id",
            "exercise_id",
            "exercise_order",
            "sets",
            "warmup_sets",
            "target_type",
            "target_reps",
            "target_reps_min",
            "target_reps_max",
            "target_duration_seconds",
            "starting_load",
            "load_unit",
            "rest_seconds",
            "rpe_target",
            "rir_target",
            "superset_group_id",
            "auto_progression_enabled",
            "notes"
        ]]

        for plan in plans {
            let sortedDays = plan.days.sorted(by: { $0.orderIndex < $1.orderIndex })
            if sortedDays.isEmpty {
                rows.append(workoutPlanRow(plan: plan, day: nil, exercise: nil))
                continue
            }

            for day in sortedDays {
                let sortedExercises = day.exercises.sorted(by: { $0.orderIndex < $1.orderIndex })
                if sortedExercises.isEmpty {
                    rows.append(workoutPlanRow(plan: plan, day: day, exercise: nil))
                    continue
                }

                for exercise in sortedExercises {
                    rows.append(workoutPlanRow(plan: plan, day: day, exercise: exercise))
                }
            }
        }

        return csv(rows)
    }

    private static func workoutPlanRow(
        plan: WorkoutPlanDTO,
        day: WorkoutDayDTO?,
        exercise: WorkoutExerciseDTO?
    ) -> [String] {
        [
            plan.id.uuidString,
            plan.name,
            plan.goal,
            "\(plan.isActive)",
            day?.id.uuidString ?? "",
            day?.name ?? "",
            day.map { "\($0.orderIndex)" } ?? "",
            exercise?.id.uuidString ?? "",
            exercise?.exerciseId.uuidString ?? "",
            exercise.map { "\($0.orderIndex)" } ?? "",
            exercise.map { "\($0.numberOfSets)" } ?? "",
            exercise.map { "\($0.warmupSets)" } ?? "",
            exercise?.targetType.rawValue ?? "",
            string(exercise?.targetReps),
            string(exercise?.targetRepsMin),
            string(exercise?.targetRepsMax),
            string(exercise?.targetDurationSeconds),
            string(exercise?.startingLoad),
            exercise?.loadUnit.rawValue ?? "",
            exercise.map { "\($0.restSeconds)" } ?? "",
            string(exercise?.rpeTarget),
            string(exercise?.rirTarget),
            exercise?.supersetGroupId?.uuidString ?? "",
            exercise.map { "\($0.autoProgressionEnabled)" } ?? "",
            exercise?.notes ?? ""
        ]
    }

    private static func workoutSessionsCSV(_ sessions: [WorkoutSessionDTO]) -> String {
        var rows = [[
            "session_id",
            "plan_id",
            "day_id",
            "plan_name",
            "day_name",
            "started_at",
            "ended_at",
            "duration_seconds",
            "source",
            "status",
            "set_count",
            "total_volume",
            "notes",
            "created_at",
            "updated_at"
        ]]

        rows += sessions.map { session in
            [
                session.id.uuidString,
                session.planId?.uuidString ?? "",
                session.dayId?.uuidString ?? "",
                session.planNameSnapshot,
                session.dayNameSnapshot,
                formatDate(session.startedAt),
                session.endedAt.map(formatDate) ?? "",
                "\(session.durationSeconds)",
                session.source.rawValue,
                session.status.rawValue,
                "\(session.setLogs.count)",
                format(totalVolume(session.setLogs)),
                session.notes,
                formatDate(session.createdAt),
                formatDate(session.updatedAt)
            ]
        }

        return csv(rows)
    }

    private static func progressHistoryCSV(_ sessions: [WorkoutSessionDTO]) -> String {
        let sessionById = sessions.reduce(into: [UUID: WorkoutSessionDTO]()) { partial, session in
            guard let existing = partial[session.id] else {
                partial[session.id] = session
                return
            }

            if session.updatedAt >= existing.updatedAt {
                partial[session.id] = session
            }
        }
        var rows = [[
            "set_log_id",
            "session_id",
            "plan_name",
            "day_name",
            "exercise_id",
            "exercise_name",
            "set_index",
            "is_warmup",
            "completion_type",
            "target_reps",
            "target_duration_seconds",
            "target_load",
            "target_load_unit",
            "completed_reps",
            "completed_duration_seconds",
            "completed_load",
            "completed_load_unit",
            "volume",
            "rest_planned_seconds",
            "rest_actual_seconds",
            "rpe",
            "rir",
            "notes",
            "completed_at"
        ]]

        let logs = sessions
            .flatMap(\.setLogs)
            .sorted { $0.completedAt < $1.completedAt }

        rows += logs.map { log in
            let session = sessionById[log.sessionId]
            return [
                log.id.uuidString,
                log.sessionId.uuidString,
                session?.planNameSnapshot ?? "",
                session?.dayNameSnapshot ?? "",
                log.exerciseId.uuidString,
                log.exerciseNameSnapshot,
                "\(log.setIndex)",
                "\(log.isWarmup)",
                log.completionType?.rawValue ?? "",
                string(log.targetReps),
                string(log.targetDurationSeconds),
                string(log.targetLoad),
                log.targetLoadUnit.rawValue,
                string(log.completedReps),
                string(log.completedDurationSeconds),
                string(log.completedLoad),
                log.completedLoadUnit.rawValue,
                format(volume(log)),
                "\(log.restPlannedSeconds)",
                string(log.restActualSeconds),
                string(log.rpe),
                string(log.rir),
                log.notes,
                formatDate(log.completedAt)
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
        date.ISO8601Format()
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
