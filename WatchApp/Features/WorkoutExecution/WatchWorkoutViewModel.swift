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
    @Published var rpeValue: Double = 0
    @Published var rirValue: Double = 0
    @Published private(set) var lastAutosavedAt = Date()
    @Published var errorMessage: String?

    private let plan: WorkoutPlanDTO
    private let day: WorkoutDayDTO
    private let cacheStore: WatchCacheStore
    private let deviceId: String
    private var snapshot: SyncSnapshot?

    init(
        plan: WorkoutPlanDTO,
        day: WorkoutDayDTO,
        cacheStore: WatchCacheStore = WatchCacheStore()
    ) {
        self.plan = plan
        self.day = day
        self.cacheStore = cacheStore
        self.deviceId = cacheStore.loadOrCreateDeviceIdentifier()

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

    var loggedSets: [WorkoutSetLogDTO] {
        state.session.setLogs.sorted { lhs, rhs in
            if lhs.completedAt == rhs.completedAt {
                return lhs.setIndex < rhs.setIndex
            }

            return lhs.completedAt < rhs.completedAt
        }
    }

    var nextExerciseName: String? {
        let exercises = WorkoutExecutionEngine.orderedExercises(in: day, state: state)
        let nextIndex = state.currentExerciseIndex + 1
        guard exercises.indices.contains(nextIndex) else {
            return nil
        }

        return exerciseName(for: exercises[nextIndex].exerciseId)
    }

    var currentSuggestion: WatchWorkoutLoggingSuggestion? {
        guard let currentExercise, let snapshot else {
            return nil
        }

        let effectiveId = effectiveExerciseId(for: currentExercise)
        let matches = snapshot.recentSessions
            .flatMap(\.setLogs)
            .filter {
                $0.completionType == .completed
                    && ($0.exerciseId == effectiveId || $0.originalExerciseId == effectiveId)
                    && $0.setIndex == nextSetNumber
            }
            .sorted { $0.completedAt > $1.completedAt }

        guard let latest = matches.first else {
            return nil
        }

        return WatchWorkoutLoggingSuggestion(log: latest, previousLog: matches.dropFirst().first)
    }

    func configure(snapshot: SyncSnapshot?) {
        self.snapshot = snapshot
    }

    func applySyncedState(_ syncedState: WorkoutExecutionState?) {
        guard let syncedState,
              syncedState.session.id == state.session.id else {
            return
        }

        let mergedState = state.mergedWithRemote(syncedState)
        guard mergedState.syncFingerprint != state.syncFingerprint else {
            return
        }

        state = mergedState
        persistActiveWorkout(markMutation: false)
        loadCurrentTargets()
    }

    func autosaveDraftInput() {
        saveActiveWorkout()
    }

    func applyPreviousSuggestion() {
        guard let suggestion = currentSuggestion else {
            return
        }

        if let reps = suggestion.previousReps {
            repsValue = Double(reps)
        }
        if let duration = suggestion.previousDurationSeconds {
            durationValue = Double(duration)
        }
        if let load = suggestion.previousLoad {
            loadValue = load
        }
        if let rpe = suggestion.previousRPE {
            rpeValue = rpe
        }
        if let rir = suggestion.previousRIR {
            rirValue = Double(rir)
        }
        saveActiveWorkout()
    }

    func completeCurrentSet() {
        completeCurrentSet(
            reps: usesDuration ? nil : Int(repsValue),
            durationSeconds: usesDuration ? Int(durationValue) : nil,
            load: currentExercise?.loadUnit == .bodyweight ? nil : loadValue,
            rpe: rpeValue > 0 ? rpeValue : nil,
            rir: rirValue >= 0 ? Int(rirValue) : nil
        )
    }

    func completeCurrentSet(reps: Int?, durationSeconds: Int?, load: Double?, rpe: Double? = nil, rir: Int? = nil) {
        guard let exercise = currentExercise else {
            return
        }

        WorkoutExecutionEngine.appendCompletedSet(
            to: &state,
            day: day,
            exercise: exercise,
            exerciseName: exerciseName(for: exercise.exerciseId),
            completedReps: reps,
            completedDurationSeconds: durationSeconds,
            completedLoad: exercise.loadUnit == .bodyweight ? nil : load,
            rpe: rpe,
            rir: rir
        )

        saveActiveWorkout()
        loadCurrentTargets()
    }

    func updateLoggedSet(_ log: WorkoutSetLogDTO, reps: Int?, durationSeconds: Int?, load: Double?) {
        WorkoutExecutionEngine.updateSetLog(
            in: &state,
            logId: log.id,
            completedReps: reps,
            completedDurationSeconds: durationSeconds,
            completedLoad: log.completedLoadUnit == .bodyweight ? nil : load
        )

        saveActiveWorkout()
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
            rpeValue = 0
            rirValue = -1
            return
        }

        repsValue = Double(exercise.targetReps ?? exercise.targetRepsMax ?? exercise.targetRepsMin ?? 0)
        durationValue = Double(exercise.targetDurationSeconds ?? exercise.targetDurationMaxSeconds ?? exercise.targetDurationMinSeconds ?? 0)
        loadValue = exercise.startingLoad ?? 0
        rpeValue = 0
        rirValue = -1
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
        persistActiveWorkout(markMutation: true)
    }

    private func persistActiveWorkout(markMutation: Bool) {
        do {
            if markMutation {
                state.markMutation(deviceId: deviceId)
            }
            try cacheStore.saveActiveWorkout(state)
            lastAutosavedAt = state.session.updatedAt
        } catch {
            errorMessage = "Unable to save workout."
        }
    }
}

struct WatchWorkoutLoggingSuggestion: Equatable {
    let lastTime: String
    let trend: String
    let reuseLabel: String
    let previousReps: Int?
    let previousDurationSeconds: Int?
    let previousLoad: Double?
    let previousRPE: Double?
    let previousRIR: Int?

    init(log: WorkoutSetLogDTO, previousLog: WorkoutSetLogDTO?) {
        previousReps = log.completedReps
        previousDurationSeconds = log.completedDurationSeconds
        previousLoad = log.completedLoad
        previousRPE = log.rpe
        previousRIR = log.rir
        lastTime = "Last: \(Self.summary(log))"
        trend = Self.trend(log: log, previousLog: previousLog)
        reuseLabel = Self.reuseLabel(log)
    }

    private static func summary(_ log: WorkoutSetLogDTO) -> String {
        if let seconds = log.completedDurationSeconds {
            return "\(seconds)s\(effort(log))"
        }

        let reps = log.completedReps.map(String.init) ?? "-"
        if let load = log.completedLoad, load > 0 {
            return "\(format(load)) \(log.completedLoadUnit.rawValue) x \(reps)\(effort(log))"
        }

        return "\(reps) reps\(effort(log))"
    }

    private static func reuseLabel(_ log: WorkoutSetLogDTO) -> String {
        if let seconds = log.completedDurationSeconds {
            return "\(seconds)s"
        }

        let reps = log.completedReps.map(String.init) ?? "-"
        guard let load = log.completedLoad, load > 0 else {
            return "\(reps) reps"
        }

        return "\(format(load)) \(log.completedLoadUnit.rawValue) x \(reps)"
    }

    private static func trend(log: WorkoutSetLogDTO, previousLog: WorkoutSetLogDTO?) -> String {
        guard let previousLog else {
            return "Tap to reuse."
        }

        if log.completedLoad == previousLog.completedLoad,
           let reps = log.completedReps,
           let previousReps = previousLog.completedReps {
            let delta = reps - previousReps
            if delta > 0 { return "+\(delta) reps" }
            if delta < 0 { return "\(delta) reps" }
            return "same reps"
        }

        if let seconds = log.completedDurationSeconds,
           let previousSeconds = previousLog.completedDurationSeconds {
            let delta = seconds - previousSeconds
            if delta > 0 { return "+\(delta)s" }
            if delta < 0 { return "\(delta)s" }
            return "same time"
        }

        return "Tap to reuse."
    }

    private static func effort(_ log: WorkoutSetLogDTO) -> String {
        let values = [
            log.rpe.map { "RPE \(format($0))" },
            log.rir.map { "RIR \($0)" }
        ].compactMap { $0 }

        return values.isEmpty ? "" : " · \(values.joined(separator: " / "))"
    }

    private static func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}
