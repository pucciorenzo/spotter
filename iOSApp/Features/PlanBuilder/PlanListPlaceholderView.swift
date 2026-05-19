import SpotterShared
import SwiftData
import SwiftUI

struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlanModel.name) private var plans: [WorkoutPlanModel]
    @Query(sort: \ExerciseModel.name) private var exercises: [ExerciseModel]
    @Query(sort: \WorkoutSessionModel.startedAt, order: .reverse) private var sessions: [WorkoutSessionModel]
    @State private var newWorkoutName = ""
    @State private var showingCreatePlanSheet = false
    @State private var searchText = ""

    var body: some View {
        ZStack {
            SpotterBackground()

            if visiblePlans.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                PlansEmptyState {
                    newWorkoutName = nextWorkoutName
                    showingCreatePlanSheet = true
                }
                .padding(.horizontal, 28)
            } else {
                List {
                    ForEach(visiblePlans) { plan in
                        NavigationLink {
                            PlanDetailPrototypeView(plan: plan, exercises: exercises)
                        } label: {
                            WorkoutPlanCard(
                                plan: plan,
                                lastUsedText: lastUsedText(for: plan)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 7, leading: 20, bottom: 7, trailing: 20))
                        .swipeActions(edge: .leading) {
                            Button {
                                makeActive(plan)
                            } label: {
                                Label("Activate", systemImage: "checkmark.circle")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                SpotterRepository.delete(plan, from: modelContext)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                plan.isArchived.toggle()
                                plan.updatedAt = Date()
                            } label: {
                                Label(plan.isArchived ? "Restore" : "Archive", systemImage: "archivebox")
                            }
                            .tint(.gray)
                        }
                        .contextMenu {
                            Button {
                                makeActive(plan)
                            } label: {
                                Label("Make Active", systemImage: "checkmark.circle")
                            }

                            Button {
                                plan.isArchived.toggle()
                                plan.updatedAt = Date()
                            } label: {
                                Label(plan.isArchived ? "Restore Plan" : "Archive Plan", systemImage: "archivebox")
                            }

                            Button(role: .destructive) {
                                SpotterRepository.delete(plan, from: modelContext)
                            } label: {
                                Label("Delete Plan", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.top, 12, for: .scrollContent)
                .contentMargins(.bottom, 24, for: .scrollContent)
            }
        }
        .navigationTitle("Workout Plans")
        .navigationBarTitleDisplayMode(.large)
        .spotterScreenChrome()
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Plans")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newWorkoutName = nextWorkoutName
                    showingCreatePlanSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(SpotterPalette.accentSoft)
                }
                .accessibilityLabel("Create Plan")
            }
        }
        .sheet(isPresented: $showingCreatePlanSheet) {
            CreatePlanSheet(planName: $newWorkoutName) {
                createWorkout()
                showingCreatePlanSheet = false
            }
            .presentationDetents([.height(310), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
    }

    private var visiblePlans: [WorkoutPlanModel] {
        let livePlans = plans.filter { !$0.isArchived }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return livePlans
        }

        return livePlans.filter { plan in
            plan.name.localizedCaseInsensitiveContains(query)
                || plan.goal.localizedCaseInsensitiveContains(query)
        }
    }

    private func lastUsedText(for plan: WorkoutPlanModel) -> String {
        guard let lastSession = sessions.first(where: { $0.planId == plan.id }) else {
            return "Not used yet"
        }

        return "Last used \(lastSession.startedAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private var nextWorkoutName: String {
        "Plan \(plans.filter { !$0.isArchived }.count + 1)"
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

    private func makeActive(_ plan: WorkoutPlanModel) {
        for existingPlan in plans {
            existingPlan.isActive = existingPlan.id == plan.id
            existingPlan.updatedAt = Date()
        }
    }
}

private struct PlansEmptyState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 84)

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 92, height: 92)
                    .overlay {
                        Circle()
                            .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
                    }

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 38, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(SpotterPalette.accentSoft)
            }

            VStack(spacing: 8) {
                Text("No Workout Plans")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textPrimary)
                Text("Create a plan for your training week, then build days around how you lift.")
                    .font(.subheadline)
                    .foregroundStyle(SpotterPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GlassButton(title: "Create Plan", systemImage: "plus", action: onCreate)
                .frame(maxWidth: 260)

            Spacer(minLength: 84)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WorkoutPlanCard: View {
    let plan: WorkoutPlanModel
    let lastUsedText: String

    var body: some View {
        GlassCard(cornerRadius: 26, padding: 18) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(plan.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(SpotterPalette.textPrimary)
                            .lineLimit(1)

                        if plan.isActive {
                            Text("Active")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(SpotterPalette.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
                                }
                        }
                    }

                    Text("\(plan.days.count) workout days")
                        .font(.subheadline)
                        .foregroundStyle(SpotterPalette.textSecondary)

                    Text(lastUsedText)
                        .font(.footnote)
                        .foregroundStyle(SpotterPalette.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CreatePlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var planName: String
    let onCreate: () -> Void
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                SpotterBackground()

                VStack(alignment: .leading, spacing: 18) {
                    Text("Name your workout plan.")
                        .font(.headline)
                        .foregroundStyle(SpotterPalette.textPrimary)

                    TextField("Plan Name", text: $planName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isNameFocused)
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .foregroundStyle(SpotterPalette.textPrimary)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
                        }
                        .onSubmit {
                            createIfPossible()
                        }

                    GlassButton(title: "Create Plan", systemImage: "plus") {
                        createIfPossible()
                    }
                    .disabled(planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(22)
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                isNameFocused = true
            }
        }
    }

    private func createIfPossible() {
        guard !planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        onCreate()
    }
}

private struct PlanDetailPrototypeView: View {
    let plan: WorkoutPlanModel
    let exercises: [ExerciseModel]

    private var planDays: [WorkoutDayModel] {
        plan.days.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
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
                                    plan: plan,
                                    day: day,
                                    exercises: exercises
                                )
                            } label: {
                                GlassCard {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(day.name)
                                                .font(.title3.weight(.semibold))
                                            Text(day.notes.isEmpty ? plan.name : day.notes)
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
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .spotterScreenChrome()
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
