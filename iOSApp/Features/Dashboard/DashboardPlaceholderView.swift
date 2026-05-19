import SpotterShared
import SwiftData
import SwiftUI

struct DashboardPlaceholderView: View {
    @Query(sort: \WorkoutPlanModel.name) private var plans: [WorkoutPlanModel]
    @Query(sort: \ExerciseModel.name) private var exercises: [ExerciseModel]
    @Query(sort: \WorkoutSessionModel.startedAt, order: .reverse) private var sessions: [WorkoutSessionModel]

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(
                        eyebrow: "Today",
                        title: "spotter",
                        subtitle: headerSubtitle
                    )

                    GlassCard {
                        HStack(alignment: .center, spacing: 18) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(nextDay?.name ?? "No Active Day")
                                    .font(.title2.weight(.semibold))
                                Text(activePlan?.name ?? "Create or activate a plan to start.")
                                    .font(.subheadline)
                                    .foregroundStyle(SpotterPalette.textSecondary)

                                HStack(spacing: 10) {
                                    MainWorkoutInfoPill(title: "\(nextPrescriptions.count) exercises", systemImage: "list.bullet")
                                    MainWorkoutInfoPill(title: estimatedDurationText, systemImage: "timer")
                                }
                            }

                            Spacer()

                            WorkoutProgressRing(progress: weeklyProgress)
                        }
                    }

                    if activeWorkoutSession == nil, let nextDay, !nextPrescriptions.isEmpty {
                        NavigationLink {
                            HomeActiveWorkoutView(
                                dayName: nextDay.name,
                                exerciseName: exerciseName(for: nextPrescriptions[0].exerciseId),
                                target: targetText(for: nextPrescriptions[0]),
                                load: loadText(for: nextPrescriptions[0])
                            )
                        } label: {
                            StartWorkoutButtonLabel()
                        }
                        .buttonStyle(.plain)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        MetricCard(title: "Week", value: "\(thisWeekSessions.count)", caption: "workouts", systemImage: "calendar")
                        MetricCard(title: "Volume", value: volumeText(for: thisWeekSessions), caption: "kg logged", systemImage: "chart.bar.fill")
                        MetricCard(title: "Sets", value: "\(completedSetCount(in: thisWeekSessions))", caption: "completed", systemImage: "checkmark.circle.fill")
                        MetricCard(title: "Time", value: durationText(for: thisWeekSessions), caption: "training", systemImage: "timer")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next Exercises")
                            .font(.headline)

                        GlassCard {
                            if nextPrescriptions.isEmpty {
                                Text("Add exercises to your active workout day.")
                                    .font(.subheadline)
                                    .foregroundStyle(SpotterPalette.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(spacing: 4) {
                                    ForEach(Array(nextPrescriptions.prefix(4).enumerated()), id: \.element.id) { index, prescription in
                                        ExerciseRow(
                                            name: exerciseName(for: prescription.exerciseId),
                                            detail: targetText(for: prescription),
                                            metric: loadText(for: prescription)
                                        )
                                        if index < min(nextPrescriptions.count, 4) - 1 {
                                            Divider().overlay(.white.opacity(0.10))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .scrollContentBackground(.hidden)
        .spotterScreenChrome()
    }

    private var activePlan: WorkoutPlanModel? {
        plans.first { $0.isActive && !$0.isArchived } ?? plans.first { !$0.isArchived }
    }

    private var nextDay: WorkoutDayModel? {
        activePlan?.days.sorted { $0.orderIndex < $1.orderIndex }.first
    }

    private var nextPrescriptions: [WorkoutExerciseModel] {
        nextDay?.exercises.sorted { $0.orderIndex < $1.orderIndex } ?? []
    }

    private var activeWorkoutSession: WorkoutSessionModel? {
        sessions.first { $0.status == .inProgress }
    }

    private var headerSubtitle: String {
        guard let activePlan else {
            return "Set up a plan and Spotter will keep today focused."
        }

        return "\(activePlan.name) is ready. Keep pace calm and precise."
    }

    private var estimatedDurationText: String {
        let seconds = nextPrescriptions.reduce(0) { total, prescription in
            total + ((prescription.numberOfSets + prescription.warmupSets) * max(prescription.restSeconds, 45))
        }
        let minutes = max(seconds / 60, nextPrescriptions.isEmpty ? 0 : 20)
        return minutes == 0 ? "0 min" : "\(minutes) min"
    }

    private var weeklyProgress: Double {
        guard let activePlan, !activePlan.days.isEmpty else { return 0 }
        return min(Double(thisWeekSessions.count) / Double(max(activePlan.days.count, 1)), 1)
    }

    private var thisWeekSessions: [WorkoutSessionModel] {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }

        return sessions.filter { $0.status == .completed && interval.contains($0.startedAt) }
    }

    private func exerciseName(for id: UUID) -> String {
        exercises.first { $0.id == id }?.name ?? "Exercise"
    }

    private func targetText(for prescription: WorkoutExerciseModel) -> String {
        if let seconds = prescription.targetDurationSeconds {
            return "\(prescription.numberOfSets) sets x \(seconds)s"
        }

        if let min = prescription.targetRepsMin, let max = prescription.targetRepsMax {
            return "\(prescription.numberOfSets) sets x \(min)-\(max) reps"
        }

        if let reps = prescription.targetReps {
            return "\(prescription.numberOfSets) sets x \(reps) reps"
        }

        return "\(prescription.numberOfSets) sets"
    }

    private func loadText(for prescription: WorkoutExerciseModel) -> String {
        guard let load = prescription.startingLoad, load > 0 else {
            return "\(prescription.restSeconds)s"
        }

        return "\(format(load)) \(prescription.loadUnit.rawValue)"
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

        guard volume > 0 else { return "0" }
        return volume >= 1_000 ? String(format: "%.1fk", volume / 1_000) : format(volume)
    }

    private func durationText(for sessions: [WorkoutSessionModel]) -> String {
        let minutes = sessions.reduce(0) { $0 + $1.durationSeconds } / 60
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}

private struct StartWorkoutButtonLabel: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.fill")
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
            Text("Start Workout")
                .font(.headline.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SpotterPalette.textSecondary)
        }
        .foregroundStyle(SpotterPalette.textPrimary)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    SpotterPalette.accent.opacity(0.92),
                    SpotterPalette.accentSoft.opacity(0.68)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 22, y: 14)
    }
}

private struct HomeActiveWorkoutView: View {
    let dayName: String
    let exerciseName: String
    let target: String
    let load: String

    var body: some View {
        ZStack(alignment: .bottom) {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(
                        eyebrow: dayName,
                        title: exerciseName,
                        subtitle: "Ready to begin. Live execution controls remain prototype-only here."
                    )

                    GlassCard {
                        VStack(spacing: 20) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Target")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(SpotterPalette.textSecondary)
                                    Text(target)
                                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.7)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 6) {
                                    Text("Load")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(SpotterPalette.textSecondary)
                                    Text(load)
                                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                            }

                            ProgressView(value: 0.0)
                                .tint(SpotterPalette.accentSoft)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Rest")
                                .font(.headline)
                            HStack(alignment: .lastTextBaseline) {
                                Text("00:00")
                                    .font(.system(size: 54, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                Spacer()
                                Text("not started")
                                    .font(.caption)
                                    .foregroundStyle(SpotterPalette.textSecondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 132)
            }

            VStack(spacing: 10) {
                GlassButton(title: "Complete Set", systemImage: "checkmark")
                HStack(spacing: 10) {
                    GlassButton(title: "Skip", systemImage: "forward.end", style: .secondary)
                    GlassButton(title: "Swap", systemImage: "arrow.triangle.2.circlepath", style: .secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .spotterScreenChrome()
    }
}

private struct MainWorkoutInfoPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(SpotterPalette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.08), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
            }
    }
}

#Preview {
    NavigationStack {
        DashboardPlaceholderView()
            .preferredColorScheme(.dark)
    }
}
