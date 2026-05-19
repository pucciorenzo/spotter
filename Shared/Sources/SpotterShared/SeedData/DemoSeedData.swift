import Foundation

public enum DemoSeedData {
    public static let exercises: [ExerciseDTO] = [
        exercise("Bench Press", primary: "Chest", secondary: ["Triceps", "Shoulders"], equipment: .barbell),
        exercise("Squat", primary: "Quadriceps", secondary: ["Glutes", "Hamstrings"], equipment: .barbell),
        exercise("Deadlift", primary: "Posterior Chain", secondary: ["Back", "Hamstrings"], equipment: .barbell),
        exercise("Overhead Press", primary: "Shoulders", secondary: ["Triceps"], equipment: .barbell),
        exercise("Lat Pulldown", primary: "Back", secondary: ["Biceps"], equipment: .cable),
        exercise("Barbell Row", primary: "Back", secondary: ["Biceps"], equipment: .barbell),
        exercise("Dumbbell Curl", primary: "Biceps", secondary: [], equipment: .dumbbell),
        exercise("Triceps Pushdown", primary: "Triceps", secondary: [], equipment: .cable),
        exercise("Push-Up", primary: "Chest", secondary: ["Triceps", "Core"], equipment: .bodyweight, loadUnit: .bodyweight),
        exercise("Plank", primary: "Core", secondary: ["Shoulders"], equipment: .bodyweight, measurement: .duration, loadUnit: .bodyweight),
        exercise("Treadmill Run", primary: "Cardio", secondary: ["Legs"], category: .cardio, equipment: .cardioMachine, measurement: .duration, restSeconds: 60, loadUnit: .bodyweight)
    ]

    public static let plans: [WorkoutPlanDTO] = {
        let fullBodyPlanId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let upperLowerPlanId = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let quickTestPlanId = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!

        return [
            WorkoutPlanDTO(
                id: fullBodyPlanId,
                name: "Full Body 3 Days",
                description: "Simple three-day full body starter plan.",
                goal: "Build strength with repeatable compound sessions.",
                days: [
                    day(fullBodyPlanId, "Day A", 0, [
                        prescription("Bench Press", sets: 3, repsMin: 6, repsMax: 8, load: 60, rest: 150),
                        prescription("Squat", sets: 3, repsMin: 6, repsMax: 8, load: 80, rest: 180),
                        prescription("Barbell Row", sets: 3, repsMin: 8, repsMax: 10, load: 50, rest: 120)
                    ]),
                    day(fullBodyPlanId, "Day B", 1, [
                        prescription("Deadlift", sets: 3, repsMin: 5, repsMax: 6, load: 100, rest: 180),
                        prescription("Overhead Press", sets: 3, repsMin: 6, repsMax: 8, load: 40, rest: 150),
                        prescription("Lat Pulldown", sets: 3, repsMin: 10, repsMax: 12, load: 55, rest: 90)
                    ]),
                    day(fullBodyPlanId, "Day C", 2, [
                        prescription("Squat", sets: 3, repsMin: 8, repsMax: 10, load: 70, rest: 150),
                        prescription("Bench Press", sets: 3, repsMin: 8, repsMax: 10, load: 55, rest: 120),
                        prescription("Plank", sets: 3, duration: 45, load: nil, rest: 60)
                    ])
                ],
                isActive: true,
                isArchived: false,
                createdAt: referenceDate,
                updatedAt: referenceDate
            ),
            WorkoutPlanDTO(
                id: upperLowerPlanId,
                name: "Upper Lower 4 Days",
                description: "Four-day split with upper and lower body emphasis.",
                goal: "Accumulate weekly volume across repeatable sessions.",
                days: [
                    day(upperLowerPlanId, "Upper A", 0, [
                        prescription("Bench Press", sets: 4, repsMin: 6, repsMax: 8, load: 62.5, rest: 150),
                        prescription("Barbell Row", sets: 4, repsMin: 8, repsMax: 10, load: 52.5, rest: 120),
                        prescription("Triceps Pushdown", sets: 3, repsMin: 10, repsMax: 12, load: 25, rest: 75)
                    ]),
                    day(upperLowerPlanId, "Lower A", 1, [
                        prescription("Squat", sets: 4, repsMin: 5, repsMax: 7, load: 85, rest: 180),
                        prescription("Deadlift", sets: 2, repsMin: 5, repsMax: 6, load: 105, rest: 180),
                        prescription("Plank", sets: 3, duration: 60, load: nil, rest: 60)
                    ]),
                    day(upperLowerPlanId, "Upper B", 2, [
                        prescription("Overhead Press", sets: 4, repsMin: 6, repsMax: 8, load: 42.5, rest: 150),
                        prescription("Lat Pulldown", sets: 4, repsMin: 8, repsMax: 12, load: 57.5, rest: 90),
                        prescription("Dumbbell Curl", sets: 3, repsMin: 10, repsMax: 12, load: 12.5, rest: 75)
                    ]),
                    day(upperLowerPlanId, "Lower B", 3, [
                        prescription("Deadlift", sets: 3, repsMin: 4, repsMax: 6, load: 110, rest: 180),
                        prescription("Squat", sets: 3, repsMin: 8, repsMax: 10, load: 72.5, rest: 150),
                        prescription("Treadmill Run", sets: 1, duration: 900, load: nil, rest: 60)
                    ])
                ],
                isActive: true,
                isArchived: false,
                createdAt: referenceDate,
                updatedAt: referenceDate
            ),
            WorkoutPlanDTO(
                id: quickTestPlanId,
                name: "QA Quick Test",
                description: "Short mixed workout for testing set result entry, rest timers, skips, substitutions, and history edits.",
                goal: "Exercise the logging flow quickly.",
                days: [
                    day(quickTestPlanId, "Mixed Inputs", 0, [
                        prescription("Bench Press", sets: 2, repsMin: 5, repsMax: 8, load: 40, rest: 5),
                        prescription("Push-Up", sets: 2, repsMin: 8, repsMax: 12, load: nil, rest: 5),
                        prescription("Plank", sets: 2, duration: 10, load: nil, rest: 5),
                        prescription("Treadmill Run", sets: 1, duration: 15, load: nil, rest: 5)
                    ])
                ],
                isActive: true,
                isArchived: false,
                createdAt: referenceDate,
                updatedAt: referenceDate
            )
        ]
    }()

    private static let referenceDate = Date(timeIntervalSince1970: 1_735_689_600)

    private static func exercise(
        _ name: String,
        primary: String,
        secondary: [String],
        category: ExerciseCategory = .strength,
        equipment: EquipmentType,
        measurement: MeasurementType = .repetitions,
        restSeconds: Int = 120,
        loadUnit: LoadUnit = .kg
    ) -> ExerciseDTO {
        ExerciseDTO(
            id: stableId(for: "exercise-\(name)"),
            name: name,
            primaryMuscleGroup: primary,
            secondaryMuscleGroups: secondary,
            category: category,
            equipment: equipment,
            description: "",
            formCues: [],
            commonMistakes: [],
            videoURL: nil,
            notes: "",
            defaultMeasurementType: measurement,
            defaultRestSeconds: restSeconds,
            defaultLoadUnit: loadUnit,
            isUnilateral: false,
            isWarmup: false,
            isArchived: false,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }

    private static func day(_ planId: UUID, _ name: String, _ orderIndex: Int, _ exercises: [WorkoutExerciseDraft]) -> WorkoutDayDTO {
        let dayId = stableId(for: "day-\(planId.uuidString)-\(name)")
        return WorkoutDayDTO(
            id: dayId,
            planId: planId,
            name: name,
            orderIndex: orderIndex,
            notes: "",
            exercises: exercises.enumerated().map { index, draft in
                draft.makeDTO(dayId: dayId, orderIndex: index)
            }
        )
    }

    private static func prescription(
        _ exerciseName: String,
        sets: Int,
        repsMin: Int? = nil,
        repsMax: Int? = nil,
        duration: Int? = nil,
        load: Double?,
        rest: Int
    ) -> WorkoutExerciseDraft {
        WorkoutExerciseDraft(
            exerciseName: exerciseName,
            numberOfSets: sets,
            targetRepsMin: repsMin,
            targetRepsMax: repsMax,
            targetDurationSeconds: duration,
            startingLoad: load,
            restSeconds: rest
        )
    }

    private static func stableId(for value: String) -> UUID {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        let suffix = String(format: "%012llX", hash & 0xFFFFFFFFFFFF)
        return UUID(uuidString: "20000000-0000-0000-0000-\(suffix)")!
    }

    fileprivate static func stableSeedId(for value: String) -> UUID {
        stableId(for: value)
    }
}

private struct WorkoutExerciseDraft {
    var exerciseName: String
    var numberOfSets: Int
    var targetRepsMin: Int?
    var targetRepsMax: Int?
    var targetDurationSeconds: Int?
    var startingLoad: Double?
    var restSeconds: Int

    func makeDTO(dayId: UUID, orderIndex: Int) -> WorkoutExerciseDTO {
        WorkoutExerciseDTO(
            id: DemoSeedData.stableSeedId(for: "workout-exercise-\(dayId.uuidString)-\(exerciseName)-\(orderIndex)"),
            workoutDayId: dayId,
            exerciseId: DemoSeedData.exercises.first(where: { $0.name == exerciseName })?.id ?? DemoSeedData.stableSeedId(for: "exercise-\(exerciseName)"),
            orderIndex: orderIndex,
            numberOfSets: numberOfSets,
            warmupSets: 0,
            targetType: targetDurationSeconds == nil ? .repRange : .fixedDuration,
            targetReps: nil,
            targetRepsMin: targetRepsMin,
            targetRepsMax: targetRepsMax,
            targetDurationSeconds: targetDurationSeconds,
            targetDurationMinSeconds: nil,
            targetDurationMaxSeconds: nil,
            startingLoad: startingLoad,
            loadUnit: startingLoad == nil ? .bodyweight : .kg,
            suggestedIncrement: startingLoad == nil ? nil : 2.5,
            restSeconds: restSeconds,
            rpeTarget: nil,
            rirTarget: nil,
            tempo: nil,
            notes: "",
            supersetGroupId: nil,
            autoProgressionEnabled: true
        )
    }
}
