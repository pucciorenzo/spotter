import Combine
import Foundation
import SpotterShared
import WatchKit

@MainActor
final class WatchWorkoutViewModel: ObservableObject {
    @Published private(set) var state: WorkoutExecutionState
    @Published private(set) var didFinish = false
    @Published var repsValue: Double = 0
    @Published var durationValue: Double = 0
    @Published var loadValue: Double = 0
    @Published var errorMessage: String?

    private let plan: WorkoutPlanDTO
    private let day: WorkoutDayDTO
    private let cacheStore: WatchCacheStore
    private var snapshot: SyncSnapshot?

    init(
        plan: WorkoutPlanDTO,
        day: WorkoutDayDTO,
        cacheStore: WatchCacheStore = WatchCacheStore()
    ) {
        self.plan = plan
        self.day = day
        self.cacheStore = cacheStore

        if let activeState = cacheStore.loadActiveWorkout(),
           activeState.session.status == .inProgress,
           activeState.session.planId == plan.id,
           activeState.session.dayId == day.id {
            state = activeState
        } else {
            state = WorkoutExecutionEngine.start(plan: plan, day: day)
            try? cacheStore.saveActiveWorkout(state)
        }

        loadCurrentTargets()
    }

    var currentExercise: WorkoutExerciseDTO? {
        let exercises = WorkoutExecutionEngine.orderedExercises(in: day, state: state)
        guard exercises.indices.contains(state.currentExerciseIndex) else {
            return nil
        }

        return exercises[state.currentExerciseIndex]
    }

    var currentExerciseName: String {
        guard let currentExercise else {
            return "Complete"
        }

        if let substitution = state.substitutions.first(where: { $0.workoutExerciseId == currentExercise.id }) {
            return substitution.replacementExerciseName
        }

        return exerciseName(for: currentExercise.exerciseId)
    }

    var currentSubstitutionText: String? {
        guard let currentExercise,
              let substitution = state.substitutions.first(where: { $0.workoutExerciseId == currentExercise.id }) else {
            return nil
        }

        return "Replaces \(exerciseName(for: substitution.originalExerciseId))"
    }

    var completedSetCount: Int {
        guard let currentExercise else {
            return 0
        }

        return WorkoutExecutionEngine.completedSetCount(for: currentExercise, in: state)
    }

    var totalSetCount: Int {
        guard let currentExercise else {
            return 0
        }

        return WorkoutExecutionEngine.totalSetCount(for: currentExercise)
    }

    var nextSetNumber: Int {
        min(completedSetCount + 1, max(totalSetCount, 1))
    }

    var isCurrentSetWarmup: Bool {
        guard let currentExercise else {
            return false
        }

        return nextSetNumber <= currentExercise.warmupSets
    }

    var usesDuration: Bool {
        guard let currentExercise else {
            return false
        }

        return currentExercise.targetType == .fixedDuration || currentExercise.targetType == .durationRange
    }

    var canCompleteSet: Bool {
        currentExercise != nil && !isWorkoutComplete
    }

    var canMoveCurrentExerciseUp: Bool {
        state.currentExerciseIndex > 0
    }

    var canMoveCurrentExerciseDown: Bool {
        state.currentExerciseIndex < WorkoutExecutionEngine.orderedExercises(in: day, state: state).count - 1
    }

    var replacementExercises: [ExerciseDTO] {
        guard let snapshot,
              let currentExercise else {
            return []
        }

        return snapshot.exercises
            .filter { !$0.isArchived && $0.id != effectiveExerciseId(for: currentExercise) }
            .sorted { $0.name < $1.name }
    }

    var isWorkoutComplete: Bool {
        WorkoutExecutionEngine.nextIncompleteExerciseIndex(in: day, state: state) == nil
    }

    func configure(snapshot: SyncSnapshot?) {
        self.snapshot = snapshot
    }

    func completeCurrentSet() {
        guard let exercise = currentExercise else {
            return
        }

        let completedReps = usesDuration ? nil : Int(repsValue)
        let completedDuration = usesDuration ? Int(durationValue) : nil
        let completedLoad = exercise.loadUnit == .bodyweight ? nil : loadValue

        WorkoutExecutionEngine.appendCompletedSet(
            to: &state,
            day: day,
            exercise: exercise,
            exerciseName: exerciseName(for: exercise.exerciseId),
            completedReps: completedReps,
            completedDurationSeconds: completedDuration,
            completedLoad: completedLoad
        )

        saveActiveWorkout()
        loadCurrentTargets()
    }

    func skipCurrentSet() {
        guard let exercise = currentExercise else {
            return
        }

        WorkoutExecutionEngine.appendSkippedSet(
            to: &state,
            day: day,
            exercise: exercise,
            exerciseName: currentExerciseName,
            reason: "Skipped set"
        )

        saveActiveWorkout()
        loadCurrentTargets()
    }

    func skipCurrentExercise() {
        guard let exercise = currentExercise else {
            return
        }

        WorkoutExecutionEngine.skipExercise(
            in: &state,
            day: day,
            exercise: exercise,
            exerciseName: currentExerciseName
        )

        saveActiveWorkout()
        loadCurrentTargets()
    }

    func moveCurrentExerciseUp() {
        moveCurrentExercise(by: -1)
    }

    func moveCurrentExerciseDown() {
        moveCurrentExercise(by: 1)
    }

    func substituteCurrentExercise(with replacement: ExerciseDTO) {
        guard let exercise = currentExercise else {
            return
        }

        WorkoutExecutionEngine.substituteExercise(
            in: &state,
            workoutExercise: exercise,
            replacementExercise: replacement
        )

        saveActiveWorkout()
    }

    func finishWorkout() {
        WorkoutExecutionEngine.finish(&state)

        do {
            try cacheStore.enqueueCompletedWorkout(state.session)
            try cacheStore.clearActiveWorkout()
            didFinish = true
        } catch {
            errorMessage = "Unable to finish workout."
        }
    }

    func cancelWorkout() {
        WorkoutExecutionEngine.cancel(&state)

        do {
            try cacheStore.clearActiveWorkout()
            didFinish = true
        } catch {
            errorMessage = "Unable to cancel workout."
        }
    }

    func tickRest(at date: Date = Date()) {
        guard let rest = state.rest,
              let remainingSeconds = restRemainingSeconds(at: date),
              rest.plannedSeconds > 0,
              remainingSeconds <= 0,
              !rest.completionHapticSent else {
            return
        }

        WKInterfaceDevice.current().play(.notification)
        state.rest?.completionHapticSent = true
        saveActiveWorkout()
    }

    func restRemainingSeconds(at date: Date = Date()) -> Int? {
        guard let rest = state.rest else {
            return nil
        }

        let elapsed = Int(date.timeIntervalSince(rest.startedAt))
        return rest.plannedSeconds - elapsed
    }

    func formattedRest(at date: Date = Date()) -> String? {
        guard let remaining = restRemainingSeconds(at: date) else {
            return nil
        }

        let absoluteSeconds = abs(remaining)
        let minutes = absoluteSeconds / 60
        let seconds = absoluteSeconds % 60
        let prefix = remaining < 0 ? "+" : ""
        return "\(prefix)\(minutes):\(String(format: "%02d", seconds))"
    }

    private func loadCurrentTargets() {
        guard let exercise = currentExercise else {
            repsValue = 0
            durationValue = 0
            loadValue = 0
            return
        }

        repsValue = Double(exercise.targetReps ?? exercise.targetRepsMax ?? exercise.targetRepsMin ?? 0)
        durationValue = Double(exercise.targetDurationSeconds ?? exercise.targetDurationMaxSeconds ?? exercise.targetDurationMinSeconds ?? 0)
        loadValue = exercise.startingLoad ?? 0
    }

    private func exerciseName(for id: UUID) -> String {
        snapshot?.exercises.first(where: { $0.id == id })?.name ?? "Exercise"
    }

    private func effectiveExerciseId(for exercise: WorkoutExerciseDTO) -> UUID {
        state.substitutions
            .first { $0.workoutExerciseId == exercise.id }?
            .replacementExerciseId ?? exercise.exerciseId
    }

    private func moveCurrentExercise(by offset: Int) {
        WorkoutExecutionEngine.moveCurrentExercise(in: &state, day: day, by: offset)
        saveActiveWorkout()
        loadCurrentTargets()
    }

    private func saveActiveWorkout() {
        do {
            try cacheStore.saveActiveWorkout(state)
        } catch {
            errorMessage = "Unable to save workout."
        }
    }
}
