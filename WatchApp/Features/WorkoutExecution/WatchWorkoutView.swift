import Foundation
import SpotterShared
import SwiftUI

struct WatchWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncManager: WatchPhoneSyncManager
    @StateObject private var viewModel: WatchWorkoutViewModel
    @State private var now = Date()
    @State private var isFocusMode = false

    init(plan: WorkoutPlanDTO, day: WorkoutDayDTO) {
        _viewModel = StateObject(wrappedValue: WatchWorkoutViewModel(plan: plan, day: day))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if isFocusMode {
                    focusContent
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    currentSetCard

                    if let restText = viewModel.formattedRest(at: now) {
                        restCard(restText)
                    }

                    if viewModel.canCompleteSet {
                        inputCard

                        if let suggestion = viewModel.currentSuggestion {
                            suggestionCard(suggestion)
                        }

                        WatchGlassButton(title: "Complete Set", systemImage: "checkmark") {
                            viewModel.completeCurrentSet()
                            syncManager.publishActiveWorkoutState(viewModel.state)
                        }
                    }

                    nextExerciseCard

                    if viewModel.isWorkoutComplete {
                        WatchGlassButton(title: "Finish", systemImage: "flag.checkered") {
                            viewModel.finishWorkout()
                        }
                    }

                    Button(role: .destructive) {
                        viewModel.skipCurrentSet()
                        syncManager.publishActiveWorkoutState(viewModel.state)
                    } label: {
                        Label("Skip Set", systemImage: "forward.end.fill")
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 8)
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isFocusMode.toggle()
                    }
                } label: {
                    Image(systemName: isFocusMode ? "list.bullet" : "scope")
                }
                .accessibilityLabel(isFocusMode ? "Exit Focus Mode" : "Enter Focus Mode")
            }
        }
        .onAppear {
            viewModel.configure(snapshot: syncManager.snapshot)
            viewModel.applySyncedState(syncManager.activeWorkoutState)
            syncManager.publishActiveWorkoutState(viewModel.state)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
            viewModel.tickRest(at: date)
        }
        .onChange(of: viewModel.state) { _, state in
            syncManager.publishActiveWorkoutState(state)
        }
        .onChange(of: syncManager.activeWorkoutState) { _, state in
            viewModel.applySyncedState(state)
        }
        .onChange(of: syncManager.snapshot) { _, snapshot in
            viewModel.configure(snapshot: snapshot)
        }
        .onChange(of: viewModel.repsValue) { _, _ in
            autosaveDraftInput()
        }
        .onChange(of: viewModel.loadValue) { _, _ in
            autosaveDraftInput()
        }
        .onChange(of: viewModel.durationValue) { _, _ in
            autosaveDraftInput()
        }
        .onChange(of: viewModel.rpeValue) { _, _ in
            autosaveDraftInput()
        }
        .onChange(of: viewModel.rirValue) { _, _ in
            autosaveDraftInput()
        }
        .onChange(of: viewModel.didFinish) { _, didFinish in
            if didFinish {
                syncManager.clearActiveWorkoutState()
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

    private var focusContent: some View {
        VStack(spacing: 9) {
            WatchGlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.currentExerciseName)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                    Text(setProgressText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchSpotterPalette.accent)
                    if let restText = viewModel.formattedRest(at: now) {
                        HStack(spacing: 5) {
                            Image(systemName: "timer")
                            Text(restText)
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        .foregroundStyle(restIsOver ? .green : .primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.canCompleteSet {
                focusInputCard

                WatchGlassButton(title: "Complete", systemImage: "checkmark") {
                    viewModel.completeCurrentSet()
                    syncManager.publishActiveWorkoutState(viewModel.state)
                }
            }

            nextExerciseCard

            Button(role: .destructive) {
                viewModel.skipCurrentSet()
                syncManager.publishActiveWorkoutState(viewModel.state)
            } label: {
                Label("Skip", systemImage: "forward.end.fill")
            }
            .font(.caption2)
        }
    }

    private func autosaveDraftInput() {
        viewModel.autosaveDraftInput()
        syncManager.publishActiveWorkoutState(viewModel.state)
    }

    private var currentSetCard: some View {
        WatchGlassCard {
            VStack(alignment: .leading, spacing: 7) {
                Text(viewModel.state.session.dayNameSnapshot)
                    .font(.caption2)
                    .foregroundStyle(WatchSpotterPalette.accent)
                Text(viewModel.currentExerciseName)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .lineLimit(2)
                Text(setProgressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let substitutionText = viewModel.currentSubstitutionText {
                    Text(substitutionText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inputCard: some View {
        WatchGlassCard {
            VStack(spacing: 8) {
                if viewModel.usesDuration {
                    FastWatchNumberField(
                        title: "Duration",
                        suffix: "s",
                        value: $viewModel.durationValue,
                        range: 0...3600,
                        step: 5
                    )
                } else {
                    FastWatchNumberField(
                        title: "Reps",
                        suffix: "",
                        value: $viewModel.repsValue,
                        range: 0...200,
                        step: 1
                    )
                }

                if viewModel.currentExercise?.loadUnit != .bodyweight {
                    FastWatchNumberField(
                        title: "Weight",
                        suffix: viewModel.currentExercise?.loadUnit.rawValue ?? "",
                        value: $viewModel.loadValue,
                        range: 0...500,
                        step: 2.5
                    )
                }

                HStack(spacing: 8) {
                    FastWatchNumberField(
                        title: "RPE",
                        suffix: "",
                        value: $viewModel.rpeValue,
                        range: 0...10,
                        step: 0.5,
                        nilValue: 0,
                        nilLabel: "-"
                    )
                    FastWatchNumberField(
                        title: "RIR",
                        suffix: "",
                        value: $viewModel.rirValue,
                        range: -1...10,
                        step: 1,
                        nilValue: -1,
                        nilLabel: "-"
                    )
                }
            }
        }
    }

    private var focusInputCard: some View {
        WatchGlassCard {
            VStack(spacing: 9) {
                if viewModel.usesDuration {
                    FastWatchNumberField(
                        title: "Duration",
                        suffix: "s",
                        value: $viewModel.durationValue,
                        range: 0...3600,
                        step: 5,
                        prominence: .focus
                    )
                } else {
                    FastWatchNumberField(
                        title: "Reps",
                        suffix: "",
                        value: $viewModel.repsValue,
                        range: 0...200,
                        step: 1,
                        prominence: .focus
                    )
                }

                if viewModel.currentExercise?.loadUnit != .bodyweight {
                    FastWatchNumberField(
                        title: "Weight",
                        suffix: viewModel.currentExercise?.loadUnit.rawValue ?? "",
                        value: $viewModel.loadValue,
                        range: 0...500,
                        step: 2.5,
                        prominence: .focus
                    )
                }
            }
        }
    }

    private func suggestionCard(_ suggestion: WatchWorkoutLoggingSuggestion) -> some View {
        WatchGlassCard {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.lastTime)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(suggestion.trend)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Button {
                    viewModel.applyPreviousSuggestion()
                    syncManager.publishActiveWorkoutState(viewModel.state)
                } label: {
                    Text(suggestion.reuseLabel)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var nextExerciseCard: some View {
        WatchGlassCard {
            VStack(alignment: .leading, spacing: 3) {
                Text("Next")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(viewModel.nextExerciseName ?? "Finish")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func restCard(_ restText: String) -> some View {
        WatchGlassCard {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(restIsOver ? .green : WatchSpotterPalette.accent)
                Text(restText)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer()
            }
            .foregroundStyle(restIsOver ? .green : .primary)
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

private struct FastWatchNumberField: View {
    enum Prominence {
        case normal
        case focus
    }

    let title: String
    let suffix: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var nilValue: Double?
    var nilLabel: String?
    var prominence: Prominence = .normal

    var body: some View {
        VStack(alignment: .leading, spacing: prominence == .focus ? 7 : 5) {
            Text(title)
                .font(prominence == .focus ? .caption.weight(.semibold) : .caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: prominence == .focus ? 10 : 8) {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: prominence == .focus ? 34 : 30, height: prominence == .focus ? 34 : 30)
                }
                .buttonStyle(.bordered)

                Text(displayText)
                    .font(.system(size: prominence == .focus ? 31 : 25, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
                    .focusable(true)
                    .digitalCrownRotation(
                        $value,
                        from: range.lowerBound,
                        through: range.upperBound,
                        by: step,
                        sensitivity: .high,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )

                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: prominence == .focus ? 34 : 30, height: prominence == .focus ? 34 : 30)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var displayText: String {
        if let nilValue, value == nilValue {
            return nilLabel ?? "-"
        }

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
