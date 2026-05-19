import Foundation
import SpotterShared
import SwiftData

struct PersistedActiveWorkout: Identifiable {
    var id: UUID { state.id }
    let state: WorkoutExecutionState
    let planSnapshot: WorkoutPlanDTO?
    let daySnapshot: WorkoutDayDTO?
    let lastAutosavedAt: Date
}

@MainActor
protocol ExerciseRepositoryProtocol {
    func fetchExercises(includeArchived: Bool) throws -> [ExerciseDTO]
    func saveExercise(_ exercise: ExerciseDTO) throws
}

@MainActor
protocol WorkoutPlanRepositoryProtocol {
    func fetchPlans(includeArchived: Bool) throws -> [WorkoutPlanDTO]
    func savePlan(_ plan: WorkoutPlanDTO) throws
    func snapshotPlan(_ plan: WorkoutPlanDTO) throws -> WorkoutPlanSnapshotModel
}

@MainActor
protocol WorkoutSessionRepositoryProtocol {
    func fetchSessions() throws -> [WorkoutSessionDTO]
    func saveActiveSession(_ session: WorkoutSessionDTO) throws
    func saveCompletedSession(_ session: WorkoutSessionDTO) throws
}

@MainActor
protocol ProgressHistoryRepositoryProtocol {
    func latestSetLogs(for exerciseId: UUID, limit: Int) throws -> [WorkoutSetLogDTO]
    func completedSessions() throws -> [WorkoutSessionDTO]
}

@MainActor
protocol ActiveWorkoutStateRepositoryProtocol {
    func loadActiveWorkout() throws -> PersistedActiveWorkout?
    func saveActiveWorkout(
        _ state: WorkoutExecutionState,
        planSnapshot: WorkoutPlanDTO?,
        daySnapshot: WorkoutDayDTO?
    ) throws
    func clearActiveWorkout() throws
}

@MainActor
final class SwiftDataExerciseRepository: ExerciseRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchExercises(includeArchived: Bool = false) throws -> [ExerciseDTO] {
        let descriptor = FetchDescriptor<ExerciseModel>(sortBy: [SortDescriptor(\.name)])
        let exercises = try context.fetch(descriptor)
        return exercises
            .filter { includeArchived || !$0.isArchived }
            .map { $0.toDTO() }
    }

    func saveExercise(_ exercise: ExerciseDTO) throws {
        if let existing = try fetchExerciseModel(id: exercise.id) {
            existing.name = exercise.name
            existing.primaryMuscleGroup = exercise.primaryMuscleGroup
            existing.secondaryMuscleGroups = exercise.secondaryMuscleGroups
            existing.category = exercise.category
            existing.equipment = exercise.equipment
            existing.exerciseDescription = exercise.description
            existing.formCues = exercise.formCues
            existing.commonMistakes = exercise.commonMistakes
            existing.videoURL = exercise.videoURL
            existing.notes = exercise.notes
            existing.defaultMeasurementType = exercise.defaultMeasurementType
            existing.defaultRestSeconds = exercise.defaultRestSeconds
            existing.defaultLoadUnit = exercise.defaultLoadUnit
            existing.isUnilateral = exercise.isUnilateral
            existing.isWarmup = exercise.isWarmup
            existing.isArchived = exercise.isArchived
            existing.updatedAt = Date()
        } else {
            context.insert(ExerciseModel(dto: exercise))
        }

        try context.save()
    }

    private func fetchExerciseModel(id: UUID) throws -> ExerciseModel? {
        let descriptor = FetchDescriptor<ExerciseModel>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }
}

@MainActor
final class SwiftDataWorkoutPlanRepository: WorkoutPlanRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchPlans(includeArchived: Bool = false) throws -> [WorkoutPlanDTO] {
        let descriptor = FetchDescriptor<WorkoutPlanModel>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let plans = try context.fetch(descriptor)
        return plans
            .filter { includeArchived || !$0.isArchived }
            .map { $0.toDTO() }
    }

    func savePlan(_ plan: WorkoutPlanDTO) throws {
        if let existing = try fetchPlanModel(id: plan.id) {
            existing.name = plan.name
            existing.planDescription = plan.description
            existing.goal = plan.goal
            existing.days = plan.days.map { WorkoutDayModel(dto: $0) }
            existing.isActive = plan.isActive
            existing.isArchived = plan.isArchived
            existing.version += 1
            existing.updatedAt = Date()
        } else {
            context.insert(WorkoutPlanModel(dto: plan))
        }

        try context.save()
    }

    @discardableResult
    func snapshotPlan(_ plan: WorkoutPlanDTO) throws -> WorkoutPlanSnapshotModel {
        let currentVersion = try fetchPlanModel(id: plan.id)?.version ?? 1
        let snapshot = try WorkoutPlanSnapshotModel(plan: plan, version: currentVersion)
        context.insert(snapshot)
        try context.save()
        return snapshot
    }

    private func fetchPlanModel(id: UUID) throws -> WorkoutPlanModel? {
        let descriptor = FetchDescriptor<WorkoutPlanModel>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }
}

@MainActor
final class SwiftDataWorkoutSessionRepository: WorkoutSessionRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchSessions() throws -> [WorkoutSessionDTO] {
        let descriptor = FetchDescriptor<WorkoutSessionModel>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func saveActiveSession(_ session: WorkoutSessionDTO) throws {
        if let existing = try fetchSessionModel(id: session.id) {
            existing.update(from: session)
        } else {
            context.insert(WorkoutSessionModel(dto: session))
        }

        try context.save()
    }

    func saveCompletedSession(_ session: WorkoutSessionDTO) throws {
        guard session.status == .completed else {
            try saveActiveSession(session)
            return
        }

        if let existing = try fetchSessionModel(id: session.id) {
            existing.update(from: session)
        } else {
            context.insert(WorkoutSessionModel(dto: session))
        }

        try context.save()
    }

    private func fetchSessionModel(id: UUID) throws -> WorkoutSessionModel? {
        let descriptor = FetchDescriptor<WorkoutSessionModel>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }
}

@MainActor
final class SwiftDataProgressHistoryRepository: ProgressHistoryRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func latestSetLogs(for exerciseId: UUID, limit: Int = 10) throws -> [WorkoutSetLogDTO] {
        let descriptor = FetchDescriptor<WorkoutSetLogModel>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        return try context.fetch(descriptor)
            .filter { $0.exerciseId == exerciseId }
            .prefix(limit)
            .map { $0.toDTO() }
    }

    func completedSessions() throws -> [WorkoutSessionDTO] {
        try SwiftDataWorkoutSessionRepository(context: context)
            .fetchSessions()
            .filter { $0.status == .completed }
    }
}

@MainActor
final class SwiftDataActiveWorkoutStateRepository: ActiveWorkoutStateRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func loadActiveWorkout() throws -> PersistedActiveWorkout? {
        let descriptor = FetchDescriptor<ActiveWorkoutStateModel>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        guard let model = try context.fetch(descriptor).first else {
            return nil
        }

        return try PersistedActiveWorkout(
            state: model.toState(),
            planSnapshot: model.toPlanSnapshot(),
            daySnapshot: model.toDaySnapshot(),
            lastAutosavedAt: model.lastAutosavedAt
        )
    }

    func saveActiveWorkout(
        _ state: WorkoutExecutionState,
        planSnapshot: WorkoutPlanDTO? = nil,
        daySnapshot: WorkoutDayDTO? = nil
    ) throws {
        guard state.session.status == .inProgress else {
            try SwiftDataWorkoutSessionRepository(context: context).saveCompletedSession(state.session)
            try clearActiveWorkout()
            return
        }

        if let existing = try fetchActiveWorkout(sessionId: state.session.id) {
            try existing.update(state: state, planSnapshot: planSnapshot, daySnapshot: daySnapshot)
        } else {
            context.insert(
                try ActiveWorkoutStateModel(
                    state: state,
                    planSnapshot: planSnapshot,
                    daySnapshot: daySnapshot
                )
            )
        }

        try SwiftDataWorkoutSessionRepository(context: context).saveActiveSession(state.session)
        try context.save()
    }

    func clearActiveWorkout() throws {
        let descriptor = FetchDescriptor<ActiveWorkoutStateModel>()
        for state in try context.fetch(descriptor) {
            context.delete(state)
        }

        try context.save()
    }

    private func fetchActiveWorkout(sessionId: UUID) throws -> ActiveWorkoutStateModel? {
        let descriptor = FetchDescriptor<ActiveWorkoutStateModel>(predicate: #Predicate { $0.sessionId == sessionId })
        return try context.fetch(descriptor).first
    }
}
