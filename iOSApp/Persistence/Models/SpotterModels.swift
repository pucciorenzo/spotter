import Foundation
import SpotterShared
import SwiftData

@Model
final class ExerciseModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var primaryMuscleGroup: String
    var secondaryMuscleGroups: [String]
    var categoryRawValue: String
    var equipmentRawValue: String
    var exerciseDescription: String
    var formCues: [String]
    var commonMistakes: [String]
    var videoURLString: String?
    var notes: String
    var defaultMeasurementTypeRawValue: String
    var defaultRestSeconds: Int
    var defaultLoadUnitRawValue: String
    var isUnilateral: Bool
    var isWarmup: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(dto: ExerciseDTO) {
        id = dto.id
        name = dto.name
        primaryMuscleGroup = dto.primaryMuscleGroup
        secondaryMuscleGroups = dto.secondaryMuscleGroups
        categoryRawValue = dto.category.rawValue
        equipmentRawValue = dto.equipment.rawValue
        exerciseDescription = dto.description
        formCues = dto.formCues
        commonMistakes = dto.commonMistakes
        videoURLString = dto.videoURL?.absoluteString
        notes = dto.notes
        defaultMeasurementTypeRawValue = dto.defaultMeasurementType.rawValue
        defaultRestSeconds = dto.defaultRestSeconds
        defaultLoadUnitRawValue = dto.defaultLoadUnit.rawValue
        isUnilateral = dto.isUnilateral
        isWarmup = dto.isWarmup
        isArchived = dto.isArchived
        createdAt = dto.createdAt
        updatedAt = dto.updatedAt
    }

    init(name: String) {
        let now = Date()
        id = UUID()
        self.name = name
        primaryMuscleGroup = ""
        secondaryMuscleGroups = []
        categoryRawValue = ExerciseCategory.strength.rawValue
        equipmentRawValue = EquipmentType.other.rawValue
        exerciseDescription = ""
        formCues = []
        commonMistakes = []
        videoURLString = nil
        notes = ""
        defaultMeasurementTypeRawValue = MeasurementType.repetitions.rawValue
        defaultRestSeconds = 120
        defaultLoadUnitRawValue = LoadUnit.kg.rawValue
        isUnilateral = false
        isWarmup = false
        isArchived = false
        createdAt = now
        updatedAt = now
    }

    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var equipment: EquipmentType {
        get { EquipmentType(rawValue: equipmentRawValue) ?? .other }
        set { equipmentRawValue = newValue.rawValue }
    }

    var defaultMeasurementType: MeasurementType {
        get { MeasurementType(rawValue: defaultMeasurementTypeRawValue) ?? .repetitions }
        set { defaultMeasurementTypeRawValue = newValue.rawValue }
    }

    var defaultLoadUnit: LoadUnit {
        get { LoadUnit(rawValue: defaultLoadUnitRawValue) ?? .kg }
        set { defaultLoadUnitRawValue = newValue.rawValue }
    }

    var videoURL: URL? {
        get {
            guard let videoURLString else { return nil }
            return URL(string: videoURLString)
        }
        set { videoURLString = newValue?.absoluteString }
    }

    func toDTO() -> ExerciseDTO {
        ExerciseDTO(
            id: id,
            name: name,
            primaryMuscleGroup: primaryMuscleGroup,
            secondaryMuscleGroups: secondaryMuscleGroups,
            category: category,
            equipment: equipment,
            description: exerciseDescription,
            formCues: formCues,
            commonMistakes: commonMistakes,
            videoURL: videoURL,
            notes: notes,
            defaultMeasurementType: defaultMeasurementType,
            defaultRestSeconds: defaultRestSeconds,
            defaultLoadUnit: defaultLoadUnit,
            isUnilateral: isUnilateral,
            isWarmup: isWarmup,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class WorkoutPlanModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var planDescription: String
    var goal: String
    @Relationship(deleteRule: .cascade) var days: [WorkoutDayModel]
    var isActive: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(dto: WorkoutPlanDTO) {
        id = dto.id
        name = dto.name
        planDescription = dto.description
        goal = dto.goal
        days = dto.days.map { WorkoutDayModel(dto: $0) }
        isActive = dto.isActive
        isArchived = dto.isArchived
        createdAt = dto.createdAt
        updatedAt = dto.updatedAt
    }

    init(name: String) {
        let now = Date()
        id = UUID()
        self.name = name
        planDescription = ""
        goal = ""
        days = []
        isActive = true
        isArchived = false
        createdAt = now
        updatedAt = now
    }

    func toDTO() -> WorkoutPlanDTO {
        WorkoutPlanDTO(
            id: id,
            name: name,
            description: planDescription,
            goal: goal,
            days: days.sorted { $0.orderIndex < $1.orderIndex }.map { $0.toDTO() },
            isActive: isActive,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class WorkoutDayModel {
    @Attribute(.unique) var id: UUID
    var planId: UUID
    var name: String
    var orderIndex: Int
    var notes: String
    @Relationship(deleteRule: .cascade) var exercises: [WorkoutExerciseModel]

    init(dto: WorkoutDayDTO) {
        id = dto.id
        planId = dto.planId
        name = dto.name
        orderIndex = dto.orderIndex
        notes = dto.notes
        exercises = dto.exercises.map { WorkoutExerciseModel(dto: $0) }
    }

    init(planId: UUID, name: String, orderIndex: Int) {
        id = UUID()
        self.planId = planId
        self.name = name
        self.orderIndex = orderIndex
        notes = ""
        exercises = []
    }

    func toDTO() -> WorkoutDayDTO {
        WorkoutDayDTO(
            id: id,
            planId: planId,
            name: name,
            orderIndex: orderIndex,
            notes: notes,
            exercises: exercises.sorted { $0.orderIndex < $1.orderIndex }.map { $0.toDTO() }
        )
    }
}

@Model
final class WorkoutExerciseModel {
    @Attribute(.unique) var id: UUID
    var workoutDayId: UUID
    var exerciseId: UUID
    var orderIndex: Int
    var numberOfSets: Int
    var warmupSets: Int
    var targetTypeRawValue: String
    var targetReps: Int?
    var targetRepsMin: Int?
    var targetRepsMax: Int?
    var targetDurationSeconds: Int?
    var targetDurationMinSeconds: Int?
    var targetDurationMaxSeconds: Int?
    var startingLoad: Double?
    var loadUnitRawValue: String
    var suggestedIncrement: Double?
    var restSeconds: Int
    var rpeTarget: Double?
    var rirTarget: Int?
    var tempo: String?
    var notes: String
    var supersetGroupId: UUID?
    var autoProgressionEnabled: Bool

    init(dto: WorkoutExerciseDTO) {
        id = dto.id
        workoutDayId = dto.workoutDayId
        exerciseId = dto.exerciseId
        orderIndex = dto.orderIndex
        numberOfSets = dto.numberOfSets
        warmupSets = dto.warmupSets
        targetTypeRawValue = dto.targetType.rawValue
        targetReps = dto.targetReps
        targetRepsMin = dto.targetRepsMin
        targetRepsMax = dto.targetRepsMax
        targetDurationSeconds = dto.targetDurationSeconds
        targetDurationMinSeconds = dto.targetDurationMinSeconds
        targetDurationMaxSeconds = dto.targetDurationMaxSeconds
        startingLoad = dto.startingLoad
        loadUnitRawValue = dto.loadUnit.rawValue
        suggestedIncrement = dto.suggestedIncrement
        restSeconds = dto.restSeconds
        rpeTarget = dto.rpeTarget
        rirTarget = dto.rirTarget
        tempo = dto.tempo
        notes = dto.notes
        supersetGroupId = dto.supersetGroupId
        autoProgressionEnabled = dto.autoProgressionEnabled
    }

    init(workoutDayId: UUID, exerciseId: UUID, orderIndex: Int) {
        id = UUID()
        self.workoutDayId = workoutDayId
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        numberOfSets = 3
        warmupSets = 0
        targetTypeRawValue = SetTargetType.repRange.rawValue
        targetReps = nil
        targetRepsMin = 8
        targetRepsMax = 10
        targetDurationSeconds = nil
        targetDurationMinSeconds = nil
        targetDurationMaxSeconds = nil
        startingLoad = nil
        loadUnitRawValue = LoadUnit.kg.rawValue
        suggestedIncrement = 2.5
        restSeconds = 120
        rpeTarget = nil
        rirTarget = nil
        tempo = nil
        notes = ""
        supersetGroupId = nil
        autoProgressionEnabled = true
    }

    var targetType: SetTargetType {
        get { SetTargetType(rawValue: targetTypeRawValue) ?? .repRange }
        set { targetTypeRawValue = newValue.rawValue }
    }

    var loadUnit: LoadUnit {
        get { LoadUnit(rawValue: loadUnitRawValue) ?? .kg }
        set { loadUnitRawValue = newValue.rawValue }
    }

    func toDTO() -> WorkoutExerciseDTO {
        WorkoutExerciseDTO(
            id: id,
            workoutDayId: workoutDayId,
            exerciseId: exerciseId,
            orderIndex: orderIndex,
            numberOfSets: numberOfSets,
            warmupSets: warmupSets,
            targetType: targetType,
            targetReps: targetReps,
            targetRepsMin: targetRepsMin,
            targetRepsMax: targetRepsMax,
            targetDurationSeconds: targetDurationSeconds,
            targetDurationMinSeconds: targetDurationMinSeconds,
            targetDurationMaxSeconds: targetDurationMaxSeconds,
            startingLoad: startingLoad,
            loadUnit: loadUnit,
            suggestedIncrement: suggestedIncrement,
            restSeconds: restSeconds,
            rpeTarget: rpeTarget,
            rirTarget: rirTarget,
            tempo: tempo,
            notes: notes,
            supersetGroupId: supersetGroupId,
            autoProgressionEnabled: autoProgressionEnabled
        )
    }
}

@Model
final class WorkoutSessionModel {
    @Attribute(.unique) var id: UUID
    var planId: UUID?
    var dayId: UUID?
    var planNameSnapshot: String
    var dayNameSnapshot: String
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int
    var sourceRawValue: String
    var statusRawValue: String
    @Relationship(deleteRule: .cascade) var setLogs: [WorkoutSetLogModel]
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(dto: WorkoutSessionDTO) {
        id = dto.id
        planId = dto.planId
        dayId = dto.dayId
        planNameSnapshot = dto.planNameSnapshot
        dayNameSnapshot = dto.dayNameSnapshot
        startedAt = dto.startedAt
        endedAt = dto.endedAt
        durationSeconds = dto.durationSeconds
        sourceRawValue = dto.source.rawValue
        statusRawValue = dto.status.rawValue
        setLogs = dto.setLogs.map { WorkoutSetLogModel(dto: $0) }
        notes = dto.notes
        createdAt = dto.createdAt
        updatedAt = dto.updatedAt
    }

    var source: WorkoutSource {
        get { WorkoutSource(rawValue: sourceRawValue) ?? .iphone }
        set { sourceRawValue = newValue.rawValue }
    }

    var status: WorkoutStatus {
        get { WorkoutStatus(rawValue: statusRawValue) ?? .completed }
        set { statusRawValue = newValue.rawValue }
    }

    func update(from dto: WorkoutSessionDTO) {
        planId = dto.planId
        dayId = dto.dayId
        planNameSnapshot = dto.planNameSnapshot
        dayNameSnapshot = dto.dayNameSnapshot
        startedAt = dto.startedAt
        endedAt = dto.endedAt
        durationSeconds = dto.durationSeconds
        source = dto.source
        status = dto.status
        setLogs = dto.setLogs.map { WorkoutSetLogModel(dto: $0) }
        notes = dto.notes
        createdAt = dto.createdAt
        updatedAt = dto.updatedAt
    }

    func toDTO() -> WorkoutSessionDTO {
        WorkoutSessionDTO(
            id: id,
            planId: planId,
            dayId: dayId,
            planNameSnapshot: planNameSnapshot,
            dayNameSnapshot: dayNameSnapshot,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            source: source,
            status: status,
            setLogs: setLogs.sorted { $0.completedAt < $1.completedAt }.map { $0.toDTO() },
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class WorkoutSetLogModel {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var exerciseId: UUID
    var workoutExerciseId: UUID?
    var exerciseNameSnapshot: String
    var setIndex: Int
    var isWarmup: Bool
    var targetReps: Int?
    var targetDurationSeconds: Int?
    var targetLoad: Double?
    var targetLoadUnitRawValue: String
    var completedReps: Int?
    var completedDurationSeconds: Int?
    var completedLoad: Double?
    var completedLoadUnitRawValue: String
    var restPlannedSeconds: Int
    var restActualSeconds: Int?
    var rpe: Double?
    var rir: Int?
    var notes: String
    var completedAt: Date

    init(dto: WorkoutSetLogDTO) {
        id = dto.id
        sessionId = dto.sessionId
        exerciseId = dto.exerciseId
        workoutExerciseId = dto.workoutExerciseId
        exerciseNameSnapshot = dto.exerciseNameSnapshot
        setIndex = dto.setIndex
        isWarmup = dto.isWarmup
        targetReps = dto.targetReps
        targetDurationSeconds = dto.targetDurationSeconds
        targetLoad = dto.targetLoad
        targetLoadUnitRawValue = dto.targetLoadUnit.rawValue
        completedReps = dto.completedReps
        completedDurationSeconds = dto.completedDurationSeconds
        completedLoad = dto.completedLoad
        completedLoadUnitRawValue = dto.completedLoadUnit.rawValue
        restPlannedSeconds = dto.restPlannedSeconds
        restActualSeconds = dto.restActualSeconds
        rpe = dto.rpe
        rir = dto.rir
        notes = dto.notes
        completedAt = dto.completedAt
    }

    var targetLoadUnit: LoadUnit {
        get { LoadUnit(rawValue: targetLoadUnitRawValue) ?? .kg }
        set { targetLoadUnitRawValue = newValue.rawValue }
    }

    var completedLoadUnit: LoadUnit {
        get { LoadUnit(rawValue: completedLoadUnitRawValue) ?? .kg }
        set { completedLoadUnitRawValue = newValue.rawValue }
    }

    func toDTO() -> WorkoutSetLogDTO {
        WorkoutSetLogDTO(
            id: id,
            sessionId: sessionId,
            exerciseId: exerciseId,
            workoutExerciseId: workoutExerciseId,
            exerciseNameSnapshot: exerciseNameSnapshot,
            setIndex: setIndex,
            isWarmup: isWarmup,
            targetReps: targetReps,
            targetDurationSeconds: targetDurationSeconds,
            targetLoad: targetLoad,
            targetLoadUnit: targetLoadUnit,
            completedReps: completedReps,
            completedDurationSeconds: completedDurationSeconds,
            completedLoad: completedLoad,
            completedLoadUnit: completedLoadUnit,
            restPlannedSeconds: restPlannedSeconds,
            restActualSeconds: restActualSeconds,
            rpe: rpe,
            rir: rir,
            notes: notes,
            completedAt: completedAt
        )
    }
}
