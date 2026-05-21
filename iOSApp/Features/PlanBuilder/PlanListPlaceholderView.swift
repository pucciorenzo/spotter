import SpotterShared
import SwiftData
import SwiftUI

struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlanModel.updatedAt, order: .reverse) private var persistedPlans: [WorkoutPlanModel]
    let dataProvider: any SpotterDataProviding
    @ObservedObject var activeWorkoutRepository: MockActiveWorkoutRepository
    let showActiveWorkout: () -> Void
    @State private var searchText = ""
    @State private var showingCreatePlanEditor = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var plans: [SpotterPlanSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourcePlans = persistedPlans.isEmpty ? dataProvider.plans : persistedPlans.map(Self.makePlanSummary)
        guard !query.isEmpty else {
            return sourcePlans
        }

        return sourcePlans.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.suggestedDay.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PlansOverviewPanel(
                        totalPlans: plans.count,
                        totalDays: plans.reduce(0) { $0 + $1.days.count },
                        activePlanName: plans.first(where: \.isActive)?.name ?? plans.first?.name
                    )

                    if plans.isEmpty {
                        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            PlansEmptyState()
                        } else {
                            PlansSearchEmptyState()
                        }
                    } else {
                        HStack {
                            Text("All Plans")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(SpotterPalette.textPrimary)

                            Spacer()

                            Text("\(plans.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SpotterPalette.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.07), in: Capsule())
                        }
                        .padding(.horizontal, 2)

                        LazyVStack(spacing: 12) {
                            ForEach(plans) { plan in
                                NavigationLink {
                                    PlanDetailView(
                                        plan: plan,
                                        activeWorkoutRepository: activeWorkoutRepository,
                                        showActiveWorkout: showActiveWorkout
                                    )
                                } label: {
                                    PlanCard(plan: plan)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                    } label: {
                                        Label("Make Active", systemImage: "checkmark.circle")
                                    }

                                    Button {
                                    } label: {
                                        Label("Edit Plan", systemImage: "pencil")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 34)
            }

            if showingCreatePlanEditor {
                NewWorkoutPlanEditor(
                    reduceMotion: reduceMotion,
                    onCancel: closeCreatePlanEditor,
                    onSave: savePlan
                )
                .zIndex(2)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.86), value: showingCreatePlanEditor)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: plans.count)
        .navigationTitle("Plans")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Plans")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !showingCreatePlanEditor {
                    Button {
                        openCreatePlanEditor()
                    } label: {
                        PlanCreateToolbarButton()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create Workout Plan")
                }
            }
        }
        .toolbar(showingCreatePlanEditor ? .hidden : .visible, for: .navigationBar)
        .spotterScreenChrome()
    }

    private func openCreatePlanEditor() {
        SpotterHaptics.impact(.light)
        withAnimation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.86)) {
            showingCreatePlanEditor = true
        }
    }

    private func closeCreatePlanEditor() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.9)) {
            showingCreatePlanEditor = false
        }
    }

    private func savePlan(_ draft: WorkoutPlanDraft) throws {
        try SwiftDataWorkoutPlanRepository(context: modelContext).savePlan(draft.makeDTO())
        SpotterHaptics.notification(.success)
        closeCreatePlanEditor()
    }

    private static func makePlanSummary(from model: WorkoutPlanModel) -> SpotterPlanSummary {
        let dto = model.toDTO()
        return SpotterPlanSummary(
            id: dto.id,
            name: dto.name,
            days: dto.days.map { day in
                let count = day.exercises.count
                return SpotterPlanDaySummary(
                    id: day.id,
                    name: day.name,
                    focus: day.notes.isEmpty ? "Custom workout day" : day.notes,
                    exerciseCount: count,
                    estimatedDuration: count == 0 ? "No exercises" : "\(max(25, count * 12)) min",
                    exercises: day.exercises.enumerated().map { index, exercise in
                        SpotterPlannedExerciseSummary(
                            id: exercise.id,
                            name: "Exercise \(index + 1)",
                            target: "\(exercise.numberOfSets) sets",
                            load: exercise.startingLoad.map { "\($0.formatted()) kg" } ?? "No load",
                            rest: "\(exercise.restSeconds)s"
                        )
                    }
                )
            },
            lastUsed: "Not started",
            suggestedDay: dto.days.first?.name ?? "Add days",
            isActive: dto.isActive
        )
    }
}

private struct PlanCard: View {
    let plan: SpotterPlanSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                PlanGlyph(systemImage: "list.bullet.rectangle")

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(plan.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(SpotterPalette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        if plan.isActive {
                            Text("Active")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(SpotterPalette.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(SpotterPalette.accentSoft.opacity(0.20), in: Capsule())
                                .overlay {
                                    Capsule().strokeBorder(SpotterPalette.accentSoft.opacity(0.36), lineWidth: 1)
                                }
                    }
                    }

                    Text("\(plan.days.count) days - \(plan.suggestedDay)")
                        .font(.subheadline)
                        .foregroundStyle(SpotterPalette.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.05), in: Circle())
            }

            Divider()
                .overlay(.white.opacity(0.08))

            HStack(spacing: 10) {
                PlanInfoPill(title: plan.lastUsed, systemImage: "clock")
                PlanInfoPill(title: plan.suggestedDay, systemImage: "arrow.forward.circle")

                Spacer()

                if let nextDay = plan.days.first {
                    Text("\(nextDay.exerciseCount) moves")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SpotterPalette.textSecondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 0.8)
                .blur(radius: 0.7)
                .padding(1)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

private struct PlansOverviewPanel: View {
    let totalPlans: Int
    let totalDays: Int
    let activePlanName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training Library")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(SpotterPalette.textPrimary)

                    Text(activePlanName.map { "Next: \($0)" } ?? "Build plans around how you lift.")
                        .font(.subheadline)
                        .foregroundStyle(SpotterPalette.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                PlanGlyph(systemImage: "sparkles")
            }

            HStack(spacing: 10) {
                PlanOverviewMetric(value: "\(totalPlans)", title: "Plans")
                PlanOverviewMetric(value: "\(totalDays)", title: "Days")
                PlanOverviewMetric(value: activePlanName == nil ? "0" : "1", title: "Active")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black.opacity(0.20))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.13), lineWidth: 1)
        }
    }
}

private struct PlanOverviewMetric: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(SpotterPalette.textPrimary)
                .monospacedDigit()
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(SpotterPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PlanGlyph: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(SpotterPalette.textPrimary)
            .frame(width: 46, height: 46)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

private struct PlanCreateToolbarButton: View {
    var body: some View {
        Image(systemName: "plus")
            .font(.headline.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(SpotterPalette.textPrimary)
            .frame(width: 38, height: 38)
            .background(Color.black.opacity(0.14), in: Circle())
            .glassEffect(.regular.interactive(true), in: Circle())
            .overlay {
                Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
    }
}

private struct PlanDetailView: View {
    let plan: SpotterPlanSummary
    @ObservedObject var activeWorkoutRepository: MockActiveWorkoutRepository
    let showActiveWorkout: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PlanDetailHeader(plan: plan)

                    ForEach(plan.days) { day in
                        NavigationLink {
                            PlanDayDetailView(
                                day: day,
                                activeWorkoutRepository: activeWorkoutRepository,
                                showActiveWorkout: showActiveWorkout
                            )
                        } label: {
                            PlanDayRow(day: day)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }

            Button {
                SpotterHaptics.impact(.medium)
                activeWorkoutRepository.startMockWorkout()
                showActiveWorkout()
            } label: {
                PlanPrimaryActionLabel(title: "Start Workout", systemImage: "play.fill")
            }
            .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit Plan")
            }
        }
        .spotterScreenChrome()
    }
}

private struct PlanDetailHeader: View {
    let plan: SpotterPlanSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(plan.days.count) days".uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SpotterPalette.accentSoft)
                Text(plan.name)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textPrimary)
                    .lineLimit(2)
                Text("Changes apply forward. Completed logs keep their original plan snapshot.")
                    .font(.subheadline)
                    .foregroundStyle(SpotterPalette.textSecondary)
            }

            HStack(spacing: 10) {
                PlanOverviewMetric(value: "\(plan.days.count)", title: "Days")
                PlanOverviewMetric(value: "\(plan.days.reduce(0) { $0 + $1.exerciseCount })", title: "Exercises")
                PlanOverviewMetric(value: plan.isActive ? "On" : "Off", title: "Active")
            }
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct PlanDayRow: View {
    let day: SpotterPlanDaySummary

    var body: some View {
        HStack(spacing: 16) {
            PlanGlyph(systemImage: "calendar")

            VStack(alignment: .leading, spacing: 6) {
                Text(day.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textPrimary)
                Text(day.focus)
                    .font(.subheadline)
                    .foregroundStyle(SpotterPalette.textSecondary)
                    .lineLimit(1)
                Text("\(day.exerciseCount) exercises - \(day.estimatedDuration)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(SpotterPalette.accentSoft)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SpotterPalette.textTertiary)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.11), lineWidth: 1)
        }
    }
}

private struct PlanDayDetailView: View {
    let day: SpotterPlanDaySummary
    @ObservedObject var activeWorkoutRepository: MockActiveWorkoutRepository
    let showActiveWorkout: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PlanDayHeader(day: day)

                    VStack(spacing: 4) {
                        if day.exercises.isEmpty {
                            Text("No exercises in this day yet.")
                                .font(.subheadline)
                                .foregroundStyle(SpotterPalette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                        } else {
                            ForEach(Array(day.exercises.enumerated()), id: \.element.id) { index, exercise in
                                ExerciseRow(
                                    name: exercise.name,
                                    detail: exercise.target,
                                    metric: exercise.load
                                )
                                if index < day.exercises.count - 1 {
                                    Divider().overlay(.white.opacity(0.10))
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }

            Button {
                SpotterHaptics.impact(.medium)
                activeWorkoutRepository.startMockWorkout()
                showActiveWorkout()
            } label: {
                PlanPrimaryActionLabel(title: "Start Workout", systemImage: "play.fill")
            }
            .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
        .navigationTitle(day.name)
        .navigationBarTitleDisplayMode(.large)
        .spotterScreenChrome()
    }
}

private struct PlanDayHeader: View {
    let day: SpotterPlanDaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Day")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SpotterPalette.accentSoft)
                .textCase(.uppercase)
            Text(day.name)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(SpotterPalette.textPrimary)
            Text("\(day.focus) - \(day.estimatedDuration)")
                .font(.subheadline)
                .foregroundStyle(SpotterPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct PlanPrimaryActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(SpotterPalette.textPrimary)
            .background(SpotterPalette.accentSoft.opacity(0.28), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .glassEffect(.regular.tint(SpotterPalette.accentSoft.opacity(0.20)).interactive(true), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.20), lineWidth: 1)
            }
    }
}

private struct PlansEmptyState: View {
    var body: some View {
        VStack(spacing: 18) {
            PlanGlyph(systemImage: "list.bullet.clipboard")

            VStack(spacing: 7) {
                Text("No Plans")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textPrimary)
                Text("Use the glass plus button to build your first workout plan.")
                    .font(.subheadline)
                    .foregroundStyle(SpotterPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct PlansSearchEmptyState: View {
    var body: some View {
        VStack(spacing: 18) {
            PlanGlyph(systemImage: "magnifyingglass")

            VStack(spacing: 7) {
                Text("No Matching Plans")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textPrimary)
                Text("Try another search or create a new workout plan.")
                    .font(.subheadline)
                    .foregroundStyle(SpotterPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct WorkoutPlanDraft: Identifiable {
    let id = UUID()
    var name = ""
    var days: [WorkoutDayDraft] = [.makeDefault(index: 0, planId: UUID())]

    mutating func addDay() {
        days.append(.makeDefault(index: days.count, planId: id))
    }

    func makeDTO(now: Date = Date()) -> WorkoutPlanDTO {
        WorkoutPlanDTO(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: "",
            goal: "",
            days: days.enumerated().map { index, day in
                day.makeDTO(planId: id, orderIndex: index)
            },
            isActive: false,
            isArchived: false,
            createdAt: now,
            updatedAt: now
        )
    }
}

private struct WorkoutDayDraft: Identifiable {
    let id: UUID
    var name: String
    var exercises: [WorkoutExerciseDraft]

    static func makeDefault(index: Int, planId: UUID) -> WorkoutDayDraft {
        WorkoutDayDraft(id: UUID(), name: "Day \(index + 1)", exercises: [])
    }

    mutating func addExercise() {
        exercises.append(WorkoutExerciseDraft(name: "Exercise \(exercises.count + 1)"))
    }

    func makeDTO(planId: UUID, orderIndex: Int) -> WorkoutDayDTO {
        WorkoutDayDTO(
            id: id,
            planId: planId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Day \(orderIndex + 1)" : name,
            orderIndex: orderIndex,
            notes: "",
            exercises: exercises.enumerated().map { index, exercise in
                exercise.makeDTO(dayId: id, orderIndex: index)
            }
        )
    }
}

private struct WorkoutExerciseDraft: Identifiable {
    let id = UUID()
    let exerciseId = UUID()
    var name: String

    func makeDTO(dayId: UUID, orderIndex: Int) -> WorkoutExerciseDTO {
        WorkoutExerciseDTO(
            id: id,
            workoutDayId: dayId,
            exerciseId: exerciseId,
            orderIndex: orderIndex,
            numberOfSets: 3,
            warmupSets: 0,
            targetType: .fixedReps,
            targetReps: 10,
            targetRepsMin: nil,
            targetRepsMax: nil,
            targetDurationSeconds: nil,
            targetDurationMinSeconds: nil,
            targetDurationMaxSeconds: nil,
            startingLoad: nil,
            loadUnit: .kg,
            suggestedIncrement: nil,
            restSeconds: 90,
            rpeTarget: nil,
            rirTarget: nil,
            tempo: nil,
            notes: name,
            supersetGroupId: nil,
            autoProgressionEnabled: false
        )
    }
}

private struct NewWorkoutPlanEditor: View {
    let reduceMotion: Bool
    let onCancel: () -> Void
    let onSave: (WorkoutPlanDraft) throws -> Void
    @State private var draft = WorkoutPlanDraft()
    @State private var errorMessage: String?

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.36)
                .ignoresSafeArea()
                .onTapGesture {
                    SpotterHaptics.impact(.light)
                    onCancel()
                }

            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") {
                        SpotterHaptics.impact(.light)
                        onCancel()
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(SpotterPalette.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.07), in: Capsule())

                    Spacer()

                    Text("New Workout Plan")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(SpotterPalette.textPrimary)

                    Spacer()

                    Button("Save") {
                        save()
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(canSave ? SpotterPalette.textPrimary : SpotterPalette.textTertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(canSave ? .white.opacity(0.12) : .white.opacity(0.04), in: Capsule())
                    .disabled(!canSave)
                }
                .padding(.horizontal, 12)
                .frame(height: 64)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Plan Name")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SpotterPalette.textSecondary)
                                .textCase(.uppercase)

                            TextField("Workout plan name", text: $draft.name)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.done)
                                .font(.body.weight(.medium))
                                .padding(.horizontal, 16)
                                .frame(height: 54)
                                .foregroundStyle(SpotterPalette.textPrimary)
                                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
                                }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.red.opacity(0.9))
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Workout Days")
                                    .font(.title3.weight(.semibold))
                                Spacer()
                                Text("\(draft.days.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(SpotterPalette.textSecondary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(.white.opacity(0.08), in: Capsule())
                            }

                            ForEach($draft.days) { $day in
                                WorkoutDayDraftCard(day: $day)
                            }

                            Button {
                                SpotterHaptics.selection()
                                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
                                    draft.addDay()
                                }
                            } label: {
                                PlanGlassActionLabel(title: "Add Day", systemImage: "plus")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.28))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding(.top, 54)
            .ignoresSafeArea(edges: .bottom)
        }
        .preferredColorScheme(.dark)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func save() {
        guard canSave else {
            errorMessage = "Plan name required."
            return
        }

        do {
            try onSave(draft)
        } catch {
            errorMessage = "Could not save plan."
        }
    }
}

private struct WorkoutDayDraftCard: View {
    @Binding var day: WorkoutDayDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Day name", text: $day.name)
                .textInputAutocapitalization(.words)
                .font(.headline.weight(.semibold))
                .foregroundStyle(SpotterPalette.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                }

            if day.exercises.isEmpty {
                Text("No exercises yet.")
                    .font(.subheadline)
                    .foregroundStyle(SpotterPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(day.exercises) { exercise in
                        HStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SpotterPalette.accentSoft)
                                .frame(width: 30, height: 30)
                                .background(.white.opacity(0.07), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("Placeholder - 3 x 10, 90s rest")
                                    .font(.caption)
                                    .foregroundStyle(SpotterPalette.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }

            Button {
                SpotterHaptics.selection()
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    day.addExercise()
                }
            } label: {
                PlanGlassActionLabel(title: "Add Exercise", systemImage: "plus")
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct PlanGlassActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundStyle(SpotterPalette.textPrimary)
            .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
    }
}

private struct PlanInfoPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(SpotterPalette.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.07), in: Capsule())
    }
}

#Preview {
    NavigationStack {
        PlanListView(
            dataProvider: MockSpotterRepository.preview,
            activeWorkoutRepository: MockActiveWorkoutRepository(),
            showActiveWorkout: {}
        )
            .preferredColorScheme(.dark)
    }
}
