import ActivityKit
import Foundation
import SpotterShared

@MainActor
final class ActiveWorkoutLiveActivityManager: ObservableObject {
    @Published private(set) var isLiveActivityActive = false
    @Published private(set) var isPaused = false
    @Published private(set) var lastErrorMessage: String?

    private var activity: Activity<SpotterWorkoutActivityAttributes>?
    private var pausedRestRemainingSeconds: Int?

    func startOrUpdate(session: ActiveWorkoutSession) {
        if activity == nil {
            start(session: session)
        } else {
            update(session: session)
        }
    }

    func start(session: ActiveWorkoutSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            lastErrorMessage = "Live Activities are disabled."
            return
        }

        let attributes = SpotterWorkoutActivityAttributes(
            sessionId: session.id,
            workoutName: "\(session.planName) - \(session.dayName)"
        )
        let state = contentState(from: session)

        Task {
            do {
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
                isLiveActivityActive = true
                lastErrorMessage = nil
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func update(session: ActiveWorkoutSession) {
        guard let activity else { return }
        let state = contentState(from: session)

        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
            isLiveActivityActive = true
            lastErrorMessage = nil
        }
    }

    func pause(session: ActiveWorkoutSession) {
        isPaused = session.isPaused
        pausedRestRemainingSeconds = session.restRemainingSeconds
        update(session: session)
    }

    func resume(session: ActiveWorkoutSession) {
        isPaused = session.isPaused
        pausedRestRemainingSeconds = nil
        update(session: session)
    }

    func end(session: ActiveWorkoutSession) {
        guard let activity else { return }
        let state = contentState(from: session, isEnded: true)

        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
            self.activity = nil
            isLiveActivityActive = false
            isPaused = false
            pausedRestRemainingSeconds = nil
            lastErrorMessage = nil
        }
    }

    private func contentState(
        from session: ActiveWorkoutSession,
        isEnded: Bool = false
    ) -> SpotterWorkoutActivityAttributes.ContentState {
        let exercise = session.currentExercise
        let set = session.currentSet
        let paused = session.isPaused || isPaused
        let restRemaining = max(0, pausedRestRemainingSeconds ?? session.restRemainingSeconds)
        let restDuration = max(session.restDurationSeconds, set?.restSeconds ?? 0, restRemaining)

        return SpotterWorkoutActivityAttributes.ContentState(
            exerciseName: exercise?.name ?? session.dayName,
            setLabel: setLabel(exercise: exercise, set: set),
            compactSetLabel: compactSetLabel(exercise: exercise, set: set),
            restStartedAt: paused ? nil : session.restStartedAt,
            restDurationSeconds: restDuration,
            restRemainingSeconds: restRemaining,
            isPaused: paused,
            isEnded: isEnded
        )
    }

    private func setLabel(exercise: ActiveWorkoutExercise?, set: ActiveWorkoutSet?) -> String {
        guard let exercise, let set else { return "No set" }
        let kind = set.isWarmup ? "Warm-up" : "Set"
        return "\(kind) \(set.index) of \(exercise.sets.count)"
    }

    private func compactSetLabel(exercise: ActiveWorkoutExercise?, set: ActiveWorkoutSet?) -> String {
        guard let exercise, let set else { return "--" }
        let prefix = set.isWarmup ? "W" : "S"
        return "\(prefix)\(set.index)/\(exercise.sets.count)"
    }
}
