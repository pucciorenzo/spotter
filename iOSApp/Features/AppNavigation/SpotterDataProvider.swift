import Foundation

protocol SpotterDataProviding {
    var today: SpotterTodaySnapshot { get }
    var plans: [SpotterPlanSummary] { get }
    var exercises: [SpotterExerciseSummary] { get }
    var progress: SpotterProgressSnapshot { get }
    var profile: SpotterProfileSnapshot { get }
}

struct SpotterTodaySnapshot {
    let greeting: String
    let status: String
    let sessionsThisWeek: Int
    let lastWorkout: String
    let recoveryStatus: String
    let suggestedWorkout: SpotterSuggestedWorkout?
    let recentWorkouts: [SpotterRecentWorkout]
    let metrics: [SpotterMetric]
    let activeWorkout: SpotterActiveWorkout?
}

struct SpotterSuggestedWorkout: Identifiable {
    let id: UUID
    let planName: String
    let dayName: String
    let dayPosition: String
    let exerciseCount: Int
    let estimatedDuration: String
    let firstExercises: [String]
}

struct SpotterActiveWorkout: Identifiable {
    let id: UUID
    let title: String
    let detail: String
}

struct SpotterRecentWorkout: Identifiable {
    let id: UUID
    let name: String
    let dateText: String
    let duration: String
    let volume: String
}

struct SpotterMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let caption: String
    let systemImage: String
}

struct SpotterPlanSummary: Identifiable {
    let id: UUID
    let name: String
    let days: [SpotterPlanDaySummary]
    let lastUsed: String
    let suggestedDay: String
    let isActive: Bool
}

struct SpotterPlanDaySummary: Identifiable {
    let id: UUID
    let name: String
    let focus: String
    let exerciseCount: Int
    let estimatedDuration: String
    let exercises: [SpotterPlannedExerciseSummary]
}

struct SpotterPlannedExerciseSummary: Identifiable {
    let id: UUID
    let name: String
    let target: String
    let load: String
    let rest: String
}

struct SpotterExerciseSummary: Identifiable {
    let id: UUID
    let name: String
    let primaryCategory: String
    let secondaryCategories: [String]
    let equipment: String
    let movementPattern: String
    let trackingType: String
    let notes: String
}

struct SpotterProgressSnapshot {
    let headlineMetrics: [SpotterMetric]
    let exerciseTrends: [SpotterExerciseTrend]
    let planTrend: SpotterPlanTrend
}

struct SpotterExerciseTrend: Identifiable {
    let id: UUID
    let exerciseName: String
    let bestSet: String
    let totalVolume: String
    let frequency: String
    let trend: String
}

struct SpotterPlanTrend {
    let planName: String
    let completedSessions: String
    let averageDuration: String
    let consistency: String
    let distribution: [SpotterMetric]
}

struct SpotterProfileSnapshot {
    let weightUnit: String
    let distanceUnit: String
    let healthStatus: String
    let privacyMessage: String
    let appVersion: String
}

struct MockSpotterRepository: SpotterDataProviding {
    let today: SpotterTodaySnapshot
    let plans: [SpotterPlanSummary]
    let exercises: [SpotterExerciseSummary]
    let progress: SpotterProgressSnapshot
    let profile: SpotterProfileSnapshot

    static let preview = MockSpotterRepository()

    init() {
        let benchId = UUID()
        let squatId = UUID()
        let rowId = UUID()
        let pullupId = UUID()
        let rdlId = UUID()
        let pressId = UUID()

        exercises = [
            SpotterExerciseSummary(
                id: benchId,
                name: "Bench Press",
                primaryCategory: "Chest",
                secondaryCategories: ["Triceps", "Front Delts"],
                equipment: "Barbell",
                movementPattern: "Horizontal Push",
                trackingType: "Reps + Weight",
                notes: "Use a controlled pause when shoulder comfort allows."
            ),
            SpotterExerciseSummary(
                id: squatId,
                name: "Back Squat",
                primaryCategory: "Quads",
                secondaryCategories: ["Glutes", "Core"],
                equipment: "Barbell",
                movementPattern: "Squat",
                trackingType: "Reps + Weight",
                notes: "Keep warmups conservative before heavy work."
            ),
            SpotterExerciseSummary(
                id: rowId,
                name: "Chest-Supported Row",
                primaryCategory: "Back",
                secondaryCategories: ["Rear Delts", "Biceps"],
                equipment: "Dumbbell",
                movementPattern: "Horizontal Pull",
                trackingType: "Reps + Weight",
                notes: "Pause briefly with the handles close to the torso."
            ),
            SpotterExerciseSummary(
                id: pullupId,
                name: "Pull-Up",
                primaryCategory: "Lats",
                secondaryCategories: ["Biceps"],
                equipment: "Bodyweight",
                movementPattern: "Vertical Pull",
                trackingType: "Bodyweight Reps",
                notes: "Add assistance or load based on daily readiness."
            ),
            SpotterExerciseSummary(
                id: rdlId,
                name: "Romanian Deadlift",
                primaryCategory: "Hamstrings",
                secondaryCategories: ["Glutes", "Back"],
                equipment: "Barbell",
                movementPattern: "Hinge",
                trackingType: "Reps + Weight",
                notes: "Stop the range when bracing or hamstring tension changes."
            ),
            SpotterExerciseSummary(
                id: pressId,
                name: "Overhead Press",
                primaryCategory: "Shoulders",
                secondaryCategories: ["Triceps"],
                equipment: "Barbell",
                movementPattern: "Vertical Push",
                trackingType: "Reps + Weight",
                notes: "Use small jumps and keep reps crisp."
            ),
        ]

        let pushDay = SpotterPlanDaySummary(
            id: UUID(),
            name: "Push Day",
            focus: "Chest, shoulders, triceps",
            exerciseCount: 4,
            estimatedDuration: "56 min",
            exercises: [
                SpotterPlannedExerciseSummary(id: UUID(), name: "Bench Press", target: "4 sets x 6-8 reps", load: "80 kg", rest: "150s"),
                SpotterPlannedExerciseSummary(id: UUID(), name: "Overhead Press", target: "3 sets x 6-8 reps", load: "45 kg", rest: "120s"),
                SpotterPlannedExerciseSummary(id: UUID(), name: "Incline Dumbbell Press", target: "3 sets x 8-10 reps", load: "28 kg", rest: "90s"),
                SpotterPlannedExerciseSummary(id: UUID(), name: "Cable Pressdown", target: "3 sets x 10-12 reps", load: "32 kg", rest: "75s"),
            ]
        )

        let pullDay = SpotterPlanDaySummary(
            id: UUID(),
            name: "Pull Day",
            focus: "Back and biceps",
            exerciseCount: 4,
            estimatedDuration: "52 min",
            exercises: [
                SpotterPlannedExerciseSummary(id: UUID(), name: "Pull-Up", target: "4 sets x 6-10 reps", load: "Bodyweight", rest: "120s"),
                SpotterPlannedExerciseSummary(id: UUID(), name: "Chest-Supported Row", target: "3 sets x 8-10 reps", load: "34 kg", rest: "120s"),
                SpotterPlannedExerciseSummary(id: UUID(), name: "Lat Pulldown", target: "3 sets x 10-12 reps", load: "68 kg", rest: "90s"),
                SpotterPlannedExerciseSummary(id: UUID(), name: "Hammer Curl", target: "3 sets x 10-12 reps", load: "18 kg", rest: "75s"),
            ]
        )

        let legsDay = SpotterPlanDaySummary(
            id: UUID(),
            name: "Legs Day",
            focus: "Squat and hinge",
            exerciseCount: 5,
            estimatedDuration: "64 min",
            exercises: [
                SpotterPlannedExerciseSummary(id: UUID(), name: "Back Squat", target: "4 sets x 5-7 reps", load: "120 kg", rest: "180s"),
                SpotterPlannedExerciseSummary(id: UUID(), name: "Romanian Deadlift", target: "3 sets x 8 reps", load: "105 kg", rest: "150s"),
                SpotterPlannedExerciseSummary(id: UUID(), name: "Leg Press", target: "3 sets x 10-12 reps", load: "180 kg", rest: "120s"),
                SpotterPlannedExerciseSummary(id: UUID(), name: "Seated Calf Raise", target: "4 sets x 12-15 reps", load: "50 kg", rest: "60s"),
            ]
        )

        plans = [
            SpotterPlanSummary(
                id: UUID(),
                name: "Push Pull Legs",
                days: [pushDay, pullDay, legsDay],
                lastUsed: "Yesterday",
                suggestedDay: "Day 2 of 3: Pull Day",
                isActive: true
            ),
            SpotterPlanSummary(
                id: UUID(),
                name: "Upper Lower Strength",
                days: [
                    SpotterPlanDaySummary(id: UUID(), name: "Upper", focus: "Heavy press and row", exerciseCount: 5, estimatedDuration: "58 min", exercises: []),
                    SpotterPlanDaySummary(id: UUID(), name: "Lower", focus: "Squat, hinge, calves", exerciseCount: 5, estimatedDuration: "62 min", exercises: []),
                ],
                lastUsed: "Apr 28",
                suggestedDay: "Upper",
                isActive: false
            ),
        ]

        today = SpotterTodaySnapshot(
            greeting: "Today",
            status: "Ready for Pull Day?",
            sessionsThisWeek: 3,
            lastWorkout: "Push Day yesterday",
            recoveryStatus: "Rested",
            suggestedWorkout: SpotterSuggestedWorkout(
                id: UUID(),
                planName: "Push Pull Legs",
                dayName: "Pull Day",
                dayPosition: "Day 2 of 3",
                exerciseCount: 4,
                estimatedDuration: "52 min",
                firstExercises: ["Pull-Up", "Chest-Supported Row", "Lat Pulldown"]
            ),
            recentWorkouts: [
                SpotterRecentWorkout(id: UUID(), name: "Push Day", dateText: "Yesterday", duration: "54 min", volume: "8.4k kg"),
                SpotterRecentWorkout(id: UUID(), name: "Legs Day", dateText: "Sat", duration: "66 min", volume: "12.1k kg"),
                SpotterRecentWorkout(id: UUID(), name: "Pull Day", dateText: "Thu", duration: "51 min", volume: "7.9k kg"),
            ],
            metrics: [
                SpotterMetric(title: "Week", value: "3", caption: "sessions", systemImage: "calendar"),
                SpotterMetric(title: "Volume", value: "28.4k", caption: "kg logged", systemImage: "chart.bar.fill"),
                SpotterMetric(title: "Consistency", value: "86%", caption: "4 week pace", systemImage: "flame.fill"),
            ],
            activeWorkout: nil
        )

        progress = SpotterProgressSnapshot(
            headlineMetrics: [
                SpotterMetric(title: "Sessions", value: "14", caption: "last 30 days", systemImage: "checkmark.circle.fill"),
                SpotterMetric(title: "Avg Time", value: "57m", caption: "per workout", systemImage: "timer"),
                SpotterMetric(title: "Volume", value: "112k", caption: "kg last 30 days", systemImage: "chart.bar.fill"),
            ],
            exerciseTrends: [
                SpotterExerciseTrend(id: UUID(), exerciseName: "Bench Press", bestSet: "82.5 kg x 8", totalVolume: "14.8k kg", frequency: "6 sessions", trend: "+2 reps vs last time"),
                SpotterExerciseTrend(id: UUID(), exerciseName: "Back Squat", bestSet: "125 kg x 5", totalVolume: "18.2k kg", frequency: "5 sessions", trend: "same load, cleaner sets"),
                SpotterExerciseTrend(id: UUID(), exerciseName: "Pull-Up", bestSet: "BW x 10", totalVolume: "86 reps", frequency: "7 sessions", trend: "+1 rep"),
            ],
            planTrend: SpotterPlanTrend(
                planName: "Push Pull Legs",
                completedSessions: "12 sessions",
                averageDuration: "58 min",
                consistency: "4.2 per week",
                distribution: [
                    SpotterMetric(title: "Push", value: "34%", caption: "sets", systemImage: "arrow.up.right"),
                    SpotterMetric(title: "Pull", value: "32%", caption: "sets", systemImage: "arrow.down.left"),
                    SpotterMetric(title: "Legs", value: "34%", caption: "sets", systemImage: "figure.run"),
                ]
            )
        )

        profile = SpotterProfileSnapshot(
            weightUnit: "kg",
            distanceUnit: "metric",
            healthStatus: "Not Connected",
            privacyMessage: "No account required. Training data stays local by default.",
            appVersion: "Spotter 1.0"
        )
    }
}
