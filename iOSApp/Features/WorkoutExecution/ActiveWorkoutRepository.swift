import Foundation
import SwiftUI

@MainActor
protocol ActiveWorkoutProviding: ObservableObject {
    var session: ActiveWorkoutSession? { get }
    func startMockWorkout()
    func select(exerciseId: UUID, setId: UUID)
    func updateReps(_ reps: Int)
    func updateWeight(_ weight: Double)
    func updateDuration(_ seconds: Int)
    func updateRPE(_ rpe: Double?)
    func updateRIR(_ rir: Int?)
    func completeCurrentSet()
    func skipCurrentSet()
    func pauseWorkout()
    func resumeWorkout()
    func endWorkout()
    func discardWorkout()
    func addSet(to exerciseId: UUID)
    func removeSet(_ setId: UUID, from exerciseId: UUID)
    func tickRest()
    func applyPreviousSuggestion()
}

struct ActiveWorkoutSession: Identifiable {
    var id: UUID
    let planName: String
    let dayName: String
    var exercises: [ActiveWorkoutExercise]
    var currentExerciseId: UUID
    var currentSetId: UUID
    var isPaused: Bool
    var restDurationSeconds: Int
    var restRemainingSeconds: Int
    var restStartedAt: Date?
    var lastAutosavedAt: Date

    var currentExercise: ActiveWorkoutExercise? {
        exercises.first { $0.id == currentExerciseId }
    }

    var currentSet: ActiveWorkoutSet? {
        currentExercise?.sets.first { $0.id == currentSetId }
    }

    var nextExercise: ActiveWorkoutExercise? {
        guard let index = exercises.firstIndex(where: { $0.id == currentExerciseId }) else {
            return nil
        }
        return exercises.dropFirst(index + 1).first
    }

    var completedSetCount: Int {
        exercises.flatMap(\.sets).filter(\.isCompleted).count
    }

    var totalSetCount: Int {
        exercises.flatMap(\.sets).count
    }

    var progress: Double {
        guard totalSetCount > 0 else { return 0 }
        return Double(completedSetCount) / Double(totalSetCount)
    }

    var estimatedRemainingMinutes: Int {
        let remaining = exercises.flatMap(\.sets).filter { !$0.isCompleted && !$0.isSkipped }
        let seconds = remaining.reduce(0) { total, set in
            total + set.estimatedWorkSeconds + set.restSeconds
        }
        return max(1, seconds / 60)
    }
}

struct ActiveWorkoutExercise: Identifiable {
    let id: UUID
    var name: String
    var nextNote: String
    var previousPerformance: WorkoutLoggingSuggestion?
    var sets: [ActiveWorkoutSet]
}

struct WorkoutLoggingSuggestion: Identifiable {
    let id = UUID()
    let lastTime: String
    let trend: String
    let warning: String?
    let previousReps: Int?
    let previousWeight: Double?
    let previousDurationSeconds: Int?
    let previousRPE: Double?
    let previousRIR: Int?

    var reuseLabel: String {
        let effort = [
            previousRPE.map { "RPE \(format($0))" },
            previousRIR.map { "RIR \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " / ")

        let base: String
        if let previousDurationSeconds {
            base = "\(previousDurationSeconds)s"
        } else if let previousReps, let previousWeight {
            base = "\(format(previousWeight)) kg x \(previousReps)"
        } else if let previousReps {
            base = "\(previousReps) reps"
        } else if let previousWeight {
            base = "\(format(previousWeight)) kg"
        } else {
            base = "Previous"
        }

        return effort.isEmpty ? base : "\(base) · \(effort)"
    }

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}

struct ActiveWorkoutSet: Identifiable {
    enum SetKind {
        case repsWeight
        case duration
    }

    var id: UUID
    var index: Int
    var kind: SetKind
    var isWarmup: Bool
    var targetReps: ClosedRange<Int>?
    var targetWeight: Double?
    var targetDurationSeconds: Int?
    var reps: Int
    var weight: Double
    var durationSeconds: Int
    var rpe: Double?
    var rir: Int?
    var restSeconds: Int
    var isCompleted: Bool
    var isSkipped: Bool

    var estimatedWorkSeconds: Int {
        switch kind {
        case .duration:
            return max(durationSeconds, targetDurationSeconds ?? 45)
        case .repsWeight:
            return 45
        }
    }

    var targetText: String {
        switch kind {
        case .duration:
            return "\(targetDurationSeconds ?? durationSeconds)s"
        case .repsWeight:
            if let targetReps {
                return "\(targetReps.lowerBound)-\(targetReps.upperBound) reps"
            }
            return "\(reps) reps"
        }
    }

    var resultText: String {
        if isSkipped {
            return "Skipped"
        }
        switch kind {
        case .duration:
            return "\(durationSeconds)s"
        case .repsWeight:
            return "\(reps) x \(format(weight)) kg"
        }
    }

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}

@MainActor
protocol WorkoutHistorySuggestionProviding {
    func suggestion(for exerciseName: String, set: ActiveWorkoutSet) -> WorkoutLoggingSuggestion?
    func recordCompletedSet(exerciseName: String, set: ActiveWorkoutSet)
}

@MainActor
final class MockWorkoutHistorySuggestionRepository: WorkoutHistorySuggestionProviding {
    private struct HistorySet {
        let exerciseName: String
        let completedAt: Date
        let setIndex: Int
        let reps: Int?
        let weight: Double?
        let durationSeconds: Int?
        let rpe: Double?
        let rir: Int?
    }

    private var history: [HistorySet]

    init(now: Date = Date()) {
        history = [
            HistorySet(exerciseName: "Pull-Up", completedAt: now.addingTimeInterval(-5 * 86_400), setIndex: 1, reps: 9, weight: 0, durationSeconds: nil, rpe: 8, rir: 2),
            HistorySet(exerciseName: "Pull-Up", completedAt: now.addingTimeInterval(-5 * 86_400), setIndex: 2, reps: 8, weight: 0, durationSeconds: nil, rpe: 8.5, rir: 1),
            HistorySet(exerciseName: "Pull-Up", completedAt: now.addingTimeInterval(-5 * 86_400), setIndex: 3, reps: 8, weight: 0, durationSeconds: nil, rpe: 9, rir: 1),
            HistorySet(exerciseName: "Chest-Supported Row", completedAt: now.addingTimeInterval(-7 * 86_400), setIndex: 1, reps: 10, weight: 22, durationSeconds: nil, rpe: nil, rir: nil),
            HistorySet(exerciseName: "Chest-Supported Row", completedAt: now.addingTimeInterval(-7 * 86_400), setIndex: 2, reps: 10, weight: 34, durationSeconds: nil, rpe: 8, rir: 2),
            HistorySet(exerciseName: "Chest-Supported Row", completedAt: now.addingTimeInterval(-7 * 86_400), setIndex: 3, reps: 9, weight: 34, durationSeconds: nil, rpe: 8.5, rir: 1),
            HistorySet(exerciseName: "RKC Plank", completedAt: now.addingTimeInterval(-6 * 86_400), setIndex: 1, reps: nil, weight: nil, durationSeconds: 45, rpe: 7, rir: nil),
            HistorySet(exerciseName: "RKC Plank", completedAt: now.addingTimeInterval(-6 * 86_400), setIndex: 2, reps: nil, weight: nil, durationSeconds: 40, rpe: 8, rir: nil)
        ]
    }

    func suggestion(for exerciseName: String, set: ActiveWorkoutSet) -> WorkoutLoggingSuggestion? {
        let matches = history
            .filter { $0.exerciseName == exerciseName && $0.setIndex == set.index }
            .sorted { $0.completedAt > $1.completedAt }

        guard let latest = matches.first else {
            return nil
        }

        let previous = matches.dropFirst().first
        return WorkoutLoggingSuggestion(
            lastTime: "Last time: \(summary(for: latest))",
            trend: trend(latest: latest, previous: previous),
            warning: warning(for: set, latest: latest),
            previousReps: latest.reps,
            previousWeight: latest.weight,
            previousDurationSeconds: latest.durationSeconds,
            previousRPE: latest.rpe,
            previousRIR: latest.rir
        )
    }

    func recordCompletedSet(exerciseName: String, set: ActiveWorkoutSet) {
        history.append(
            HistorySet(
                exerciseName: exerciseName,
                completedAt: Date(),
                setIndex: set.index,
                reps: set.kind == .duration ? nil : set.reps,
                weight: set.kind == .duration ? nil : set.weight,
                durationSeconds: set.kind == .duration ? set.durationSeconds : nil,
                rpe: set.rpe,
                rir: set.rir
            )
        )
    }

    private func summary(for set: HistorySet) -> String {
        if let durationSeconds = set.durationSeconds {
            return "\(durationSeconds)s\(effortText(set))"
        }

        let repsText = set.reps.map { "\($0)" } ?? "-"
        if let weight = set.weight, weight > 0 {
            return "\(format(weight)) kg x \(repsText)\(effortText(set))"
        }

        return "BW x \(repsText)\(effortText(set))"
    }

    private func effortText(_ set: HistorySet) -> String {
        let values = [
            set.rpe.map { "RPE \(format($0))" },
            set.rir.map { "RIR \($0)" }
        ].compactMap { $0 }

        return values.isEmpty ? "" : " · \(values.joined(separator: " / "))"
    }

    private func trend(latest: HistorySet, previous: HistorySet?) -> String {
        guard let previous else {
            return "Tap to reuse previous values."
        }

        if let reps = latest.reps, let oldReps = previous.reps, latest.weight == previous.weight {
            let delta = reps - oldReps
            if delta > 0 { return "same weight, +\(delta) reps vs last time" }
            if delta < 0 { return "same weight, \(delta) reps vs last time" }
            return "same weight and reps as last time"
        }

        if let duration = latest.durationSeconds, let oldDuration = previous.durationSeconds {
            let delta = duration - oldDuration
            if delta > 0 { return "+\(delta)s vs last time" }
            if delta < 0 { return "\(delta)s vs last time" }
            return "same duration as last time"
        }

        return "Tap to reuse previous values."
    }

    private func warning(for set: ActiveWorkoutSet, latest: HistorySet) -> String? {
        guard let latestWeight = latest.weight, latestWeight > 0 else { return nil }
        let difference = abs(set.weight - latestWeight)
        return difference >= max(10, latestWeight * 0.25) ? "Large change from last time." : nil
    }

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}

@MainActor
final class MockActiveWorkoutRepository: ActiveWorkoutProviding {
    @Published private(set) var session: ActiveWorkoutSession?
    private let historyRepository: WorkoutHistorySuggestionProviding

    init(historyRepository: WorkoutHistorySuggestionProviding? = nil) {
        self.historyRepository = historyRepository ?? MockWorkoutHistorySuggestionRepository()
        startMockWorkout()
    }

    func startMockWorkout() {
        let pullUp = ActiveWorkoutExercise(
            id: UUID(),
            name: "Pull-Up",
            nextNote: "Next: Chest-Supported Row",
            previousPerformance: nil,
            sets: [
                ActiveWorkoutSet(id: UUID(), index: 1, kind: .repsWeight, isWarmup: true, targetReps: 5...6, targetWeight: 0, targetDurationSeconds: nil, reps: 6, weight: 0, durationSeconds: 0, rpe: nil, rir: nil, restSeconds: 60, isCompleted: false, isSkipped: false),
                ActiveWorkoutSet(id: UUID(), index: 2, kind: .repsWeight, isWarmup: false, targetReps: 6...10, targetWeight: 0, targetDurationSeconds: nil, reps: 8, weight: 0, durationSeconds: 0, rpe: 8, rir: 2, restSeconds: 120, isCompleted: false, isSkipped: false),
                ActiveWorkoutSet(id: UUID(), index: 3, kind: .repsWeight, isWarmup: false, targetReps: 6...10, targetWeight: 0, targetDurationSeconds: nil, reps: 8, weight: 0, durationSeconds: 0, rpe: 8, rir: 2, restSeconds: 120, isCompleted: false, isSkipped: false)
            ]
        )

        let row = ActiveWorkoutExercise(
            id: UUID(),
            name: "Chest-Supported Row",
            nextNote: "Next: Lat Pulldown",
            previousPerformance: nil,
            sets: [
                ActiveWorkoutSet(id: UUID(), index: 1, kind: .repsWeight, isWarmup: true, targetReps: 10...12, targetWeight: 22, targetDurationSeconds: nil, reps: 10, weight: 22, durationSeconds: 0, rpe: nil, rir: nil, restSeconds: 60, isCompleted: false, isSkipped: false),
                ActiveWorkoutSet(id: UUID(), index: 2, kind: .repsWeight, isWarmup: false, targetReps: 8...10, targetWeight: 34, targetDurationSeconds: nil, reps: 10, weight: 34, durationSeconds: 0, rpe: 8, rir: 2, restSeconds: 120, isCompleted: false, isSkipped: false),
                ActiveWorkoutSet(id: UUID(), index: 3, kind: .repsWeight, isWarmup: false, targetReps: 8...10, targetWeight: 34, targetDurationSeconds: nil, reps: 9, weight: 34, durationSeconds: 0, rpe: 8.5, rir: 1, restSeconds: 120, isCompleted: false, isSkipped: false)
            ]
        )

        let plank = ActiveWorkoutExercise(
            id: UUID(),
            name: "RKC Plank",
            nextNote: "Finish strong",
            previousPerformance: nil,
            sets: [
                ActiveWorkoutSet(id: UUID(), index: 1, kind: .duration, isWarmup: false, targetReps: nil, targetWeight: nil, targetDurationSeconds: 45, reps: 0, weight: 0, durationSeconds: 45, rpe: 7, rir: nil, restSeconds: 75, isCompleted: false, isSkipped: false),
                ActiveWorkoutSet(id: UUID(), index: 2, kind: .duration, isWarmup: false, targetReps: nil, targetWeight: nil, targetDurationSeconds: 45, reps: 0, weight: 0, durationSeconds: 45, rpe: 8, rir: nil, restSeconds: 75, isCompleted: false, isSkipped: false)
            ]
        )

        session = ActiveWorkoutSession(
            id: UUID(),
            planName: "Push Pull Legs",
            dayName: "Pull Day",
            exercises: [pullUp, row, plank],
            currentExerciseId: pullUp.id,
            currentSetId: pullUp.sets[0].id,
            isPaused: false,
            restDurationSeconds: 0,
            restRemainingSeconds: 0,
            restStartedAt: nil,
            lastAutosavedAt: Date()
        )
        refreshSuggestions()
    }

    func select(exerciseId: UUID, setId: UUID) {
        mutateSession { session in
            session.currentExerciseId = exerciseId
            session.currentSetId = setId
            refreshSuggestions(in: &session)
        }
    }

    func updateReps(_ reps: Int) {
        updateCurrentSet { $0.reps = max(0, reps) }
    }

    func updateWeight(_ weight: Double) {
        updateCurrentSet { $0.weight = max(0, weight) }
    }

    func updateDuration(_ seconds: Int) {
        updateCurrentSet { $0.durationSeconds = max(0, seconds) }
    }

    func updateRPE(_ rpe: Double?) {
        updateCurrentSet { $0.rpe = rpe.map { min(max($0, 1), 10) } }
    }

    func updateRIR(_ rir: Int?) {
        updateCurrentSet { $0.rir = rir.map { min(max($0, 0), 10) } }
    }

    func completeCurrentSet() {
        mutateSession { session in
            guard let indexes = currentIndexes(in: session) else { return }
            session.exercises[indexes.exercise].sets[indexes.set].isCompleted = true
            session.exercises[indexes.exercise].sets[indexes.set].isSkipped = false
            historyRepository.recordCompletedSet(
                exerciseName: session.exercises[indexes.exercise].name,
                set: session.exercises[indexes.exercise].sets[indexes.set]
            )
            let restSeconds = session.exercises[indexes.exercise].sets[indexes.set].restSeconds
            session.restDurationSeconds = restSeconds
            session.restRemainingSeconds = restSeconds
            session.restStartedAt = Date()
            refreshSuggestions(in: &session)
            advanceSelection(in: &session, after: indexes)
        }
    }

    func applyPreviousSuggestion() {
        mutateSession { session in
            guard let indexes = currentIndexes(in: session),
                  let suggestion = session.exercises[indexes.exercise].previousPerformance else {
                return
            }

            if let reps = suggestion.previousReps {
                session.exercises[indexes.exercise].sets[indexes.set].reps = reps
            }
            if let weight = suggestion.previousWeight {
                session.exercises[indexes.exercise].sets[indexes.set].weight = weight
            }
            if let duration = suggestion.previousDurationSeconds {
                session.exercises[indexes.exercise].sets[indexes.set].durationSeconds = duration
            }
            session.exercises[indexes.exercise].sets[indexes.set].rpe = suggestion.previousRPE
            session.exercises[indexes.exercise].sets[indexes.set].rir = suggestion.previousRIR
        }
    }

    func skipCurrentSet() {
        mutateSession { session in
            guard let indexes = currentIndexes(in: session) else { return }
            session.exercises[indexes.exercise].sets[indexes.set].isSkipped = true
            session.exercises[indexes.exercise].sets[indexes.set].isCompleted = false
            advanceSelection(in: &session, after: indexes)
        }
    }

    func pauseWorkout() {
        mutateSession { session in
            session.isPaused = true
        }
    }

    func resumeWorkout() {
        mutateSession { session in
            if session.restStartedAt != nil {
                let elapsedBeforePause = max(0, session.restDurationSeconds - session.restRemainingSeconds)
                session.restStartedAt = Date().addingTimeInterval(TimeInterval(-elapsedBeforePause))
            }
            session.isPaused = false
        }
    }

    func endWorkout() {
        session = nil
    }

    func discardWorkout() {
        session = nil
    }

    func addSet(to exerciseId: UUID) {
        mutateSession { session in
            guard let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseId }),
                  let template = session.exercises[exerciseIndex].sets.last else {
                return
            }
            var newSet = template
            newSet.id = UUID()
            newSet.index = session.exercises[exerciseIndex].sets.count + 1
            newSet.isCompleted = false
            newSet.isSkipped = false
            session.exercises[exerciseIndex].sets.append(newSet)
        }
    }

    func removeSet(_ setId: UUID, from exerciseId: UUID) {
        mutateSession { session in
            guard let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseId }),
                  session.exercises[exerciseIndex].sets.count > 1 else {
                return
            }
            session.exercises[exerciseIndex].sets.removeAll { $0.id == setId }
            for index in session.exercises[exerciseIndex].sets.indices {
                session.exercises[exerciseIndex].sets[index].index = index + 1
            }
            if session.currentSetId == setId, let first = session.exercises[exerciseIndex].sets.first {
                session.currentExerciseId = exerciseId
                session.currentSetId = first.id
            }
        }
    }

    func tickRest() {
        guard session?.restStartedAt != nil, session?.isPaused == false else { return }
        mutateSession { session in
            guard let restStartedAt = session.restStartedAt else { return }
            let elapsedSeconds = max(0, Int(Date().timeIntervalSince(restStartedAt)))
            session.restRemainingSeconds = session.restDurationSeconds - elapsedSeconds
        }
    }

    private func updateCurrentSet(_ update: (inout ActiveWorkoutSet) -> Void) {
        mutateSession { session in
            guard let indexes = currentIndexes(in: session) else { return }
            update(&session.exercises[indexes.exercise].sets[indexes.set])
            refreshSuggestions(in: &session)
        }
    }

    private func mutateSession(_ update: (inout ActiveWorkoutSession) -> Void) {
        guard var session else { return }
        update(&session)
        session.lastAutosavedAt = Date()
        self.session = session
    }

    private func currentIndexes(in session: ActiveWorkoutSession) -> (exercise: Int, set: Int)? {
        guard let exerciseIndex = session.exercises.firstIndex(where: { $0.id == session.currentExerciseId }),
              let setIndex = session.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == session.currentSetId }) else {
            return nil
        }
        return (exerciseIndex, setIndex)
    }

    private func advanceSelection(in session: inout ActiveWorkoutSession, after indexes: (exercise: Int, set: Int)) {
        for exerciseIndex in indexes.exercise..<session.exercises.count {
            let startSetIndex = exerciseIndex == indexes.exercise ? indexes.set + 1 : 0
            for setIndex in startSetIndex..<session.exercises[exerciseIndex].sets.count {
                let set = session.exercises[exerciseIndex].sets[setIndex]
                if !set.isCompleted && !set.isSkipped {
                    session.currentExerciseId = session.exercises[exerciseIndex].id
                    session.currentSetId = set.id
                    return
                }
            }
        }
    }

    private func refreshSuggestions() {
        guard var session else { return }
        refreshSuggestions(in: &session)
        self.session = session
    }

    private func refreshSuggestions(in session: inout ActiveWorkoutSession) {
        for exerciseIndex in session.exercises.indices {
            let currentSet = session.exercises[exerciseIndex].id == session.currentExerciseId
                ? session.exercises[exerciseIndex].sets.first { $0.id == session.currentSetId }
                : nil
            guard let activeSet = currentSet ?? session.exercises[exerciseIndex].sets.first(where: { !$0.isCompleted && !$0.isSkipped }) else {
                session.exercises[exerciseIndex].previousPerformance = nil
                continue
            }
            session.exercises[exerciseIndex].previousPerformance = historyRepository.suggestion(
                for: session.exercises[exerciseIndex].name,
                set: activeSet
            )
        }
    }
}
