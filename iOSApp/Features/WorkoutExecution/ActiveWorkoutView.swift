import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var repository: MockActiveWorkoutRepository
    @ObservedObject var healthKitManager: HealthKitWorkoutManager
    @ObservedObject var liveActivityManager: ActiveWorkoutLiveActivityManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("activeWorkoutFocusModeDefault") private var focusModeDefault = false
    @State private var isFocusMode = false
    @State private var didApplyFocusDefault = false
    @State private var showingStopConfirmation = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                SpotterBackground()

                if let session = repository.session,
                   let currentExercise = session.currentExercise,
                   let currentSet = session.currentSet {
                    if isFocusMode {
                        ActiveWorkoutFocusContent(
                            session: session,
                            exercise: currentExercise,
                            set: currentSet,
                            repository: repository
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 136)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                ActiveWorkoutHeader(session: session)

                                HealthWorkoutPanel(
                                    session: session,
                                    healthKitManager: healthKitManager
                                )

                                CurrentSetPanel(
                                    session: session,
                                    exercise: currentExercise,
                                    set: currentSet,
                                    repository: repository
                                )

                                if let suggestion = currentExercise.previousPerformance {
                                    PreviousPerformanceCard(suggestion: suggestion) {
                                        repository.applyPreviousSuggestion()
                                    }
                                }

                                WorkoutExerciseList(
                                    session: session,
                                    repository: repository
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 18)
                            .padding(.bottom, 138)
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }

                    ActiveWorkoutBottomBar(
                        set: currentSet,
                        repository: repository,
                        healthKitManager: healthKitManager,
                        liveActivityManager: liveActivityManager
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                }

            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: isFocusMode)
            .navigationTitle(isFocusMode ? "Focus" : "Active Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if repository.session != nil {
                        Button {
                            SpotterHaptics.selection()
                            withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.88)) {
                                showingStopConfirmation = true
                            }
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .foregroundStyle(.white)
                        .tint(.white)
                        .accessibilityLabel("Stop Workout")
                        .popover(
                            isPresented: $showingStopConfirmation,
                            attachmentAnchor: .point(.center),
                            arrowEdge: .top
                        ) {
                            StopWorkoutConfirmationPopover(
                                completedSets: repository.session?.completedSetCount ?? 0,
                                totalSets: repository.session?.totalSetCount ?? 0,
                                save: { stopWorkout(shouldSave: true) },
                                discard: { stopWorkout(shouldSave: false) }
                            )
                            .presentationCompactAdaptation(.popover)
                            .presentationBackground(.clear)
                        }
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if let session = repository.session {
                        Button {
                            SpotterHaptics.selection()
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                                isFocusMode.toggle()
                            }
                        } label: {
                            Image(systemName: isFocusMode ? "rectangle.expand.vertical" : "scope")
                        }
                        .accessibilityLabel(isFocusMode ? "Exit Focus Mode" : "Enter Focus Mode")

                        Button {
                            togglePause(session: session)
                        } label: {
                            Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                        }
                        .accessibilityLabel(session.isPaused ? "Resume Workout" : "Pause Workout")
                    }
                }
            }
            .spotterScreenChrome()
        }
        .onAppear {
            if !didApplyFocusDefault {
                isFocusMode = focusModeDefault
                didApplyFocusDefault = true
            }
            if let session = repository.session {
                liveActivityManager.startOrUpdate(session: session)
            }
        }
        .onReceive(timer) { _ in
            repository.tickRest()
            if repository.session?.isPaused == false {
                healthKitManager.tick()
            }
            if let session = repository.session {
                liveActivityManager.update(session: session)
            }
        }
        .onChange(of: activityVersion) { _, _ in
            if let session = repository.session {
                liveActivityManager.startOrUpdate(session: session)
            }
        }
    }

    private var activityVersion: String {
        guard let session = repository.session else { return "none" }
        return [
            session.id.uuidString,
            session.currentExerciseId.uuidString,
            session.currentSetId.uuidString,
            "\(session.isPaused)",
            "\(session.restDurationSeconds)",
            "\(session.restRemainingSeconds)",
            "\(session.restStartedAt?.timeIntervalSince1970 ?? 0)",
            "\(session.lastAutosavedAt.timeIntervalSince1970)",
            "\(session.completedSetCount)",
            "\(session.totalSetCount)"
        ].joined(separator: ":")
    }

    private func togglePause(session: ActiveWorkoutSession) {
        SpotterHaptics.impact(.light)
        if session.isPaused {
            repository.resumeWorkout()
            if let updated = repository.session {
                liveActivityManager.resume(session: updated)
            }
        } else {
            repository.pauseWorkout()
            if let updated = repository.session {
                liveActivityManager.pause(session: updated)
            }
        }
    }

    private func stopWorkout(shouldSave: Bool) {
        guard let session = repository.session else {
            dismiss()
            return
        }

        SpotterHaptics.notification(shouldSave ? .success : .warning)
        liveActivityManager.end(session: session)
        healthKitManager.finishParallelWorkout()

        if shouldSave {
            repository.endWorkout()
        } else {
            repository.discardWorkout()
        }

        dismiss()
    }
}

private struct StopWorkoutConfirmationPopover: View {
    let completedSets: Int
    let totalSets: Int
    let save: () -> Void
    let discard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stop workout?")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                Text("\(completedSets) of \(totalSets) sets logged")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }

            VStack(spacing: 10) {
                StopWorkoutPopoverButton(
                    title: "Save Workout",
                    style: .primary,
                    action: save
                )

                StopWorkoutPopoverButton(
                    title: "Discard Workout",
                    style: .destructive,
                    action: discard
                )
            }
        }
        .padding(16)
        .frame(width: 292)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .glassEffect(
            .regular.interactive(true),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 0.8)
                .blur(radius: 0.8)
                .padding(1)
                .mask(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .shadow(color: .black.opacity(0.26), radius: 22, y: 12)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
    }
}

private struct StopWorkoutPopoverButton: View {
    enum Style {
        case primary
        case destructive
    }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button {
            SpotterHaptics.selection()
            action()
        } label: {
            Text(title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 46)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var foreground: Color {
        switch style {
        case .primary:
            return .white.opacity(0.92)
        case .destructive:
            return .red.opacity(0.92)
        }
    }

    private var background: some ShapeStyle {
        switch style {
        case .primary:
            return AnyShapeStyle(.white.opacity(0.10))
        case .destructive:
            return AnyShapeStyle(Color.red.opacity(0.08))
        }
    }
}

private struct ActiveWorkoutFocusContent: View {
    let session: ActiveWorkoutSession
    let exercise: ActiveWorkoutExercise
    let set: ActiveWorkoutSet
    @ObservedObject var repository: MockActiveWorkoutRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassCard(cornerRadius: 30, padding: 22) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(exercise.name)
                                .font(.system(size: 42, weight: .semibold, design: .rounded))
                                .lineLimit(2)
                                .minimumScaleFactor(0.64)
                            Text(setLabel)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(SpotterPalette.accentSoft)
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 5) {
                            Text(restText)
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(restIsRunning ? SpotterPalette.accentSoft : SpotterPalette.textPrimary)
                            Text("\(session.estimatedRemainingMinutes) min left")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SpotterPalette.textSecondary)
                        }
                    }

                    ActiveMetricPill(
                        title: session.nextExercise.map { "Next: \($0.name)" } ?? "Last exercise",
                        systemImage: "forward.end"
                    )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(SpotterPalette.accent.opacity(0.46), lineWidth: 1.5)
            }

            FocusSetInputPanel(
                set: set,
                exercise: exercise,
                repository: repository
            )

            if let suggestion = exercise.previousPerformance {
                PreviousPerformanceCard(suggestion: suggestion) {
                    repository.applyPreviousSuggestion()
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var setLabel: String {
        let prefix = set.isWarmup ? "Warm-up" : "Working"
        return "\(prefix) Set \(set.index) of \(exercise.sets.count)"
    }

    private var restIsRunning: Bool {
        session.restStartedAt != nil
    }

    private var restText: String {
        guard session.restStartedAt != nil else {
            return "0:00"
        }

        if session.restRemainingSeconds >= 0 {
            return formatTime(session.restRemainingSeconds)
        }

        return "+\(formatTime(abs(session.restRemainingSeconds)))"
    }
}

private struct FocusSetInputPanel: View {
    let set: ActiveWorkoutSet
    let exercise: ActiveWorkoutExercise
    @ObservedObject var repository: MockActiveWorkoutRepository
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GlassCard(cornerRadius: 30, padding: 18) {
            VStack(spacing: 14) {
                switch set.kind {
                case .repsWeight:
                    VStack(spacing: 12) {
                        FastNumberControl(
                            title: "Reps",
                            value: "\(set.reps)",
                            inputMode: .integer,
                            prominence: .focus,
                            decrement: { repository.updateReps(set.reps - 1) },
                            increment: { repository.updateReps(set.reps + 1) },
                            updateText: { text in
                                if let reps = Int(text) {
                                    repository.updateReps(reps)
                                }
                            }
                        )
                        FastNumberControl(
                            title: "Weight (kg)",
                            value: format(set.weight),
                            inputMode: .decimal,
                            prominence: .focus,
                            decrement: { repository.updateWeight(set.weight - 2.5) },
                            increment: { repository.updateWeight(set.weight + 2.5) },
                            updateText: { text in
                                if let weight = Double(text.replacingOccurrences(of: ",", with: ".")) {
                                    repository.updateWeight(weight)
                                }
                            }
                        )
                    }
                case .duration:
                    FastNumberControl(
                        title: "Duration (s)",
                        value: "\(set.durationSeconds)",
                        inputMode: .integer,
                        prominence: .focus,
                        decrement: { repository.updateDuration(set.durationSeconds - 5) },
                        increment: { repository.updateDuration(set.durationSeconds + 5) },
                        updateText: { text in
                            if let seconds = Int(text) {
                                repository.updateDuration(seconds)
                            }
                        }
                    )
                }

                HStack(spacing: 12) {
                    EffortControl(
                        title: "RPE",
                        value: set.rpe.map { format($0) } ?? "-",
                        decrement: { repository.updateRPE((set.rpe ?? 7) - 0.5) },
                        increment: { repository.updateRPE((set.rpe ?? 7) + 0.5) }
                    )
                    EffortControl(
                        title: "RIR",
                        value: set.rir.map(String.init) ?? "-",
                        decrement: { repository.updateRIR((set.rir ?? 2) - 1) },
                        increment: { repository.updateRIR((set.rir ?? 2) + 1) }
                    )
                }
                .stackedWhenAccessibility(dynamicTypeSize)
            }
        }
    }
}

private struct ActiveWorkoutHeader: View {
    let session: ActiveWorkoutSession

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.dayName)
                            .font(.title2.weight(.semibold))
                        Text(session.planName)
                            .font(.subheadline)
                            .foregroundStyle(SpotterPalette.textSecondary)
                    }

                    Spacer()

                    WorkoutProgressRing(progress: session.progress)
                        .frame(width: 92, height: 92)
                }

                HStack(spacing: 10) {
                    ActiveMetricPill(title: session.currentExercise?.name ?? "Exercise", systemImage: "scope")
                    ActiveMetricPill(title: session.nextExercise?.name ?? "Last exercise", systemImage: "forward.end")
                }

                HStack(spacing: 10) {
                    ActiveMetricPill(title: "\(session.estimatedRemainingMinutes) min left", systemImage: "hourglass")
                    ActiveMetricPill(title: restText, systemImage: "timer")
                    ActiveMetricPill(title: "Saved \(session.lastAutosavedAt.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.icloud")
                }
            }
        }
    }

    private var restText: String {
        if session.restStartedAt == nil {
            return "Rest idle"
        }
        if session.restRemainingSeconds >= 0 {
            return "Rest \(formatTime(session.restRemainingSeconds))"
        }
        return "+\(formatTime(abs(session.restRemainingSeconds)))"
    }
}

private struct CurrentSetPanel: View {
    let session: ActiveWorkoutSession
    let exercise: ActiveWorkoutExercise
    let set: ActiveWorkoutSet
    @ObservedObject var repository: MockActiveWorkoutRepository
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(exercise.name)
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                        Text(setLabel)
                            .font(.headline)
                            .foregroundStyle(SpotterPalette.accentSoft)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(set.targetText)
                            .font(.headline.monospacedDigit())
                        Text("\(set.restSeconds)s rest")
                            .font(.caption)
                            .foregroundStyle(SpotterPalette.textSecondary)
                    }
                }

                switch set.kind {
                case .repsWeight:
                    HStack(spacing: 8) {
                        FastNumberControl(
                            title: "Reps",
                            value: "\(set.reps)",
                            inputMode: .integer,
                            decrement: { repository.updateReps(set.reps - 1) },
                            increment: { repository.updateReps(set.reps + 1) },
                            updateText: { text in
                                if let reps = Int(text) {
                                    repository.updateReps(reps)
                                }
                            }
                        )
                        FastNumberControl(
                            title: "Weight (kg)",
                            value: format(set.weight),
                            inputMode: .decimal,
                            decrement: { repository.updateWeight(set.weight - 2.5) },
                            increment: { repository.updateWeight(set.weight + 2.5) },
                            updateText: { text in
                                if let weight = Double(text.replacingOccurrences(of: ",", with: ".")) {
                                    repository.updateWeight(weight)
                                }
                            }
                        )
                    }
                    .stackedWhenAccessibility(dynamicTypeSize)
                case .duration:
                    FastNumberControl(
                        title: "Duration (s)",
                        value: "\(set.durationSeconds)",
                        inputMode: .integer,
                        decrement: { repository.updateDuration(set.durationSeconds - 5) },
                        increment: { repository.updateDuration(set.durationSeconds + 5) },
                        updateText: { text in
                            if let seconds = Int(text) {
                                repository.updateDuration(seconds)
                            }
                        }
                    )
                }

                HStack(spacing: 12) {
                    EffortControl(
                        title: "RPE",
                        value: set.rpe.map { format($0) } ?? "-",
                        decrement: { repository.updateRPE((set.rpe ?? 7) - 0.5) },
                        increment: { repository.updateRPE((set.rpe ?? 7) + 0.5) }
                    )
                    EffortControl(
                        title: "RIR",
                        value: set.rir.map(String.init) ?? "-",
                        decrement: { repository.updateRIR((set.rir ?? 2) - 1) },
                        increment: { repository.updateRIR((set.rir ?? 2) + 1) }
                    )
                }
                .stackedWhenAccessibility(dynamicTypeSize)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(SpotterPalette.accent.opacity(0.42), lineWidth: 1.5)
        }
    }

    private var setLabel: String {
        let prefix = set.isWarmup ? "Warm-up" : "Working"
        return "\(prefix) Set \(set.index) of \(exercise.sets.count)"
    }
}

private struct PreviousPerformanceCard: View {
    let suggestion: WorkoutLoggingSuggestion
    let applySuggestion: () -> Void

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Label("Previous", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                        .foregroundStyle(SpotterPalette.accentSoft)

                    Spacer()

                    Button(action: applySuggestion) {
                        Label(suggestion.reuseLabel, systemImage: "arrow.uturn.backward.circle")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reuse previous values")
                    .simultaneousGesture(TapGesture().onEnded {
                        SpotterHaptics.selection()
                    })
                }

                Text(suggestion.lastTime)
                    .font(.subheadline.weight(.medium))
                Text(suggestion.trend)
                    .font(.caption)
                    .foregroundStyle(SpotterPalette.textSecondary)
                if let warning = suggestion.warning {
                    Text(warning)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WorkoutExerciseList: View {
    let session: ActiveWorkoutSession
    @ObservedObject var repository: MockActiveWorkoutRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout")
                .font(.headline)

            VStack(spacing: 14) {
                ForEach(session.exercises) { exercise in
                    GlassCard(cornerRadius: 24, padding: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.headline)
                                    Text(exercise.nextNote)
                                        .font(.caption)
                                        .foregroundStyle(SpotterPalette.textSecondary)
                                }
                                Spacer()
                                Button {
                                    repository.addSet(to: exercise.id)
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.title3)
                                }
                                .accessibilityLabel("Add Set")
                            }

                            VStack(spacing: 8) {
                                ForEach(exercise.sets) { set in
                                    ActiveSetRow(
                                        exercise: exercise,
                                        set: set,
                                        isCurrent: exercise.id == session.currentExerciseId && set.id == session.currentSetId,
                                        repository: repository
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ActiveSetRow: View {
    let exercise: ActiveWorkoutExercise
    let set: ActiveWorkoutSet
    let isCurrent: Bool
    @ObservedObject var repository: MockActiveWorkoutRepository

    var body: some View {
        Button {
            SpotterHaptics.selection()
            repository.select(exerciseId: exercise.id, setId: set.id)
        } label: {
            HStack(spacing: 12) {
                Text(set.isWarmup ? "W\(set.index)" : "\(set.index)")
                    .font(.headline.monospacedDigit())
                    .frame(width: 38, height: 38)
                    .background(isCurrent ? SpotterPalette.accent.opacity(0.32) : .white.opacity(0.08), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(set.targetText)
                        .font(.subheadline.weight(.medium))
                    Text(set.resultText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(SpotterPalette.textSecondary)
                }

                Spacer()

                if set.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if set.isSkipped {
                    Image(systemName: "forward.end.circle")
                        .foregroundStyle(SpotterPalette.textTertiary)
                } else if isCurrent {
                    Text("Current")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SpotterPalette.accentSoft)
                }

                Button {
                    SpotterHaptics.impact(.light)
                    repository.removeSet(set.id, from: exercise.id)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(SpotterPalette.textTertiary)
                }
                .accessibilityLabel("Remove Set")
            }
            .padding(10)
            .background(isCurrent ? .white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isCurrent ? SpotterPalette.accent.opacity(0.42) : .white.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(exercise.name), set \(set.index), \(set.resultText)")
        .accessibilityHint(isCurrent ? "Current set. Double tap to keep selected." : "Double tap to select this set.")
    }
}

private struct ActiveWorkoutBottomBar: View {
    let set: ActiveWorkoutSet
    @ObservedObject var repository: MockActiveWorkoutRepository
    @ObservedObject var healthKitManager: HealthKitWorkoutManager
    @ObservedObject var liveActivityManager: ActiveWorkoutLiveActivityManager

    var body: some View {
        VStack(spacing: 10) {
            GlassButton(title: set.isCompleted ? "Completed" : "Complete Set", systemImage: "checkmark") {
                SpotterHaptics.notification(.success)
                repository.completeCurrentSet()
                healthKitManager.refreshMetrics()
                if let session = repository.session {
                    liveActivityManager.update(session: session)
                }
            }
            HStack(spacing: 10) {
                GlassButton(title: "Skip", systemImage: "forward.end", style: .secondary) {
                    SpotterHaptics.impact(.medium)
                    repository.skipCurrentSet()
                    if let session = repository.session {
                        liveActivityManager.update(session: session)
                    }
                }
                GlassButton(title: "Rest \(set.restSeconds)s", systemImage: "timer", style: .secondary)
            }
        }
    }
}

private struct HealthWorkoutPanel: View {
    let session: ActiveWorkoutSession
    @ObservedObject var healthKitManager: HealthKitWorkoutManager

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(SpotterPalette.accentSoft)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apple Workout")
                            .font(.headline)
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(SpotterPalette.textSecondary)
                    }

                    Spacer()

                    Button(action: toggleWorkout) {
                        Text(healthKitManager.isParallelWorkoutActive ? "End" : "Start")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    HealthMetricPill(
                        title: "Time",
                        value: formatTime(healthKitManager.durationSeconds),
                        systemImage: "timer"
                    )
                    HealthMetricPill(
                        title: "Energy",
                        value: "\(Int(healthKitManager.activeEnergyKilocalories.rounded())) kcal",
                        systemImage: "flame"
                    )
                    HealthMetricPill(
                        title: "Heart",
                        value: heartRateText,
                        systemImage: "waveform.path.ecg"
                    )
                }

                if let error = healthKitManager.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }
        }
    }

    private var statusText: String {
        if !healthKitManager.isHealthDataAvailable {
            return "Health unavailable on this device."
        }

        if healthKitManager.isParallelWorkoutActive {
            return "Saving duration, active energy and heart rate locally."
        }

        return "\(healthKitManager.authorizationStatusText). Optional parallel Apple workout."
    }

    private var heartRateText: String {
        guard let bpm = healthKitManager.currentHeartRateBPM else {
            return "-- bpm"
        }
        return "\(Int(bpm.rounded())) bpm"
    }

    private func toggleWorkout() {
        if healthKitManager.isParallelWorkoutActive {
            healthKitManager.finishParallelWorkout()
        } else {
            healthKitManager.startParallelWorkout(named: "\(session.planName) - \(session.dayName)")
        }
    }
}

private struct HealthMetricPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SpotterPalette.textSecondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(SpotterPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct FastNumberControl: View {
    enum InputMode {
        case integer
        case decimal
    }

    enum Prominence {
        case normal
        case focus
    }

    let title: String
    let value: String
    let inputMode: InputMode
    var prominence: Prominence = .normal
    let decrement: () -> Void
    let increment: () -> Void
    let updateText: (String) -> Void

    var body: some View {
        VStack(spacing: prominence == .focus ? 14 : 10) {
            Text(title)
                .font(prominence == .focus ? .headline.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(SpotterPalette.textSecondary)
            HStack(spacing: prominence == .focus ? 12 : 6) {
                StepButton(systemImage: "minus", action: decrement, size: prominence == .focus ? 48 : 34)
                EditableNumberText(
                    value: value,
                    inputMode: inputMode,
                    fontSize: prominence == .focus ? 46 : 28,
                    updateText: updateText
                )
                StepButton(systemImage: "plus", action: increment, size: prominence == .focus ? 48 : 34)
            }
        }
        .padding(prominence == .focus ? 18 : 12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: prominence == .focus ? 26 : 22, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct EditableNumberText: View {
    let value: String
    let inputMode: FastNumberControl.InputMode
    var fontSize: CGFloat = 28
    let updateText: (String) -> Void
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: textBinding)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .keyboardType(inputMode == .decimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .allowsTightening(true)
            .layoutPriority(1)
            .frame(maxWidth: .infinity)
            .focused($isFocused)
            .onAppear {
                text = value
            }
            .onChange(of: value) { _, newValue in
                guard !isFocused else { return }
                text = newValue
            }
            .toolbar {
                if isFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isFocused = false
                        }
                    }
                }
            }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                let sanitized = sanitize(newValue)
                text = sanitized
                guard !sanitized.isEmpty, sanitized != "." else { return }
                updateText(sanitized)
            }
        )
    }

    private func sanitize(_ rawValue: String) -> String {
        switch inputMode {
        case .integer:
            return rawValue.filter(\.isNumber)
        case .decimal:
            var output = ""
            var hasSeparator = false

            for character in rawValue.replacingOccurrences(of: ",", with: ".") {
                if character.isNumber {
                    output.append(character)
                } else if character == ".", !hasSeparator {
                    output.append(character)
                    hasSeparator = true
                }
            }

            return output
        }
    }
}

private struct EffortControl: View {
    let title: String
    let value: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SpotterPalette.textSecondary)
            HStack(spacing: 10) {
                StepButton(systemImage: "minus", action: decrement, size: 34)
                Text(value)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
                StepButton(systemImage: "plus", action: increment, size: 34)
            }
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct StepButton: View {
    let systemImage: String
    let action: () -> Void
    var size: CGFloat = 44

    var body: some View {
        Button {
            SpotterHaptics.selection()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .frame(width: size, height: size)
                .background(.thinMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemImage == "plus" ? "Increase" : "Decrease")
    }
}

private struct ActiveMetricPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(SpotterPalette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.08), in: Capsule())
            .overlay {
                Capsule().strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
            }
    }
}

func formatTime(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
}

private func format(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0
        ? "\(Int(value))"
        : String(format: "%.1f", value)
}

#Preview {
    ActiveWorkoutView(
        repository: MockActiveWorkoutRepository(),
        healthKitManager: HealthKitWorkoutManager(),
        liveActivityManager: ActiveWorkoutLiveActivityManager()
    )
        .preferredColorScheme(.dark)
}

private extension View {
    @ViewBuilder
    func stackedWhenAccessibility(_ dynamicTypeSize: DynamicTypeSize) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                self
            }
        } else {
            self
        }
    }
}
