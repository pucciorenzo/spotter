import Foundation
import SpotterShared
import SwiftUI

struct WatchWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncManager: WatchPhoneSyncManager
    @StateObject private var viewModel: WatchWorkoutViewModel
    @AppStorage("workout.promptForSetResults") private var promptForSetResults = true
    @State private var now = Date()
    @State private var showingSetResultEntry = false

    init(plan: WorkoutPlanDTO, day: WorkoutDayDTO) {
        _viewModel = StateObject(wrappedValue: WatchWorkoutViewModel(plan: plan, day: day))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                WatchGlassCard {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(viewModel.state.session.dayNameSnapshot)
                            .font(.caption2)
                            .foregroundStyle(WatchSpotterPalette.accent)
                        Text(viewModel.currentExerciseName)
                            .font(.headline)
                            .lineLimit(2)
                        if let substitutionText = viewModel.currentSubstitutionText {
                            Text(substitutionText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(setProgressText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let restText = viewModel.formattedRest(at: now) {
                    WatchGlassCard {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundStyle(restIsOver ? .green : WatchSpotterPalette.accent)
                            Text(restText)
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Spacer()
                        }
                        .foregroundStyle(restIsOver ? .green : .primary)
                    }
                }

                if viewModel.canCompleteSet {
                    Toggle("Prompt", isOn: $promptForSetResults)
                        .font(.caption)
                        .padding(.horizontal, 4)

                    if !promptForSetResults {
                        WatchGlassCard {
                            VStack(spacing: 10) {
                                if viewModel.usesDuration {
                                    CrownNumberField(
                                        title: "Duration",
                                        suffix: "s",
                                        value: $viewModel.durationValue,
                                        range: 0...3600,
                                        step: 5
                                    )
                                } else {
                                    CrownNumberField(
                                        title: "Reps",
                                        suffix: "",
                                        value: $viewModel.repsValue,
                                        range: 0...200,
                                        step: 1
                                    )
                                }

                                if viewModel.currentExercise?.loadUnit != .bodyweight {
                                    CrownNumberField(
                                        title: "Load",
                                        suffix: viewModel.currentExercise?.loadUnit.rawValue ?? "",
                                        value: $viewModel.loadValue,
                                        range: 0...500,
                                        step: 2.5
                                    )
                                }
                            }
                        }
                    }

                    WatchGlassButton(title: "Complete", systemImage: "checkmark") {
                        if promptForSetResults {
                            showingSetResultEntry = true
                        } else {
                            viewModel.completeCurrentSet()
                        }
                    }
                    .sheet(isPresented: $showingSetResultEntry) {
                        WatchSetResultEntryView(
                            title: "Set \(viewModel.nextSetNumber)",
                            usesDuration: viewModel.usesDuration,
                            loadUnit: viewModel.currentExercise?.loadUnit ?? .kg,
                            reps: Int(viewModel.repsValue),
                            durationSeconds: Int(viewModel.durationValue),
                            load: viewModel.loadValue
                        ) { reps, durationSeconds, load in
                            viewModel.completeCurrentSet(
                                reps: reps,
                                durationSeconds: durationSeconds,
                                load: load
                            )
                        }
                    }

                    WatchGlassCard {
                        VStack(spacing: 8) {
                            if !viewModel.loggedSets.isEmpty {
                                NavigationLink {
                                    WatchLoggedSetListView(viewModel: viewModel)
                                } label: {
                                    Label("Logged Sets", systemImage: "pencil")
                                }
                            }

                            Button {
                                viewModel.skipCurrentSet()
                            } label: {
                                Label("Skip Set", systemImage: "forward.end.fill")
                            }

                            Button(role: .destructive) {
                                viewModel.skipCurrentExercise()
                            } label: {
                                Label("Skip Exercise", systemImage: "figure.strengthtraining.traditional")
                            }

                            HStack {
                                Button {
                                    viewModel.moveCurrentExerciseUp()
                                } label: {
                                    Image(systemName: "arrow.up")
                                }
                                .disabled(!viewModel.canMoveCurrentExerciseUp)

                                Button {
                                    viewModel.moveCurrentExerciseDown()
                                } label: {
                                    Image(systemName: "arrow.down")
                                }
                                .disabled(!viewModel.canMoveCurrentExerciseDown)
                            }

                            NavigationLink {
                                WatchExerciseReplacementView(viewModel: viewModel)
                            } label: {
                                Label("Change", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(viewModel.replacementExercises.isEmpty)
                        }
                        .font(.caption)
                    }
                } else if !viewModel.loggedSets.isEmpty {
                    NavigationLink {
                        WatchLoggedSetListView(viewModel: viewModel)
                    } label: {
                        Label("Edit Logged Sets", systemImage: "pencil")
                    }
                }

                if viewModel.isWorkoutComplete {
                    WatchGlassButton(title: "Finish", systemImage: "flag.checkered") {
                        viewModel.finishWorkout()
                    }
                }

                Button(role: .destructive) {
                    viewModel.cancelWorkout()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .containerBackground(for: .navigation) {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.07, blue: 0.11),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .navigationTitle(viewModel.state.session.dayNameSnapshot)
        .onAppear {
            viewModel.configure(snapshot: syncManager.snapshot)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
            viewModel.tickRest(at: date)
        }
        .onChange(of: viewModel.didFinish) { _, didFinish in
            if didFinish {
                syncManager.syncQueuedCompletedWorkouts()
                dismiss()
            }
        }
        .alert("Workout Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var setProgressText: String {
        guard viewModel.totalSetCount > 0 else {
            return "No sets"
        }

        let type = viewModel.isCurrentSetWarmup ? "Warm-up" : "Working"
        return "\(type) set \(viewModel.nextSetNumber) of \(viewModel.totalSetCount)"
    }

    private var restIsOver: Bool {
        (viewModel.restRemainingSeconds(at: now) ?? 1) <= 0
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

private struct WatchLoggedSetListView: View {
    @ObservedObject var viewModel: WatchWorkoutViewModel

    var body: some View {
        List(viewModel.loggedSets) { log in
            if log.completionType == .completed {
                NavigationLink {
                    WatchSetResultEntryView(
                        title: "\(log.exerciseNameSnapshot) \(log.setIndex)",
                        usesDuration: log.targetDurationSeconds != nil,
                        loadUnit: log.completedLoadUnit,
                        reps: log.completedReps ?? log.targetReps ?? 0,
                        durationSeconds: log.completedDurationSeconds ?? log.targetDurationSeconds ?? 0,
                        load: log.completedLoad ?? log.targetLoad ?? 0
                    ) { reps, durationSeconds, load in
                        viewModel.updateLoggedSet(
                            log,
                            reps: reps,
                            durationSeconds: durationSeconds,
                            load: load
                        )
                    }
                } label: {
                    WatchLoggedSetRow(log: log)
                }
            } else {
                WatchLoggedSetRow(log: log)
            }
        }
        .navigationTitle("Logged Sets")
    }
}

private struct WatchLoggedSetRow: View {
    let log: WorkoutSetLogDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(log.exerciseNameSnapshot) \(log.setIndex)")
                .font(.headline)
            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
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

        return "\(repsText) x \(format(load)) \(log.completedLoadUnit.rawValue)"
    }

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}

private struct WatchSetResultEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let usesDuration: Bool
    let loadUnit: LoadUnit
    let onSave: (Int?, Int?, Double?) -> Void

    @State private var repsText: String
    @State private var durationText: String
    @State private var loadText: String

    init(
        title: String,
        usesDuration: Bool,
        loadUnit: LoadUnit,
        reps: Int,
        durationSeconds: Int,
        load: Double,
        onSave: @escaping (Int?, Int?, Double?) -> Void
    ) {
        self.title = title
        self.usesDuration = usesDuration
        self.loadUnit = loadUnit
        self.onSave = onSave
        _repsText = State(initialValue: reps == 0 ? "" : "\(reps)")
        _durationText = State(initialValue: durationSeconds == 0 ? "" : "\(durationSeconds)")
        _loadText = State(initialValue: load == 0 ? "" : Self.format(load))
    }

    var body: some View {
        Form {
            if usesDuration {
                TextField("Seconds", text: $durationText)
            } else {
                TextField("Reps", text: $repsText)
            }

            if loadUnit != .bodyweight {
                TextField(loadUnit.rawValue, text: $loadText)
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(
                        usesDuration ? nil : Int(repsText),
                        usesDuration ? Int(durationText) : nil,
                        loadUnit == .bodyweight ? nil : Double(loadText.replacingOccurrences(of: ",", with: "."))
                    )
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

private struct WatchExerciseReplacementView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WatchWorkoutViewModel

    var body: some View {
        List(viewModel.replacementExercises) { exercise in
            Button {
                viewModel.substituteCurrentExercise(with: exercise)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                    Text(exercise.primaryMuscleGroup)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Change")
    }
}

private struct CrownNumberField: View {
    let title: String
    let suffix: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(displayText)
                .font(.title3.monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusable(true)
                .digitalCrownRotation(
                    $value,
                    from: range.lowerBound,
                    through: range.upperBound,
                    by: step,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
        }
    }

    private var displayText: String {
        let formattedValue = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)

        guard !suffix.isEmpty else {
            return formattedValue
        }

        return "\(formattedValue) \(suffix)"
    }
}

#Preview {
    NavigationStack {
        WatchWorkoutView(
            plan: DemoSeedData.plans[0],
            day: DemoSeedData.plans[0].days[0]
        )
    }
    .environmentObject(WatchPhoneSyncManager(cacheStore: WatchCacheStore()))
}
