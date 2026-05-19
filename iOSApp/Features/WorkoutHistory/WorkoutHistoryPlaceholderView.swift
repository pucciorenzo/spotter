import SwiftData
import SwiftUI

struct WorkoutHistoryPlaceholderView: View {
    @Query(sort: \WorkoutSessionModel.startedAt, order: .reverse) private var sessions: [WorkoutSessionModel]

    var body: some View {
        List {
            ForEach(sessions) { session in
                NavigationLink {
                    WorkoutSessionDetailView(session: session)
                } label: {
                    WorkoutSessionRow(session: session)
                }
            }
        }
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "calendar.badge.clock",
                    description: Text("Completed workouts will appear here.")
                )
            }
        }
        .navigationTitle("History")
    }
}

private struct WorkoutSessionRow: View {
    let session: WorkoutSessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.dayNameSnapshot.isEmpty ? "Workout" : session.dayNameSnapshot)
                    .font(.headline)
                Spacer()
                Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(session.planNameSnapshot)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label(durationText, systemImage: "timer")
                Label("\(completedSetCount) sets", systemImage: "checkmark.circle")
                if skippedSetCount > 0 {
                    Label("\(skippedSetCount) skipped", systemImage: "forward.end")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var completedSetCount: Int {
        session.setLogs.filter { $0.completionType == .completed }.count
    }

    private var skippedSetCount: Int {
        session.setLogs.filter { $0.completionType == .skipped }.count
    }

    private var durationText: String {
        DurationFormatter.short(session.durationSeconds)
    }
}

private struct WorkoutSessionDetailView: View {
    @Bindable var session: WorkoutSessionModel
    @State private var editedLog: WorkoutSetLogModel?

    var body: some View {
        List {
            Section {
                LabeledContent("Plan", value: session.planNameSnapshot)
                LabeledContent("Day", value: session.dayNameSnapshot)
                LabeledContent("Started", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duration", value: DurationFormatter.long(session.durationSeconds))
                LabeledContent("Source", value: session.source == .watch ? "Apple Watch" : "iPhone")
            }

            Section("Sets") {
                ForEach(groupedSetLogs, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name)
                            .font(.headline)

                        ForEach(group.logs) { log in
                            if log.completionType == .completed {
                                Button {
                                    editedLog = log
                                } label: {
                                    WorkoutSetLogRow(log: log)
                                }
                            } else {
                                WorkoutSetLogRow(log: log)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(session.dayNameSnapshot.isEmpty ? "Workout" : session.dayNameSnapshot)
        .sheet(item: $editedLog) { log in
            NavigationStack {
                HistorySetResultEditorView(log: log)
            }
        }
    }

    private var groupedSetLogs: [(name: String, logs: [WorkoutSetLogModel])] {
        let sortedLogs = session.setLogs.sorted { lhs, rhs in
            if lhs.completedAt == rhs.completedAt {
                return lhs.setIndex < rhs.setIndex
            }
            return lhs.completedAt < rhs.completedAt
        }

        var groups: [(name: String, logs: [WorkoutSetLogModel])] = []
        for log in sortedLogs {
            if let index = groups.firstIndex(where: { $0.name == log.exerciseNameSnapshot }) {
                groups[index].logs.append(log)
            } else {
                groups.append((name: log.exerciseNameSnapshot, logs: [log]))
            }
        }
        return groups
    }
}

private struct WorkoutSetLogRow: View {
    let log: WorkoutSetLogModel

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Set \(log.setIndex)")
                .font(.subheadline)

            if log.isWarmup {
                Text("Warm-up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(summaryText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(log.completionType == .skipped ? .secondary : .primary)
        }
    }

    private var summaryText: String {
        if log.completionType == .skipped {
            return "Skipped"
        }

        if let seconds = log.completedDurationSeconds {
            return "\(seconds)s"
        }

        let repsText = log.completedReps.map { "\($0) reps" } ?? "Logged"
        guard let load = log.completedLoad else {
            return repsText
        }

        let loadText = load.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(load))"
            : String(format: "%.1f", load)
        return "\(repsText) x \(loadText) \(log.completedLoadUnit.rawValue)"
    }
}

private struct HistorySetResultEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var log: WorkoutSetLogModel
    @State private var repsText: String
    @State private var durationText: String
    @State private var loadText: String

    init(log: WorkoutSetLogModel) {
        self.log = log
        _repsText = State(initialValue: log.completedReps.map(String.init) ?? "")
        _durationText = State(initialValue: log.completedDurationSeconds.map(String.init) ?? "")
        _loadText = State(initialValue: log.completedLoad.map(Self.format) ?? "")
    }

    var body: some View {
        Form {
            Section("Result") {
                if log.targetDurationSeconds != nil {
                    TextField("Seconds", text: $durationText)
                        .keyboardType(.numberPad)
                } else {
                    TextField("Reps", text: $repsText)
                        .keyboardType(.numberPad)
                }

                if log.completedLoadUnit != .bodyweight {
                    TextField(log.completedLoadUnit.rawValue, text: $loadText)
                        .keyboardType(.decimalPad)
                }
            }
        }
        .navigationTitle("\(log.exerciseNameSnapshot) Set \(log.setIndex)")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if log.targetDurationSeconds != nil {
                        log.completedDurationSeconds = Int(durationText)
                        log.completedReps = nil
                    } else {
                        log.completedReps = Int(repsText)
                        log.completedDurationSeconds = nil
                    }

                    log.completedLoad = log.completedLoadUnit == .bodyweight
                        ? nil
                        : Double(loadText.replacingOccurrences(of: ",", with: "."))
                    log.completedAt = Date()
                    dismiss()
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private static func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}

private enum DurationFormatter {
    static func short(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        return "\(hours)h \(minutes % 60)m"
    }

    static func long(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(remainingMinutes) min"
        }

        return "\(hours) hr \(remainingMinutes) min"
    }
}

#Preview {
    NavigationStack {
        WorkoutHistoryPlaceholderView()
    }
}
