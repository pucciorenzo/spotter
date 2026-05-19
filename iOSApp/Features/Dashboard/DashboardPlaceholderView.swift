import SwiftData
import SwiftUI

struct DashboardPlaceholderView: View {
    @Query(sort: \WorkoutSessionModel.startedAt, order: .reverse) private var sessions: [WorkoutSessionModel]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: columns, spacing: 12) {
                    DashboardMetricTile(
                        title: "This Week",
                        value: "\(thisWeekSessions.count)",
                        caption: "workouts",
                        systemImage: "calendar"
                    )

                    DashboardMetricTile(
                        title: "Sets",
                        value: "\(completedSetCount(in: thisWeekSessions))",
                        caption: "completed",
                        systemImage: "checkmark.circle"
                    )

                    DashboardMetricTile(
                        title: "Volume",
                        value: volumeText(for: thisWeekSessions),
                        caption: "logged load",
                        systemImage: "scalemass"
                    )

                    DashboardMetricTile(
                        title: "Time",
                        value: durationText(for: thisWeekSessions),
                        caption: "training",
                        systemImage: "timer"
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Workouts")
                        .font(.headline)

                    if recentSessions.isEmpty {
                        ContentUnavailableView(
                            "No Workouts Yet",
                            systemImage: "chart.xyaxis.line",
                            description: Text("Complete a workout to start building trends.")
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(recentSessions) { session in
                                RecentWorkoutSummaryRow(session: session)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 12)]
    }

    private var recentSessions: [WorkoutSessionModel] {
        Array(sessions.prefix(5))
    }

    private var thisWeekSessions: [WorkoutSessionModel] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }

        return sessions.filter { session in
            session.status == .completed && weekInterval.contains(session.startedAt)
        }
    }

    private func completedSetCount(in sessions: [WorkoutSessionModel]) -> Int {
        sessions.reduce(0) { count, session in
            count + session.setLogs.filter { $0.completionType == .completed }.count
        }
    }

    private func volumeText(for sessions: [WorkoutSessionModel]) -> String {
        let volume = sessions
            .flatMap(\.setLogs)
            .filter { $0.completionType == .completed }
            .reduce(0.0) { total, log in
                guard let reps = log.completedReps,
                      let load = log.completedLoad,
                      log.completedLoadUnit != .bodyweight else {
                    return total
                }

                return total + (Double(reps) * load)
            }

        guard volume > 0 else {
            return "0"
        }

        if volume >= 1_000 {
            return String(format: "%.1fk", volume / 1_000)
        }

        return volume.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(volume))"
            : String(format: "%.1f", volume)
    }

    private func durationText(for sessions: [WorkoutSessionModel]) -> String {
        let seconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        let minutes = seconds / 60

        if minutes < 60 {
            return "\(minutes)m"
        }

        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

private struct DashboardMetricTile: View {
    let title: String
    let value: String
    let caption: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.title2.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RecentWorkoutSummaryRow: View {
    let session: WorkoutSessionModel

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.dayNameSnapshot.isEmpty ? "Workout" : session.dayNameSnapshot)
                    .font(.subheadline.weight(.medium))

                Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(completedSetCount) sets")
                    .font(.subheadline.monospacedDigit())

                Text(durationText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var completedSetCount: Int {
        session.setLogs.filter { $0.completionType == .completed }.count
    }

    private var durationText: String {
        let minutes = session.durationSeconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }

        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

#Preview {
    NavigationStack {
        DashboardPlaceholderView()
    }
}
