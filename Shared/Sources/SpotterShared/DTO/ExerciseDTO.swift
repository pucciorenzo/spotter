import Foundation

public struct ExerciseDTO: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var primaryMuscleGroup: String
    public var secondaryMuscleGroups: [String]
    public var category: ExerciseCategory
    public var equipment: EquipmentType
    public var description: String
    public var formCues: [String]
    public var commonMistakes: [String]
    public var videoURL: URL?
    public var notes: String
    public var defaultMeasurementType: MeasurementType
    public var defaultRestSeconds: Int
    public var defaultLoadUnit: LoadUnit
    public var isUnilateral: Bool
    public var isWarmup: Bool
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        name: String,
        primaryMuscleGroup: String,
        secondaryMuscleGroups: [String],
        category: ExerciseCategory,
        equipment: EquipmentType,
        description: String,
        formCues: [String],
        commonMistakes: [String],
        videoURL: URL?,
        notes: String,
        defaultMeasurementType: MeasurementType,
        defaultRestSeconds: Int,
        defaultLoadUnit: LoadUnit,
        isUnilateral: Bool,
        isWarmup: Bool,
        isArchived: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.primaryMuscleGroup = primaryMuscleGroup
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.category = category
        self.equipment = equipment
        self.description = description
        self.formCues = formCues
        self.commonMistakes = commonMistakes
        self.videoURL = videoURL
        self.notes = notes
        self.defaultMeasurementType = defaultMeasurementType
        self.defaultRestSeconds = defaultRestSeconds
        self.defaultLoadUnit = defaultLoadUnit
        self.isUnilateral = isUnilateral
        self.isWarmup = isWarmup
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
