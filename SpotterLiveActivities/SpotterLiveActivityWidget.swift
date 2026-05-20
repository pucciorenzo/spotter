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
                .widgetURL(spotterWorkoutResumeURL)
                .activityBackgroundTint(.black.opacity(0.66))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading, priority: 1) {
                    IslandMetric(
                        title: "Set",
                        value: context.state.compactSetLabel,
                        systemImage: context.state.isPaused ? "pause.fill" : "checklist"
                    )
                }

                DynamicIslandExpandedRegion(.trailing, priority: 1) {
                    IslandTimerMetric(state: context.state)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 3) {
                        Text(context.state.exerciseName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(context.attributes.workoutName)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Link(destination: spotterWorkoutResumeURL) {
                        HStack(spacing: 8) {
                            Text(context.state.setLabel)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(context.state.isPaused ? "Resume" : "Open")
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.11), in: Capsule())
                    }
                }
            } compactLeading: {
                Text(context.state.compactSetLabel)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
            } compactTrailing: {
                RestTimerView(state: context.state)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
                    .foregroundStyle(.white)
            }
            .widgetURL(spotterWorkoutResumeURL)
        }
    }
}

private struct WorkoutLiveActivityLockScreenView: View {
    let context: ActivityViewContext<SpotterWorkoutActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label(statusText, systemImage: context.state.isPaused ? "pause.fill" : "figure.strengthtraining.traditional")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Link(destination: spotterWorkoutResumeURL) {
                    HStack(spacing: 5) {
                        Text(context.state.isPaused ? "Resume" : "Open")
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.12), in: Capsule())
                }
            }

            Text(context.state.exerciseName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            HStack(spacing: 10) {
                LockScreenMetric(
                    title: "Set",
                    systemImage: "checklist"
                ) {
                    Text(context.state.setLabel)
                }

                LockScreenMetric(
                    title: "Rest",
                    systemImage: "timer"
                ) {
                    RestTimerView(state: context.state)
                }
                .monospacedDigit()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var statusText: String {
        if context.state.isEnded {
            return "Workout ended"
        }
        if context.state.isPaused {
            return "Workout paused"
        }
        return context.attributes.workoutName
    }

}

private struct LockScreenMetric<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
            content
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct IslandMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.headline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

private struct IslandTimerMetric: View {
    let state: SpotterWorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Label("Rest", systemImage: "timer")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            RestTimerView(state: state)
                .font(.headline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
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

private let spotterWorkoutResumeURL = URL(string: "spotter://active-workout")!
