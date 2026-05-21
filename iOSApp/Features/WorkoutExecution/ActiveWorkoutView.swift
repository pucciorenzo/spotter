import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var repository: MockActiveWorkoutRepository
    @ObservedObject var healthKitManager: HealthKitWorkoutManager
    @ObservedObject var liveActivityManager: ActiveWorkoutLiveActivityManager
    @Environment(\.dismiss) private var dismiss
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                SpotterBackground()

                if let session = repository.session,
                   let currentExercise = session.currentExercise,
                   let currentSet = session.currentSet {
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
            .navigationTitle("Active Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if let session = repository.session {
                        Button {
                            togglePause(session: session)
                        } label: {
                            Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                        }
                        .accessibilityLabel(session.isPaused ? "Resume Workout" : "Pause Workout")

                        Button(role: .destructive) {
                            endWorkout(session: session)
                        } label: {
                            Image(systemName: "stop.fill")
                        }
                        .accessibilityLabel("End Workout")
                    }
                }
            }
            .spotterScreenChrome()
        }
        .onAppear {
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

    private func endWorkout(session: ActiveWorkoutSession) {
        liveActivityManager.end(session: session)
        healthKitManager.finishParallelWorkout()
        repository.endWorkout()
        dismiss()
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
                            decrement: { repository.updateReps(set.reps - 1) },
                            increment: { repository.updateReps(set.reps + 1) }
                        )
                        FastNumberControl(
                            title: "Weight",
                            value: "\(format(set.weight)) kg",
                            decrement: { repository.updateWeight(set.weight - 2.5) },
                            increment: { repository.updateWeight(set.weight + 2.5) }
                        )
                    }
                case .duration:
                    FastNumberControl(
                        title: "Duration",
                        value: "\(set.durationSeconds)s",
                        decrement: { repository.updateDuration(set.durationSeconds - 5) },
                        increment: { repository.updateDuration(set.durationSeconds + 5) }
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
                repository.completeCurrentSet()
                healthKitManager.refreshMetrics()
                if let session = repository.session {
                    liveActivityManager.update(session: session)
                }
            }
            HStack(spacing: 10) {
                GlassButton(title: "Skip", systemImage: "forward.end", style: .secondary) {
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
    let title: String
    let value: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SpotterPalette.textSecondary)
            HStack(spacing: 6) {
                StepButton(systemImage: "minus", action: decrement, size: 34)
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                    .layoutPriority(1)
                    .frame(maxWidth: .infinity)
                StepButton(systemImage: "plus", action: increment, size: 34)
            }
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .frame(width: size, height: size)
                .background(.thinMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
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
