import SpotterShared
import SwiftData
import SwiftUI

struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlanModel.updatedAt, order: .reverse) private var persistedPlans: [WorkoutPlanModel]
    @Query(sort: \ExerciseModel.name) private var persistedExercises: [ExerciseModel]
    let dataProvider: any SpotterDataProviding
    @ObservedObject var activeWorkoutRepository: MockActiveWorkoutRepository
    let showActiveWorkout: () -> Void
    @State private var searchText = ""
    @State private var showingCreatePlanEditor = false
    @State private var showsNavigationTitle = false
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

    private var exerciseLibrary: [SpotterExerciseSummary] {
        if persistedExercises.isEmpty {
            return dataProvider.exercises
        }

        return persistedExercises
            .filter { !$0.isArchived }
            .map(Self.makeExerciseSummary)
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
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, SpotterLayout.bottomScrollClearance)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > 24
            } action: { _, isScrolled in
                showsNavigationTitle = isScrolled
            }

            if showingCreatePlanEditor {
                NewWorkoutPlanEditor(
                    exerciseLibrary: exerciseLibrary,
                    reduceMotion: reduceMotion,
                    onCancel: closeCreatePlanEditor,
                    onSave: savePlan
                )
                .zIndex(2)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.86), value: showingCreatePlanEditor)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: plans.count)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Plans")
        .toolbar {
            ToolbarItem(placement: .principal) {
                SpotterInlineNavigationTitle(title: "Plans", isVisible: showsNavigationTitle)
            }

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
                            name: Self.exerciseDisplayName(for: exercise, index: index),
                            target: Self.exerciseTargetSummary(for: exercise),
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

    private static func exerciseDisplayName(for exercise: WorkoutExerciseDTO, index: Int) -> String {
        let trimmedNotes = exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNotes.isEmpty else {
            return "Exercise \(index + 1)"
        }

        if let firstLine = trimmedNotes.components(separatedBy: .newlines).first,
           firstLine.hasPrefix("Name:") {
            let name = firstLine.replacingOccurrences(of: "Name:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? "Exercise \(index + 1)" : name
        }

        return trimmedNotes.components(separatedBy: .newlines).first ?? "Exercise \(index + 1)"
    }

    private static func exerciseTargetSummary(for exercise: WorkoutExerciseDTO) -> String {
        switch exercise.targetType {
        case .fixedDuration:
            "\(exercise.numberOfSets) x \(exercise.targetDurationSeconds ?? 0)s"
        case .amrap:
            "\(exercise.numberOfSets) AMRAP"
        case .repRange:
            "\(exercise.numberOfSets) x \(exercise.targetRepsMin ?? 0)-\(exercise.targetRepsMax ?? 0)"
        case .durationRange:
            "\(exercise.numberOfSets) x \(exercise.targetDurationMinSeconds ?? 0)-\(exercise.targetDurationMaxSeconds ?? 0)s"
        case .fixedReps:
            "\(exercise.numberOfSets) x \(exercise.targetReps ?? 0)"
        }
    }

    private static func makeExerciseSummary(from model: ExerciseModel) -> SpotterExerciseSummary {
        SpotterExerciseSummary(
            id: model.id,
            name: model.name,
            primaryCategory: model.primaryMuscleGroup.isEmpty ? model.category.rawValue.capitalized : model.primaryMuscleGroup,
            secondaryCategories: model.secondaryMuscleGroups,
            equipment: model.equipment.rawValue.capitalized,
            movementPattern: model.category.rawValue.capitalized,
            trackingType: model.defaultMeasurementType == .duration ? "Time" : "Reps + Weight",
            notes: model.notes
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
                .padding(.bottom, SpotterLayout.bottomScrollClearance)
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
                .padding(.bottom, SpotterLayout.bottomPinnedActionClearance)
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
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
                .padding(.bottom, SpotterLayout.bottomScrollClearance)
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
                .padding(.bottom, SpotterLayout.bottomPinnedActionClearance)
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

    mutating func addExercise(from library: [SpotterExerciseSummary]) {
        guard let exercise = library.first else {
            return
        }
        exercises.append(WorkoutExerciseDraft(exercise: exercise))
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

private enum PlanExerciseExecutionMode: String, CaseIterable, Identifiable {
    case normal
    case endurance
    case mav
    case rm
    case amrap
    case dropset
    case superset
    case circuit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .endurance: "Endurance"
        case .mav: "MAV"
        case .rm: "RM"
        case .amrap: "AMRAP"
        case .dropset: "Dropset"
        case .superset: "Superset"
        case .circuit: "Circuit"
        }
    }

    var caption: String {
        switch self {
        case .normal: "Fixed reps"
        case .endurance: "Timed sets"
        case .mav: "+2.5% steps"
        case .rm: "Rep max"
        case .amrap: "As many reps"
        case .dropset: "No-rest drops"
        case .superset: "Back-to-back"
        case .circuit: "Rounds"
        }
    }

    var systemImage: String {
        switch self {
        case .normal: "number"
        case .endurance: "timer"
        case .mav: "chart.line.uptrend.xyaxis"
        case .rm: "target"
        case .amrap: "infinity"
        case .dropset: "arrow.down.right.circle"
        case .superset: "link"
        case .circuit: "repeat.circle"
        }
    }

    var targetType: SetTargetType {
        switch self {
        case .endurance:
            .fixedDuration
        case .amrap:
            .amrap
        case .normal, .mav, .rm, .dropset, .superset, .circuit:
            .fixedReps
        }
    }

    var showsEditableSetTargets: Bool {
        switch self {
        case .mav, .dropset:
            true
        case .normal, .endurance, .rm, .amrap, .superset, .circuit:
            false
        }
    }

    var showsStructurePreview: Bool {
        switch self {
        case .superset, .circuit:
            true
        case .normal, .endurance, .mav, .rm, .amrap, .dropset:
            false
        }
    }

    var supportsWarmups: Bool {
        switch self {
        case .normal, .endurance, .mav:
            true
        case .rm, .amrap, .dropset, .superset, .circuit:
            false
        }
    }
}

private struct PlannedSetDraft: Identifiable {
    let id = UUID()
    var index: Int
    var isWarmup: Bool
    var reps: Int
    var weight: Double
    var durationSeconds: Int

    var title: String {
        isWarmup ? "Warm-up \(index + 1)" : "Set \(index + 1)"
    }
}

private struct WorkoutExerciseDraft: Identifiable {
    let id = UUID()
    var exerciseId: UUID
    var name: String
    var executionMode: PlanExerciseExecutionMode = .normal
    var setCount = 3
    var warmupSets = 0
    var restSeconds = 90
    var baseReps = 10
    var baseWeight = 0.0
    var durationSeconds = 45
    var incrementPercent = 2.5
    var targetRM = 1
    var timeLimitSeconds: Int?
    var restBetweenExercisesSeconds = 0
    var linkedExerciseId: UUID?
    var linkedExerciseName = "Second exercise"
    var circuitExercises: [SpotterExerciseSummary] = []
    var notes = ""
    var plannedSets: [PlannedSetDraft]

    init(exercise: SpotterExerciseSummary) {
        self.exerciseId = exercise.id
        self.name = exercise.name
        self.plannedSets = Self.makeSets(
            mode: .normal,
            setCount: 3,
            warmupSets: 0,
            baseReps: 10,
            baseWeight: 0,
            durationSeconds: 45,
            incrementPercent: 2.5
        )
    }

    var summary: String {
        switch executionMode {
        case .endurance:
            "\(setCount) x \(durationSeconds)s, \(restSeconds)s rest"
        case .mav:
            "\(setCount) sets @ +\(incrementPercent.cleanWeight)%, \(restSeconds)s rest"
        case .rm:
            "\(targetRM)RM @ \(baseWeight.cleanWeight)kg, est \(estimatedOneRM.cleanWeight)kg"
        case .amrap:
            "AMRAP @ \(baseWeight.cleanWeight)kg, \(restSeconds)s rest"
        case .dropset:
            "\(setCount) drops, \(baseReps) reps, \(restSeconds)s between"
        case .superset:
            "\(setCount) rounds with \(linkedExerciseName), \(restSeconds)s rest"
        case .circuit:
            "\(setCount) rounds, \(restBetweenExercisesSeconds)s between moves"
        case .normal:
            "\(setCount) x \(baseReps), \(restSeconds)s rest"
        }
    }

    var circuitExercisesText: String {
        circuitExercises.map(\.name).joined(separator: ", ")
    }

    var helperText: String {
        switch executionMode {
        case .normal:
            "Same target across sets. Edit any set below."
        case .endurance:
            "Timed target for planks, holds, carries, intervals."
        case .mav:
            "Start from first set. Weight increases by chosen percent each set."
        case .rm:
            "Plan a rep-max attempt. Actual result is logged during workout."
        case .amrap:
            "Plan load and optional time cap. Actual reps are logged during workout."
        case .dropset:
            "Reduce weight and keep going with little or no rest."
        case .superset:
            "Pair two exercises back-to-back, then rest after each round."
        case .circuit:
            "Group multiple exercises into rounds. Useful for timer-heavy work."
        }
    }

    var estimatedOneRM: Double {
        guard baseReps > 0 else {
            return baseWeight
        }
        return baseWeight * (1 + Double(baseReps) / 30)
    }

    mutating func setMode(_ mode: PlanExerciseExecutionMode) {
        executionMode = mode
        if mode == .rm {
            setCount = 1
            warmupSets = 0
            baseReps = targetRM
        } else if mode == .amrap {
            setCount = 1
            warmupSets = 0
        } else if mode == .dropset {
            warmupSets = 0
            setCount = max(setCount, 3)
        }
        rebuildSets()
    }

    mutating func updateSetCount(_ value: Int) {
        setCount = min(max(value, 1), 12)
        warmupSets = executionMode.supportsWarmups ? min(warmupSets, setCount - 1) : 0
        rebuildSets()
    }

    mutating func updateWarmupSets(_ value: Int) {
        warmupSets = min(max(value, 0), max(setCount - 1, 0))
        rebuildSets()
    }

    mutating func updateBaseReps(_ value: Int) {
        baseReps = min(max(value, 1), 50)
        rebuildSets()
    }

    mutating func updateBaseWeight(_ value: Double) {
        baseWeight = max(value, 0)
        rebuildSets()
    }

    mutating func updateDuration(_ value: Int) {
        durationSeconds = min(max(value, 10), 600)
        rebuildSets()
    }

    mutating func updateRest(_ value: Int) {
        restSeconds = min(max(value, 0), 600)
    }

    mutating func updateIncrementPercent(_ value: Double) {
        incrementPercent = min(max(value, 0), 10)
        rebuildSets()
    }

    mutating func updateTargetRM(_ value: Int) {
        targetRM = min(max(value, 1), 20)
        baseReps = targetRM
        rebuildSets()
    }

    mutating func updateRestBetweenExercises(_ value: Int) {
        restBetweenExercisesSeconds = min(max(value, 0), 300)
    }

    mutating func selectExercise(_ exercise: SpotterExerciseSummary) {
        exerciseId = exercise.id
        name = exercise.name
    }

    mutating func selectLinkedExercise(_ exercise: SpotterExerciseSummary) {
        linkedExerciseId = exercise.id
        linkedExerciseName = exercise.name
    }

    mutating func addCircuitExercise(_ exercise: SpotterExerciseSummary) {
        guard !circuitExercises.contains(where: { $0.id == exercise.id }) else {
            return
        }
        circuitExercises.append(exercise)
    }

    mutating func removeCircuitExercise(id: UUID) {
        circuitExercises.removeAll { $0.id == id }
    }

    mutating func rebuildSets() {
        plannedSets = Self.makeSets(
            mode: executionMode,
            setCount: setCount,
            warmupSets: executionMode.supportsWarmups ? warmupSets : 0,
            baseReps: baseReps,
            baseWeight: baseWeight,
            durationSeconds: durationSeconds,
            incrementPercent: incrementPercent
        )
    }

    func makeDTO(dayId: UUID, orderIndex: Int) -> WorkoutExerciseDTO {
        let firstWorkingSet = plannedSets.first { !$0.isWarmup } ?? plannedSets.first
        let targetReps = executionMode == .endurance || executionMode == .amrap ? nil : firstWorkingSet?.reps
        let targetDuration = executionMode == .endurance ? firstWorkingSet?.durationSeconds : nil
        let startingLoad = executionMode == .endurance ? nil : firstWorkingSet?.weight
        let planNotes = makePlanNotes()
        let supersetId = executionMode == .superset ? id : nil

        return WorkoutExerciseDTO(
            id: id,
            workoutDayId: dayId,
            exerciseId: exerciseId,
            orderIndex: orderIndex,
            numberOfSets: plannedSets.count,
            warmupSets: executionMode.supportsWarmups ? warmupSets : 0,
            targetType: executionMode.targetType,
            targetReps: targetReps,
            targetRepsMin: nil,
            targetRepsMax: nil,
            targetDurationSeconds: targetDuration,
            targetDurationMinSeconds: nil,
            targetDurationMaxSeconds: nil,
            startingLoad: startingLoad,
            loadUnit: .kg,
            suggestedIncrement: executionMode == .mav ? incrementPercent : nil,
            restSeconds: restSeconds,
            rpeTarget: nil,
            rirTarget: nil,
            tempo: nil,
            notes: planNotes,
            supersetGroupId: supersetId,
            autoProgressionEnabled: executionMode == .mav
        )
    }

    private func makePlanNotes() -> String {
        let setSummary = plannedSets.map { set in
            if executionMode == .endurance {
                "\(set.title): \(set.durationSeconds)s"
            } else {
                "\(set.title): \(set.reps) reps @ \(set.weight.cleanWeight) kg"
            }
        }
        .joined(separator: "; ")
        var parts = [
            "Name: \(name.trimmingCharacters(in: .whitespacesAndNewlines))",
            "Mode: \(executionMode.title)",
            "Rest: \(restSeconds)s",
            setSummary
        ]
        switch executionMode {
        case .mav:
            parts.append("Increment: \(incrementPercent.cleanWeight)%")
        case .rm:
            parts.append("Target RM: \(targetRM)")
            parts.append("Estimated 1RM: \(estimatedOneRM.cleanWeight) kg")
        case .amrap:
            if let timeLimitSeconds {
                parts.append("Time cap: \(timeLimitSeconds)s")
            }
        case .superset:
            parts.append("Linked exercise: \(linkedExerciseName)")
        case .circuit:
            parts.append("Exercises: \(circuitExercisesText.isEmpty ? name : circuitExercisesText)")
            parts.append("Rest between exercises: \(restBetweenExercisesSeconds)s")
        case .dropset, .normal, .endurance:
            break
        }
        if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(notes.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return parts.joined(separator: "\n")
    }

    private static func makeSets(
        mode: PlanExerciseExecutionMode,
        setCount: Int,
        warmupSets: Int,
        baseReps: Int,
        baseWeight: Double,
        durationSeconds: Int,
        incrementPercent: Double
    ) -> [PlannedSetDraft] {
        (0..<setCount).map { index in
            let isWarmup = index < warmupSets
            let workingIndex = max(index - warmupSets, 0)
            let factor = pow(1 + incrementPercent / 100, Double(workingIndex))
            let reps: Int
            let weight: Double

            switch mode {
            case .mav:
                reps = baseReps
                weight = (baseWeight * factor).roundedToHalf
            case .dropset:
                reps = baseReps
                weight = max(0, (baseWeight * pow(0.85, Double(index))).roundedToHalf)
            case .rm, .amrap, .normal, .superset, .circuit:
                reps = baseReps
                weight = baseWeight
            case .endurance:
                reps = 0
                weight = 0
            }

            return PlannedSetDraft(
                index: index,
                isWarmup: isWarmup,
                reps: reps,
                weight: weight,
                durationSeconds: durationSeconds
            )
        }
    }
}

private struct NewWorkoutPlanEditor: View {
    let exerciseLibrary: [SpotterExerciseSummary]
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
                                WorkoutDayDraftCard(day: $day, exerciseLibrary: exerciseLibrary)
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
                    .padding(.bottom, SpotterLayout.bottomScrollClearance)
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
    let exerciseLibrary: [SpotterExerciseSummary]

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
                PlanEmptyInlineMessage(
                    title: "No exercises yet",
                    detail: exerciseLibrary.isEmpty ? "Create exercises in the Exercises tab first." : "Add one, choose the set style, rest time, and targets."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach($day.exercises) { $exercise in
                        WorkoutExerciseDraftCard(exercise: $exercise, exerciseLibrary: exerciseLibrary)
                    }
                }
            }

            Button {
                SpotterHaptics.selection()
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    day.addExercise(from: exerciseLibrary)
                }
            } label: {
                PlanGlassActionLabel(title: "Add Exercise", systemImage: "plus")
            }
            .buttonStyle(.plain)
            .disabled(exerciseLibrary.isEmpty)
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

private struct WorkoutExerciseDraftCard: View {
    @Binding var exercise: WorkoutExerciseDraft
    let exerciseLibrary: [SpotterExerciseSummary]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            PlanModePicker(selectedMode: exercise.executionMode) { mode in
                SpotterHaptics.selection()
                withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86)) {
                    exercise.setMode(mode)
                }
            }

            Text(exercise.helperText)
                .font(.caption)
                .foregroundStyle(SpotterPalette.textSecondary)

            controlGrid

            if exercise.executionMode.showsEditableSetTargets {
                PlanGeneratedSetsEditor(exercise: $exercise)
            } else if exercise.executionMode.showsStructurePreview {
                PlanStructurePreview(exercise: exercise)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textSecondary)
                    .textCase(.uppercase)

                TextField("Tempo, cue, setup note", text: $exercise.notes, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.footnote)
                    .foregroundStyle(SpotterPalette.textPrimary)
                    .padding(12)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                    }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.executionMode.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SpotterPalette.accentSoft)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.08), in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                PlanExerciseMenu(
                    selectedName: exercise.name,
                    exerciseLibrary: exerciseLibrary
                ) { selected in
                    exercise.selectExercise(selected)
                }

                Text(exercise.summary)
                    .font(.caption)
                    .foregroundStyle(SpotterPalette.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(.white.opacity(0.052), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var controlGrid: some View {
        VStack(spacing: 10) {
            switch exercise.executionMode {
            case .normal:
                basicSetControls(setTitle: "Sets")
                repsAndRestControls(repsTitle: "Reps", restTitle: "Rest")
                weightControl(title: "Weight")

            case .endurance:
                basicSetControls(setTitle: "Sets")
                PlanResponsivePair {
                    PlanIntegerControl(title: "Duration", value: exercise.durationSeconds, suffix: "s", range: 10...600, step: 5) { value in
                        exercise.updateDuration(value)
                    }
                } trailing: {
                    PlanIntegerControl(title: "Rest", value: exercise.restSeconds, suffix: "s", range: 0...600, step: 15) { value in
                        exercise.updateRest(value)
                    }
                }

            case .mav:
                basicSetControls(setTitle: "Sets")
                repsAndRestControls(repsTitle: "Target Reps", restTitle: "Rest")
                weightControl(title: "Starting Weight")
                PlanDoubleControl(title: "Increment", value: exercise.incrementPercent, suffix: "%", range: 0...10, step: 0.5) { value in
                    exercise.updateIncrementPercent(value)
                }

            case .rm:
                PlanResponsivePair {
                    PlanIntegerControl(title: "Target RM", value: exercise.targetRM, suffix: "RM", range: 1...20, step: 1) { value in
                        exercise.updateTargetRM(value)
                    }
                } trailing: {
                    PlanIntegerControl(title: "Rest", value: exercise.restSeconds, suffix: "s", range: 0...600, step: 15) { value in
                        exercise.updateRest(value)
                    }
                }
                weightControl(title: "Attempt Weight")
                PlanEstimatePill(title: "Estimated 1RM", value: "\(exercise.estimatedOneRM.cleanWeight) kg")

            case .amrap:
                PlanResponsivePair {
                    PlanIntegerControl(title: "Rest", value: exercise.restSeconds, suffix: "s", range: 0...600, step: 15) { value in
                        exercise.updateRest(value)
                    }
                } trailing: {
                    PlanOptionalIntControl(title: "Time Cap", value: exercise.timeLimitSeconds, range: 15...900, step: 15) { value in
                        exercise.timeLimitSeconds = value
                    }
                }
                weightControl(title: "Target Weight")

            case .dropset:
                PlanResponsivePair {
                    PlanIntegerControl(title: "Drops", value: exercise.setCount, suffix: nil, range: 2...8, step: 1) { value in
                        exercise.updateSetCount(value)
                    }
                } trailing: {
                    PlanIntegerControl(title: "Rest Between", value: exercise.restSeconds, suffix: "s", range: 0...120, step: 5) { value in
                        exercise.updateRest(value)
                    }
                }
                PlanIntegerControl(title: "Target Reps", value: exercise.baseReps, suffix: nil, range: 1...50, step: 1) { value in
                    exercise.updateBaseReps(value)
                }
                weightControl(title: "Initial Weight")

            case .superset:
                PlanResponsivePair {
                    PlanIntegerControl(title: "Sets", value: exercise.setCount, suffix: nil, range: 1...12, step: 1) { value in
                        exercise.updateSetCount(value)
                    }
                } trailing: {
                    PlanIntegerControl(title: "Rest After Round", value: exercise.restSeconds, suffix: "s", range: 0...600, step: 15) { value in
                        exercise.updateRest(value)
                    }
                }
                PlanIntegerControl(title: "Reps Per Exercise", value: exercise.baseReps, suffix: nil, range: 1...50, step: 1) { value in
                    exercise.updateBaseReps(value)
                }
                PlanExercisePickerControl(
                    title: "Linked Exercise",
                    selectedName: exercise.linkedExerciseName,
                    exerciseLibrary: exerciseLibrary.filter { $0.id != exercise.exerciseId }
                ) { selected in
                    exercise.selectLinkedExercise(selected)
                }

            case .circuit:
                PlanResponsivePair {
                    PlanIntegerControl(title: "Rounds", value: exercise.setCount, suffix: nil, range: 1...12, step: 1) { value in
                        exercise.updateSetCount(value)
                    }
                } trailing: {
                    PlanIntegerControl(title: "Rest After Round", value: exercise.restSeconds, suffix: "s", range: 0...600, step: 15) { value in
                        exercise.updateRest(value)
                    }
                }
                PlanIntegerControl(title: "Rest Between", value: exercise.restBetweenExercisesSeconds, suffix: "s", range: 0...300, step: 10) { value in
                    exercise.updateRestBetweenExercises(value)
                }
                PlanCircuitExerciseSelector(
                    selectedExercises: exercise.circuitExercises,
                    exerciseLibrary: exerciseLibrary.filter { $0.id != exercise.exerciseId }
                ) { selected in
                    exercise.addCircuitExercise(selected)
                } onRemove: { id in
                    exercise.removeCircuitExercise(id: id)
                }
            }
        }
    }

    private func basicSetControls(setTitle: String) -> some View {
        PlanResponsivePair {
            PlanIntegerControl(title: setTitle, value: exercise.setCount, suffix: nil, range: 1...12, step: 1) { value in
                exercise.updateSetCount(value)
            }
        } trailing: {
            PlanIntegerControl(title: "Warm-up", value: exercise.warmupSets, suffix: nil, range: 0...max(exercise.setCount - 1, 0), step: 1) { value in
                exercise.updateWarmupSets(value)
            }
        }
    }

    private func repsAndRestControls(repsTitle: String, restTitle: String) -> some View {
        PlanResponsivePair {
            PlanIntegerControl(title: repsTitle, value: exercise.baseReps, suffix: nil, range: 1...50, step: 1) { value in
                exercise.updateBaseReps(value)
            }
        } trailing: {
            PlanIntegerControl(title: restTitle, value: exercise.restSeconds, suffix: "s", range: 0...600, step: 15) { value in
                exercise.updateRest(value)
            }
        }
    }

    private func weightControl(title: String) -> some View {
        PlanDoubleControl(title: title, value: exercise.baseWeight, suffix: "kg", range: 0...500, step: 2.5) { value in
            exercise.updateBaseWeight(value)
        }
    }
}

private struct PlanModePicker: View {
    let selectedMode: PlanExerciseExecutionMode
    let onSelect: (PlanExerciseExecutionMode) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlanExerciseExecutionMode.allCases) { mode in
                    Button {
                        onSelect(mode)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(mode.title, systemImage: mode.systemImage)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(mode.caption)
                                .font(.caption2)
                                .foregroundStyle(selectedMode == mode ? SpotterPalette.textPrimary.opacity(0.8) : SpotterPalette.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .foregroundStyle(selectedMode == mode ? SpotterPalette.textPrimary : SpotterPalette.textSecondary)
                        .background(selectedMode == mode ? SpotterPalette.accent.opacity(0.22) : .white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(selectedMode == mode ? SpotterPalette.accentSoft.opacity(0.65) : .white.opacity(0.10), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Set exercise mode to \(mode.title)")
                }
            }
        }
    }
}

private struct PlanGeneratedSetsEditor: View {
    @Binding var exercise: WorkoutExerciseDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Set Targets")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                if exercise.executionMode == .mav {
                    Text("+\(exercise.incrementPercent.cleanWeight)%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SpotterPalette.accentSoft)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.07), in: Capsule())
                }
            }

            VStack(spacing: 7) {
                ForEach($exercise.plannedSets) { $set in
                    PlanSetDraftRow(set: $set, mode: exercise.executionMode)
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.038), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PlanSetDraftRow: View {
    @Binding var set: PlannedSetDraft
    let mode: PlanExerciseExecutionMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(set.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textPrimary)

                Text(statusLabel)
                    .font(.caption2)
                    .foregroundStyle(SpotterPalette.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.06), in: Capsule())

                Spacer(minLength: 0)
            }

            if mode == .endurance {
                PlanInlineIntegerControl(value: set.durationSeconds, suffix: "s", range: 10...600, step: 5) { value in
                    set.durationSeconds = value
                }
            } else if mode == .amrap {
                PlanInlineDoubleControl(value: set.weight, suffix: "kg", range: 0...500, step: 2.5) { value in
                    set.weight = value
                }
            } else if mode == .rm {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        PlanInlineIntegerControl(value: set.reps, suffix: "RM", range: 1...20, step: 1) { value in
                            set.reps = value
                        }
                        .frame(maxWidth: .infinity)

                        PlanInlineDoubleControl(value: set.weight, suffix: "kg", range: 0...500, step: 2.5) { value in
                            set.weight = value
                        }
                        .frame(maxWidth: .infinity)
                    }

                    VStack(spacing: 8) {
                        PlanInlineIntegerControl(value: set.reps, suffix: "RM", range: 1...20, step: 1) { value in
                            set.reps = value
                        }

                        PlanInlineDoubleControl(value: set.weight, suffix: "kg", range: 0...500, step: 2.5) { value in
                            set.weight = value
                        }
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        PlanInlineIntegerControl(value: set.reps, suffix: "reps", range: 1...80, step: 1) { value in
                            set.reps = value
                        }
                        .frame(maxWidth: .infinity)

                        PlanInlineDoubleControl(value: set.weight, suffix: "kg", range: 0...500, step: 2.5) { value in
                            set.weight = value
                        }
                        .frame(maxWidth: .infinity)
                    }

                    VStack(spacing: 8) {
                        PlanInlineIntegerControl(value: set.reps, suffix: "reps", range: 1...80, step: 1) { value in
                            set.reps = value
                        }

                        PlanInlineDoubleControl(value: set.weight, suffix: "kg", range: 0...500, step: 2.5) { value in
                            set.weight = value
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(.white.opacity(0.046), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var statusLabel: String {
        switch mode {
        case .dropset:
            "Drop"
        case .rm:
            "Attempt"
        case .amrap:
            "Open reps"
        default:
            set.isWarmup ? "Warm-up" : "Working"
        }
    }
}

private struct PlanStructurePreview: View {
    let exercise: WorkoutExerciseDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Structure")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SpotterPalette.textSecondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 7) {
                if exercise.executionMode == .superset {
                    PlanStructureLine(title: exercise.name, detail: "\(exercise.baseReps) reps")
                    PlanStructureLine(title: exercise.linkedExerciseName, detail: "\(exercise.baseReps) reps")
                    PlanStructureLine(title: "Rest", detail: "\(exercise.restSeconds)s after round")
                } else {
                    ForEach(circuitNames, id: \.self) { name in
                        PlanStructureLine(title: name, detail: "\(exercise.restBetweenExercisesSeconds)s transition")
                    }
                    PlanStructureLine(title: "Rounds", detail: "\(exercise.setCount) rounds, \(exercise.restSeconds)s rest")
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.038), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var circuitNames: [String] {
        exercise.circuitExercisesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct PlanStructureLine: View {
    let title: String
    let detail: String

    var body: some View {
        HStack {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SpotterPalette.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(detail)
                .font(.caption)
                .foregroundStyle(SpotterPalette.textSecondary)
                .lineLimit(1)
        }
        .padding(10)
        .background(.white.opacity(0.046), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct PlanExerciseMenu: View {
    let selectedName: String
    let exerciseLibrary: [SpotterExerciseSummary]
    let onSelect: (SpotterExerciseSummary) -> Void

    var body: some View {
        Menu {
            ForEach(exerciseLibrary) { exercise in
                Button(exercise.name) {
                    SpotterHaptics.selection()
                    onSelect(exercise)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textPrimary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SpotterPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(exerciseLibrary.isEmpty)
        .accessibilityLabel("Choose exercise")
        .accessibilityValue(selectedName)
    }
}

private struct PlanExercisePickerControl: View {
    let title: String
    let selectedName: String
    let exerciseLibrary: [SpotterExerciseSummary]
    let onSelect: (SpotterExerciseSummary) -> Void

    var body: some View {
        PlanControlShell(title: title) {
            Menu {
                ForEach(exerciseLibrary) { exercise in
                    Button(exercise.name) {
                        SpotterHaptics.selection()
                        onSelect(exercise)
                    }
                }
            } label: {
                HStack {
                    Text(selectedName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SpotterPalette.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SpotterPalette.textSecondary)
                }
            }
            .disabled(exerciseLibrary.isEmpty)
        }
    }
}

private struct PlanCircuitExerciseSelector: View {
    let selectedExercises: [SpotterExerciseSummary]
    let exerciseLibrary: [SpotterExerciseSummary]
    let onAdd: (SpotterExerciseSummary) -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        PlanControlShell(title: "Circuit Exercises") {
            VStack(alignment: .leading, spacing: 10) {
                if selectedExercises.isEmpty {
                    Text("Add saved exercises to this circuit.")
                        .font(.caption)
                        .foregroundStyle(SpotterPalette.textSecondary)
                } else {
                    VStack(spacing: 7) {
                        ForEach(selectedExercises) { exercise in
                            HStack {
                                Text(exercise.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(SpotterPalette.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Button {
                                    SpotterHaptics.selection()
                                    onRemove(exercise.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(SpotterPalette.textSecondary)
                                        .frame(width: 28, height: 28)
                                        .background(.white.opacity(0.06), in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }

                Menu {
                    ForEach(availableExercises) { exercise in
                        Button(exercise.name) {
                            SpotterHaptics.selection()
                            onAdd(exercise)
                        }
                    }
                } label: {
                    Label("Add Saved Exercise", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .foregroundStyle(SpotterPalette.textPrimary)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .disabled(availableExercises.isEmpty)
            }
        }
    }

    private var availableExercises: [SpotterExerciseSummary] {
        exerciseLibrary.filter { candidate in
            !selectedExercises.contains { $0.id == candidate.id }
        }
    }
}

private struct PlanEstimatePill: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SpotterPalette.textSecondary)
                .textCase(.uppercase)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(SpotterPalette.accentSoft)
        }
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct PlanResponsivePair<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                leading
                    .frame(maxWidth: .infinity)
                trailing
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: 10) {
                leading
                trailing
            }
        }
    }
}

private struct PlanIntegerControl: View {
    let title: String
    let value: Int
    let suffix: String?
    let range: ClosedRange<Int>
    let step: Int
    let onChange: (Int) -> Void

    var body: some View {
        PlanControlShell(title: title) {
            HStack(spacing: 8) {
                PlanControlButton(systemImage: "minus") {
                    onChange(max(range.lowerBound, value - step))
                }
                .disabled(value <= range.lowerBound)

                Text("\(value)\(suffix.map { " \($0)" } ?? "")")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(SpotterPalette.textPrimary)
                    .frame(minWidth: 52)

                PlanControlButton(systemImage: "plus") {
                    onChange(min(range.upperBound, value + step))
                }
                .disabled(value >= range.upperBound)
            }
        }
    }
}

private struct PlanDoubleControl: View {
    let title: String
    let value: Double
    let suffix: String?
    let range: ClosedRange<Double>
    let step: Double
    let onChange: (Double) -> Void

    var body: some View {
        PlanControlShell(title: title) {
            HStack(spacing: 8) {
                PlanControlButton(systemImage: "minus") {
                    onChange(max(range.lowerBound, value - step))
                }
                .disabled(value <= range.lowerBound)

                Text("\(value.cleanWeight)\(suffix.map { " \($0)" } ?? "")")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(SpotterPalette.textPrimary)
                    .frame(minWidth: 70)

                PlanControlButton(systemImage: "plus") {
                    onChange(min(range.upperBound, value + step))
                }
                .disabled(value >= range.upperBound)
            }
        }
    }
}

private struct PlanOptionalDoubleControl: View {
    let title: String
    let value: Double?
    let range: ClosedRange<Double>
    let step: Double
    let onChange: (Double?) -> Void

    var body: some View {
        PlanControlShell(title: title) {
            HStack(spacing: 8) {
                PlanControlButton(systemImage: "minus") {
                    guard let value else {
                        return
                    }
                    let nextValue = value - step
                    onChange(nextValue < range.lowerBound ? nil : nextValue)
                }
                .disabled(value == nil)

                Text(value.map { String(format: "%.1f", $0) } ?? "-")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(SpotterPalette.textPrimary)
                    .frame(minWidth: 42)

                PlanControlButton(systemImage: "plus") {
                    onChange(min(range.upperBound, (value ?? range.lowerBound - step) + step))
                }
            }
        }
    }
}

private struct PlanOptionalIntControl: View {
    let title: String
    let value: Int?
    let range: ClosedRange<Int>
    let step: Int
    let onChange: (Int?) -> Void

    var body: some View {
        PlanControlShell(title: title) {
            HStack(spacing: 8) {
                PlanControlButton(systemImage: "minus") {
                    guard let value else {
                        return
                    }
                    let nextValue = value - step
                    onChange(nextValue < range.lowerBound ? nil : nextValue)
                }
                .disabled(value == nil)

                Text(value.map(String.init) ?? "-")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(SpotterPalette.textPrimary)
                    .frame(minWidth: 42)

                PlanControlButton(systemImage: "plus") {
                    onChange(min(range.upperBound, (value ?? range.lowerBound - step) + step))
                }
            }
        }
    }
}

private struct PlanInlineIntegerControl: View {
    let value: Int
    let suffix: String
    let range: ClosedRange<Int>
    let step: Int
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            PlanControlButton(systemImage: "minus") {
                onChange(max(range.lowerBound, value - step))
            }
            .disabled(value <= range.lowerBound)

            Text("\(value) \(suffix)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(SpotterPalette.textPrimary)
                .frame(minWidth: 58)

            PlanControlButton(systemImage: "plus") {
                onChange(min(range.upperBound, value + step))
            }
            .disabled(value >= range.upperBound)
        }
    }
}

private struct PlanInlineDoubleControl: View {
    let value: Double
    let suffix: String
    let range: ClosedRange<Double>
    let step: Double
    let onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 6) {
            PlanControlButton(systemImage: "minus") {
                onChange(max(range.lowerBound, value - step))
            }
            .disabled(value <= range.lowerBound)

            Text("\(value.cleanWeight) \(suffix)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(SpotterPalette.textPrimary)
                .frame(minWidth: 62)

            PlanControlButton(systemImage: "plus") {
                onChange(min(range.upperBound, value + step))
            }
            .disabled(value >= range.upperBound)
        }
    }
}

private struct PlanControlShell<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SpotterPalette.textSecondary)
                .textCase(.uppercase)

            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct PlanControlButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            SpotterHaptics.selection()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(SpotterPalette.textPrimary)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.12), in: Circle())
                .glassEffect(.regular.interactive(true), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct PlanEmptyInlineMessage: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SpotterPalette.textPrimary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(SpotterPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private extension Double {
    var roundedToHalf: Double {
        (self * 2).rounded() / 2
    }

    var cleanWeight: String {
        if rounded(.towardZero) == self {
            return String(Int(self))
        }
        return String(format: "%.1f", self)
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
