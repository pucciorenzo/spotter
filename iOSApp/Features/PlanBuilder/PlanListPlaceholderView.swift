import SpotterShared
import SwiftData
import SwiftUI

struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlanModel.name) private var plans: [WorkoutPlanModel]
    @Query(sort: \ExerciseModel.name) private var exercises: [ExerciseModel]
    @State private var newWorkoutName = ""
    @State private var showingNewWorkoutPrompt = false

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(
                        eyebrow: "Plan",
                        title: activePlan?.name ?? "Training Week",
                        subtitle: activePlan?.goal.isEmpty == false ? activePlan?.goal ?? "" : "Built around steady progress and low-friction logging."
                    )

                    if planDays.isEmpty {
                        GlassCard {
                            Text("No workout days yet.")
                                .font(.subheadline)
                                .foregroundStyle(SpotterPalette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(planDays) { day in
                            NavigationLink {
                                WorkoutDayPrototypeView(
                                    plan: activePlan,
                                    day: day,
                                    exercises: exercises
                                )
                            } label: {
                                GlassCard {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(day.name)
                                                .font(.title3.weight(.semibold))
                                            Text(day.notes.isEmpty ? activePlan?.name ?? "Workout day" : day.notes)
                                                .font(.subheadline)
                                                .foregroundStyle(SpotterPalette.textSecondary)
                                            Text("\(day.exercises.count) exercises")
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(SpotterPalette.accentSoft)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right.circle.fill")
                                            .font(.title2)
                                            .symbolRenderingMode(.hierarchical)
                                            .foregroundStyle(SpotterPalette.accentSoft)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .spotterScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newWorkoutName = nextWorkoutName
                    showingNewWorkoutPrompt = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(SpotterPalette.accentSoft)
                }
                .accessibilityLabel("Create Workout")
            }
        }
        .alert("New Workout", isPresented: $showingNewWorkoutPrompt) {
            TextField("Name", text: $newWorkoutName)
            Button("Create") {
                createWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Create an active workout plan with one empty day.")
        }
    }

    private var activePlan: WorkoutPlanModel? {
        plans.first { $0.isActive && !$0.isArchived } ?? plans.first { !$0.isArchived }
    }

    private var planDays: [WorkoutDayModel] {
        activePlan?.days.sorted { $0.orderIndex < $1.orderIndex } ?? []
    }

    private var nextWorkoutName: String {
        "Workout \(plans.filter { !$0.isArchived }.count + 1)"
    }

    private func createWorkout() {
        let trimmedName = newWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = SpotterRepository.insertPlan(
            named: trimmedName.isEmpty ? nextWorkoutName : trimmedName,
            in: modelContext
        )

        for existingPlan in plans where existingPlan.id != plan.id {
            existingPlan.isActive = false
            existingPlan.updatedAt = Date()
        }

        _ = SpotterRepository.insertDay(named: "Day 1", into: plan)
    }
}

private struct WorkoutDayPrototypeView: View {
    let plan: WorkoutPlanModel?
    let day: WorkoutDayModel
    let exercises: [ExerciseModel]

    private var prescriptions: [WorkoutExerciseModel] {
        day.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(
                        eyebrow: "Workout Day",
                        title: day.name,
                        subtitle: plan?.name ?? "Workout"
                    )

                    GlassCard {
                        HStack(spacing: 18) {
                            WorkoutProgressRing(progress: 0.0)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(estimatedDurationText)
                                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                                Text("Estimated duration")
                                    .font(.subheadline)
                                    .foregroundStyle(SpotterPalette.textSecondary)
                                Text("\(warmupSetCount) warm-up sets included")
                                    .font(.caption)
                                    .foregroundStyle(SpotterPalette.accentSoft)
                            }
                            Spacer()
                        }
                    }

                    GlassCard {
                        if prescriptions.isEmpty {
                            Text("No exercises in this day.")
                                .font(.subheadline)
                                .foregroundStyle(SpotterPalette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(spacing: 4) {
                                ForEach(Array(prescriptions.enumerated()), id: \.element.id) { index, prescription in
                                    ExerciseRow(
                                        name: exerciseName(for: prescription.exerciseId),
                                        detail: targetText(for: prescription),
                                        metric: loadText(for: prescription)
                                    )
                                    if index < prescriptions.count - 1 {
                                        Divider().overlay(.white.opacity(0.10))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 116)
            }

            NavigationLink {
                ActiveWorkoutPrototypeView(
                    title: prescriptions.first.map { exerciseName(for: $0.exerciseId) } ?? day.name,
                    target: prescriptions.first.map(targetText(for:)) ?? "No target",
                    load: prescriptions.first.map(loadText(for:)) ?? "-"
                )
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [SpotterPalette.accent.opacity(0.94), SpotterPalette.accentSoft.opacity(0.70)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .buttonStyle(.plain)
            .disabled(prescriptions.isEmpty)
        }
        .spotterScreenChrome()
    }

    private var warmupSetCount: Int {
        prescriptions.reduce(0) { $0 + $1.warmupSets }
    }

    private var estimatedDurationText: String {
        let seconds = prescriptions.reduce(0) { total, prescription in
            total + ((prescription.numberOfSets + prescription.warmupSets) * max(prescription.restSeconds, 45))
        }
        let minutes = max(seconds / 60, prescriptions.isEmpty ? 0 : 20)
        return minutes == 0 ? "0 min" : "\(minutes) min"
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

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}

private struct ActiveWorkoutPrototypeView: View {
    let title: String
    let target: String
    let load: String

    private let loggedSets = [
        ("Warm-up", "12 reps x 40 kg"),
        ("Set 1", "8 reps x 80 kg"),
        ("Set 2", "8 reps x 80 kg")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(
                        eyebrow: "Active",
                        title: title,
                        subtitle: "Set 1 ready. Live execution remains prototype-only here."
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

                    GlassCard {
                        VStack(spacing: 12) {
                            ForEach(loggedSets, id: \.0) { set in
                                HStack {
                                    Text(set.0)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(set.1)
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(SpotterPalette.textSecondary)
                                }
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

#Preview {
    NavigationStack {
        PlanListView()
            .preferredColorScheme(.dark)
    }
}
