import Foundation
import SwiftUI

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
    func addSet(to exerciseId: UUID)
    func removeSet(_ setId: UUID, from exerciseId: UUID)
    func tickRest()
}

struct ActiveWorkoutSession: Identifiable {
    var id: UUID
    let planName: String
    let dayName: String
    var exercises: [ActiveWorkoutExercise]
    var currentExerciseId: UUID
    var currentSetId: UUID
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
    var previousPerformance: PreviousPerformanceSuggestion
    var sets: [ActiveWorkoutSet]
}

struct PreviousPerformanceSuggestion {
    let lastTime: String
    let trend: String
    let warning: String?
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
final class MockActiveWorkoutRepository: ActiveWorkoutProviding {
    @Published private(set) var session: ActiveWorkoutSession?

    init() {
        startMockWorkout()
    }

    func startMockWorkout() {
        let pullUp = ActiveWorkoutExercise(
            id: UUID(),
            name: "Pull-Up",
            nextNote: "Next: Chest-Supported Row",
            previousPerformance: PreviousPerformanceSuggestion(
                lastTime: "Last time: BW x 9, 8, 8",
                trend: "+1 rep available if first set feels sharp",
                warning: nil
            ),
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
            previousPerformance: PreviousPerformanceSuggestion(
                lastTime: "Last time: 34 kg x 10",
                trend: "same weight, +2 reps vs last week",
                warning: nil
            ),
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
            previousPerformance: PreviousPerformanceSuggestion(
                lastTime: "Last time: 45s, 45s, 40s",
                trend: "hold 45s before adding load",
                warning: nil
            ),
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
            restRemainingSeconds: 0,
            restStartedAt: nil,
            lastAutosavedAt: Date()
        )
    }

    func select(exerciseId: UUID, setId: UUID) {
        mutateSession { session in
            session.currentExerciseId = exerciseId
            session.currentSetId = setId
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
            session.restRemainingSeconds = session.exercises[indexes.exercise].sets[indexes.set].restSeconds
            session.restStartedAt = Date()
            advanceSelection(in: &session, after: indexes)
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
        guard session?.restStartedAt != nil else { return }
        mutateSession { session in
            session.restRemainingSeconds -= 1
        }
    }

    private func updateCurrentSet(_ update: (inout ActiveWorkoutSet) -> Void) {
        mutateSession { session in
            guard let indexes = currentIndexes(in: session) else { return }
            update(&session.exercises[indexes.exercise].sets[indexes.set])
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
}
