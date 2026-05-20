import ActivityKit
import SpotterShared
import SwiftUI
import WidgetKit

@main
struct SpotterLiveActivitiesBundle: WidgetBundle {
    var body: some Widget {
        SpotterWorkoutLiveActivity()
    }
}

struct SpotterWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SpotterWorkoutActivityAttributes.self) { context in
            WorkoutLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.72))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.exerciseName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.setLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    RestTimerView(state: context.state)
                        .font(.title3.monospacedDigit().weight(.semibold))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.workoutName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "figure.strengthtraining.traditional")
            } compactTrailing: {
                RestTimerView(state: context.state)
                    .font(.caption.monospacedDigit().weight(.semibold))
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}

private struct WorkoutLiveActivityLockScreenView: View {
    let context: ActivityViewContext<SpotterWorkoutActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: context.state.isPaused ? "pause.fill" : "figure.strengthtraining.traditional")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.exerciseName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(context.state.setLabel)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text("Rest")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                RestTimerView(state: context.state)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(18)
    }
}

private struct RestTimerView: View {
    let state: SpotterWorkoutActivityAttributes.ContentState

    var body: some View {
        if state.isEnded {
            Text("Done")
        } else if state.isPaused {
            Text(formatTime(state.restRemainingSeconds))
        } else if let restStartedAt = state.restStartedAt {
            Text(timerInterval: restStartedAt...restStartedAt.addingTimeInterval(TimeInterval(state.restDurationSeconds)), countsDown: true)
        } else {
            Text("--")
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}
