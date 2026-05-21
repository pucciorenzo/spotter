import XCTest
@testable import SpotterShared

final class SpotterCoreLogicTests: XCTestCase {
    func testPlanSnapshotPreservesVersionWhenPlanIsEdited() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let store = InMemoryWorkoutPlanRepository()
        var plan = makePlan(name: "Pull", exerciseName: "Pull-Up", load: 0, now: now)

        try store.savePlan(plan)
        let versionOne = try store.snapshotPlan(plan)

        plan.name = "Pull Heavy"
        plan.days[0].exercises[0].startingLoad = 12.5
        plan.updatedAt = now.addingTimeInterval(60)
        try store.savePlan(plan)
        let versionTwo = try store.snapshotPlan(plan)

        XCTAssertEqual(store.snapshotCount, 2)
        XCTAssertEqual(versionOne.name, "Pull")
        XCTAssertEqual(versionOne.days[0].exercises[0].startingLoad, 0)
        XCTAssertEqual(versionTwo.name, "Pull Heavy")
        XCTAssertEqual(versionTwo.days[0].exercises[0].startingLoad, 12.5)
    }

    func testEditingPlanOnlyAffectsFutureSessions() throws {
        let now = Date(timeIntervalSince1970: 2_000)
        var plan = makePlan(name: "Strength A", exerciseName: "Bench Press", load: 80, now: now)
        let dayV1 = plan.days[0]
        let oldSession = WorkoutExecutionEngine.start(plan: plan, day: dayV1, source: .iphone, at: now)

        plan.name = "Strength B"
        plan.days[0].name = "Upper"
        plan.days[0].exercises[0].startingLoad = 85
        let newSession = WorkoutExecutionEngine.start(
            plan: plan,
            day: plan.days[0],
            source: .iphone,
            at: now.addingTimeInterval(3_600)
        )

        XCTAssertEqual(oldSession.session.planNameSnapshot, "Strength A")
        XCTAssertEqual(oldSession.session.dayNameSnapshot, "Day 1")
        XCTAssertEqual(newSession.session.planNameSnapshot, "Strength B")
        XCTAssertEqual(newSession.session.dayNameSnapshot, "Upper")
    }

    func testCompletedWorkoutHistoryStaysImmutable() throws {
        let repository = InMemoryWorkoutSessionRepository()
        let now = Date(timeIntervalSince1970: 3_000)
        var session = makeCompletedSession(now: now, reps: 8, load: 100)

        try repository.saveCompletedSession(session)
        session.setLogs[0].completedReps = 12
        session.setLogs[0].completedLoad = 120
        try repository.saveCompletedSession(session)

        let saved = try XCTUnwrap(repository.fetchSessions().first)
        XCTAssertEqual(saved.setLogs[0].completedReps, 8)
        XCTAssertEqual(saved.setLogs[0].completedLoad, 100)
    }

    func testActiveWorkoutAutosavesAndRestoresAfterRestart() throws {
        let now = Date(timeIntervalSince1970: 4_000)
        let repository = InMemoryActiveWorkoutStateRepository()
        let plan = makePlan(name: "Pull", exerciseName: "Row", load: 40, now: now)
        let day = plan.days[0]
        let exercise = day.exercises[0]
        var state = WorkoutExecutionEngine.start(plan: plan, day: day, source: .iphone, at: now)

        try repository.saveActiveWorkout(state, planSnapshot: plan, daySnapshot: day)
        WorkoutExecutionEngine.appendCompletedSet(
            to: &state,
            day: day,
            exercise: exercise,
            exerciseName: "Row",
            completedReps: 10,
            completedDurationSeconds: nil,
            completedLoad: 40,
            rpe: 8,
            rir: 2,
            completedAt: now.addingTimeInterval(90)
        )
        try repository.saveActiveWorkout(state, planSnapshot: plan, daySnapshot: day)

        let restoredRepository = InMemoryActiveWorkoutStateRepository(seed: repository.encodedStateData)
        let restored = try XCTUnwrap(restoredRepository.loadActiveWorkout())
        XCTAssertEqual(repository.saveCount, 2)
        XCTAssertEqual(restored.state.session.setLogs.count, 1)
        XCTAssertEqual(restored.state.session.setLogs[0].completedReps, 10)
        XCTAssertEqual(restored.planSnapshot?.name, "Pull")
    }

    func testSetLoggingSupportsRepsWeightDurationRPERIRAndWarmups() throws {
        let now = Date(timeIntervalSince1970: 5_000)
        let plan = makePlan(
            name: "Mixed",
            exerciseName: "Squat",
            load: 100,
            targetType: .repRange,
            targetRepsMin: 6,
            targetRepsMax: 10,
            targetDurationSeconds: nil,
            warmupSets: 1,
            now: now
        )
        let day = plan.days[0]
        let exercise = day.exercises[0]
        var state = WorkoutExecutionEngine.start(plan: plan, day: day, source: .watch, at: now)

        WorkoutExecutionEngine.appendCompletedSet(
            to: &state,
            day: day,
            exercise: exercise,
            exerciseName: "Squat",
            completedReps: 8,
            completedDurationSeconds: nil,
            completedLoad: 100,
            rpe: 8.5,
            rir: 1,
            completedAt: now.addingTimeInterval(120)
        )

        let firstLog = try XCTUnwrap(state.session.setLogs.first)
        XCTAssertTrue(firstLog.isWarmup)
        XCTAssertEqual(firstLog.targetReps, 10)
        XCTAssertEqual(firstLog.completedReps, 8)
        XCTAssertEqual(firstLog.completedLoad, 100)
        XCTAssertEqual(firstLog.rpe, 8.5)
        XCTAssertEqual(firstLog.rir, 1)

        let timedPlan = makePlan(
            name: "Core",
            exerciseName: "Plank",
            load: nil,
            targetType: .fixedDuration,
            targetRepsMin: nil,
            targetRepsMax: nil,
            targetDurationSeconds: 45,
            warmupSets: 0,
            now: now
        )
        let timedDay = timedPlan.days[0]
        let timedExercise = timedDay.exercises[0]
        var timedState = WorkoutExecutionEngine.start(plan: timedPlan, day: timedDay, source: .iphone, at: now)

        WorkoutExecutionEngine.appendCompletedSet(
            to: &timedState,
            day: timedDay,
            exercise: timedExercise,
            exerciseName: "Plank",
            completedReps: nil,
            completedDurationSeconds: 45,
            completedLoad: nil,
            rpe: 7,
            rir: nil,
            completedAt: now.addingTimeInterval(60)
        )

        let timedLog = try XCTUnwrap(timedState.session.setLogs.first)
        XCTAssertEqual(timedLog.targetDurationSeconds, 45)
        XCTAssertEqual(timedLog.completedDurationSeconds, 45)
        XCTAssertNil(timedLog.completedReps)
        XCTAssertNil(timedLog.completedLoad)
    }

    func testCSVAndJSONExportOutputIsHumanReadable() throws {
        let now = Date(timeIntervalSince1970: 6_000)
        let exercise = makeExercise(name: "Bench Press", now: now)
        let session = makeCompletedSession(now: now, reps: 5, load: 100)
        let snapshot = SpotterExportSnapshot(
            exportedAt: now,
            exercises: [exercise],
            workoutPlans: [makePlan(name: "Strength", exerciseName: "Bench Press", load: 100, now: now)],
            workoutSessions: [session],
            progressHistory: session.setLogs
        )

        let jsonData = try SpotterExportFormatter.jsonData(for: snapshot)
        let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
        XCTAssertTrue(json.contains("\"schemaVersion\""))
        XCTAssertTrue(json.contains("Bench Press"))

        let exerciseCSV = SpotterExportFormatter.exercisesCSV([exercise])
        XCTAssertTrue(exerciseCSV.hasPrefix("id,name,primary_muscle_group"))
        XCTAssertTrue(exerciseCSV.contains("Bench Press"))

        let progressCSV = SpotterExportFormatter.progressHistoryCSV(session.setLogs)
        XCTAssertTrue(progressCSV.contains("completed_reps"))
        XCTAssertTrue(progressCSV.contains(",5,,100,kg,"))
    }

    func testRepositoryProtocolsWorkWithMockRepositories() throws {
        let now = Date(timeIntervalSince1970: 7_000)
        let exerciseRepository = InMemoryExerciseRepository()
        let planRepository = InMemoryWorkoutPlanRepository()
        let sessionRepository = InMemoryWorkoutSessionRepository()
        let historyRepository = InMemoryProgressHistoryRepository(sessionRepository: sessionRepository)

        let exercise = makeExercise(name: "Deadlift", now: now)
        let plan = makePlan(name: "Posterior", exerciseName: "Deadlift", load: 140, now: now)
        let session = makeCompletedSession(now: now, reps: 3, load: 140, exerciseId: plan.days[0].exercises[0].exerciseId)

        try exerciseRepository.saveExercise(exercise)
        try planRepository.savePlan(plan)
        try sessionRepository.saveCompletedSession(session)

        XCTAssertEqual(try exerciseRepository.fetchExercises(includeArchived: false).map(\.name), ["Deadlift"])
        XCTAssertEqual(try planRepository.fetchPlans(includeArchived: false).map(\.name), ["Posterior"])
        XCTAssertEqual(try historyRepository.completedSessions().count, 1)
        XCTAssertEqual(try historyRepository.latestSetLogs(for: plan.days[0].exercises[0].exerciseId, limit: 1).first?.completedLoad, 140)
    }
}

private final class InMemoryExerciseRepository: ExerciseRepository {
    private var exercises: [UUID: ExerciseDTO] = [:]

    func fetchExercises(includeArchived: Bool) throws -> [ExerciseDTO] {
        exercises.values
            .filter { includeArchived || !$0.isArchived }
            .sorted { $0.name < $1.name }
    }

    func saveExercise(_ exercise: ExerciseDTO) throws {
        exercises[exercise.id] = exercise
    }
}

private final class InMemoryWorkoutPlanRepository: WorkoutPlanRepository {
    private var plans: [UUID: WorkoutPlanDTO] = [:]
    private(set) var snapshots: [WorkoutPlanDTO] = []

    var snapshotCount: Int { snapshots.count }

    func fetchPlans(includeArchived: Bool) throws -> [WorkoutPlanDTO] {
        plans.values
            .filter { includeArchived || !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func savePlan(_ plan: WorkoutPlanDTO) throws {
        plans[plan.id] = plan
    }

    func snapshotPlan(_ plan: WorkoutPlanDTO) throws -> WorkoutPlanDTO {
        let snapshot = plan
        snapshots.append(snapshot)
        return snapshot
    }
}

private final class InMemoryWorkoutSessionRepository: WorkoutSessionRepository {
    private var sessions: [UUID: WorkoutSessionDTO] = [:]

    func fetchSessions() throws -> [WorkoutSessionDTO] {
        sessions.values.sorted { $0.startedAt > $1.startedAt }
    }

    func saveActiveSession(_ session: WorkoutSessionDTO) throws {
        sessions[session.id] = session
    }

    func saveCompletedSession(_ session: WorkoutSessionDTO) throws {
        if let existing = sessions[session.id], existing.status == .completed {
            return
        }
        sessions[session.id] = session
    }
}

private final class InMemoryProgressHistoryRepository: ProgressHistoryRepository {
    private let sessionRepository: InMemoryWorkoutSessionRepository

    init(sessionRepository: InMemoryWorkoutSessionRepository) {
        self.sessionRepository = sessionRepository
    }

    func latestSetLogs(for exerciseId: UUID, limit: Int) throws -> [WorkoutSetLogDTO] {
        try sessionRepository.fetchSessions()
            .flatMap(\.setLogs)
            .filter { $0.exerciseId == exerciseId }
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(limit)
            .map { $0 }
    }

    func completedSessions() throws -> [WorkoutSessionDTO] {
        try sessionRepository.fetchSessions().filter { $0.status == .completed }
    }
}

private final class InMemoryActiveWorkoutStateRepository: ActiveWorkoutStateRepository {
    private struct StoredState: Codable {
        var state: WorkoutExecutionState
        var planSnapshot: WorkoutPlanDTO?
        var daySnapshot: WorkoutDayDTO?
        var lastAutosavedAt: Date
    }

    private var persisted: PersistedWorkoutExecutionState?
    private(set) var saveCount = 0

    var encodedStateData: Data? {
        guard let persisted else { return nil }
        let stored = StoredState(
            state: persisted.state,
            planSnapshot: persisted.planSnapshot,
            daySnapshot: persisted.daySnapshot,
            lastAutosavedAt: persisted.lastAutosavedAt
        )
        return try? JSONEncoder().encode(stored)
    }

    init(seed: Data? = nil) {
        if let seed,
           let stored = try? JSONDecoder().decode(StoredState.self, from: seed) {
            persisted = PersistedWorkoutExecutionState(
                state: stored.state,
                planSnapshot: stored.planSnapshot,
                daySnapshot: stored.daySnapshot,
                lastAutosavedAt: stored.lastAutosavedAt
            )
        }
    }

    func loadActiveWorkout() throws -> PersistedWorkoutExecutionState? {
        persisted
    }

    func saveActiveWorkout(
        _ state: WorkoutExecutionState,
        planSnapshot: WorkoutPlanDTO?,
        daySnapshot: WorkoutDayDTO?
    ) throws {
        saveCount += 1
        persisted = PersistedWorkoutExecutionState(
            state: state,
            planSnapshot: planSnapshot,
            daySnapshot: daySnapshot,
            lastAutosavedAt: state.session.updatedAt
        )
    }

    func clearActiveWorkout() throws {
        persisted = nil
    }
}

private func makeExercise(name: String, now: Date) -> ExerciseDTO {
    ExerciseDTO(
        id: UUID(),
        name: name,
        primaryMuscleGroup: "Chest",
        secondaryMuscleGroups: [],
        category: .strength,
        equipment: .barbell,
        description: "",
        formCues: [],
        commonMistakes: [],
        videoURL: nil,
        notes: "",
        defaultMeasurementType: .repetitions,
        defaultRestSeconds: 120,
        defaultLoadUnit: .kg,
        isUnilateral: false,
        isWarmup: false,
        isArchived: false,
        createdAt: now,
        updatedAt: now
    )
}

private func makePlan(
    name: String,
    exerciseName: String,
    load: Double?,
    targetType: SetTargetType = .fixedReps,
    targetRepsMin: Int? = nil,
    targetRepsMax: Int? = nil,
    targetDurationSeconds: Int? = nil,
    warmupSets: Int = 0,
    now: Date
) -> WorkoutPlanDTO {
    let planId = UUID()
    let dayId = UUID()
    let workoutExerciseId = UUID()
    let exerciseId = UUID()
    let exercise = WorkoutExerciseDTO(
        id: workoutExerciseId,
        workoutDayId: dayId,
        exerciseId: exerciseId,
        orderIndex: 0,
        numberOfSets: 3,
        warmupSets: warmupSets,
        targetType: targetType,
        targetReps: targetType == .fixedReps ? 8 : nil,
        targetRepsMin: targetRepsMin,
        targetRepsMax: targetRepsMax,
        targetDurationSeconds: targetDurationSeconds,
        targetDurationMinSeconds: nil,
        targetDurationMaxSeconds: nil,
        startingLoad: load,
        loadUnit: .kg,
        suggestedIncrement: 2.5,
        restSeconds: 120,
        rpeTarget: 8,
        rirTarget: 2,
        tempo: nil,
        notes: exerciseName,
        supersetGroupId: nil,
        autoProgressionEnabled: true
    )
    let day = WorkoutDayDTO(
        id: dayId,
        planId: planId,
        name: "Day 1",
        orderIndex: 0,
        notes: "",
        exercises: [exercise]
    )
    return WorkoutPlanDTO(
        id: planId,
        name: name,
        description: "",
        goal: "Strength",
        days: [day],
        isActive: true,
        isArchived: false,
        createdAt: now,
        updatedAt: now
    )
}

private func makeCompletedSession(
    now: Date,
    reps: Int,
    load: Double,
    exerciseId: UUID = UUID()
) -> WorkoutSessionDTO {
    let sessionId = UUID()
    let log = WorkoutSetLogDTO(
        id: UUID(),
        sessionId: sessionId,
        exerciseId: exerciseId,
        workoutExerciseId: UUID(),
        exerciseNameSnapshot: "Bench Press",
        setIndex: 1,
        isWarmup: false,
        completionType: .completed,
        targetReps: reps,
        targetDurationSeconds: nil,
        targetLoad: load,
        targetLoadUnit: .kg,
        completedReps: reps,
        completedDurationSeconds: nil,
        completedLoad: load,
        completedLoadUnit: .kg,
        restPlannedSeconds: 120,
        restActualSeconds: 125,
        rpe: 8,
        rir: 2,
        notes: "",
        completedAt: now.addingTimeInterval(120)
    )

    return WorkoutSessionDTO(
        id: sessionId,
        planId: UUID(),
        dayId: UUID(),
        planNameSnapshot: "Strength",
        dayNameSnapshot: "Day 1",
        startedAt: now,
        endedAt: now.addingTimeInterval(1_800),
        durationSeconds: 1_800,
        source: .iphone,
        status: .completed,
        setLogs: [log],
        notes: "",
        createdAt: now,
        updatedAt: now.addingTimeInterval(1_800)
    )
}
