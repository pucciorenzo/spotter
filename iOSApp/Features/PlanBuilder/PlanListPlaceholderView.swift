import SpotterShared
import Foundation
import SwiftUI
import SwiftData

struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlanModel.name) private var plans: [WorkoutPlanModel]
    @State private var editedPlan: WorkoutPlanModel?

    var body: some View {
        List {
            ForEach(plans) { plan in
                NavigationLink {
                    PlanDetailView(plan: plan)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.name)
                            .font(.headline)
                        Text("\(plan.days.count) days • \(plan.goal.isEmpty ? "No goal" : plan.goal)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        editedPlan = plan
                    } label: {
                        Label("Edit", systemImage: "pencil")
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
                    .tint(.orange)
                }
            }
        }
        .navigationTitle("Plans")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editedPlan = SpotterRepository.insertPlan(named: "New Plan", in: modelContext)
                } label: {
                    Label("Add Plan", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editedPlan) { plan in
            NavigationStack {
                PlanEditorView(plan: plan)
            }
        }
    }
}

private struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plan: WorkoutPlanModel
    @State private var editedDay: WorkoutDayModel?
    @State private var newDayName = ""
    @State private var showingNewDay = false

    var body: some View {
        List {
            ForEach(sortedDays) { day in
                NavigationLink {
                    WorkoutDayDetailView(plan: plan, day: day)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day.name)
                            .font(.headline)
                        Text("\(day.exercises.count) exercises")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        plan.days.removeAll { $0.id == day.id }
                        modelContext.delete(day)
                        plan.updatedAt = Date()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onMove(perform: moveDays)
        }
        .navigationTitle(plan.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newDayName = "Day \(plan.days.count + 1)"
                    showingNewDay = true
                } label: {
                    Label("Add Day", systemImage: "plus")
                }
            }
        }
        .alert("New Day", isPresented: $showingNewDay) {
            TextField("Name", text: $newDayName)
            Button("Add") {
                _ = SpotterRepository.insertDay(named: newDayName, into: plan)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var sortedDays: [WorkoutDayModel] {
        plan.days.sorted { $0.orderIndex < $1.orderIndex }
    }

    private func moveDays(from source: IndexSet, to destination: Int) {
        var ordered = sortedDays
        ordered.move(fromOffsets: source, toOffset: destination)

        for (index, day) in ordered.enumerated() {
            day.orderIndex = index
        }

        plan.updatedAt = Date()
    }
}

private struct WorkoutDayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plan: WorkoutPlanModel
    @Bindable var day: WorkoutDayModel
    @Query(sort: \ExerciseModel.name) private var exercises: [ExerciseModel]
    @State private var editedPrescription: WorkoutExerciseModel?
    @State private var showingExercisePicker = false

    var body: some View {
        List {
            Section("Notes") {
                TextField("Notes", text: $day.notes, axis: .vertical)
            }

            Section("Exercises") {
                ForEach(sortedPrescriptions) { prescription in
                    Button {
                        editedPrescription = prescription
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exerciseName(for: prescription.exerciseId))
                                .font(.headline)
                            Text(targetText(for: prescription))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            day.exercises.removeAll { $0.id == prescription.id }
                            modelContext.delete(prescription)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: movePrescriptions)
            }
        }
        .navigationTitle(day.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink {
                        PhoneWorkoutView(
                            plan: plan.toDTO(),
                            day: day.toDTO(),
                            exercises: exercises.map { $0.toDTO() }
                        )
                    } label: {
                        Label("Start Workout", systemImage: "play.fill")
                    }

                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            NavigationStack {
                ExercisePickerView(exercises: exercises) { exercise in
                    editedPrescription = SpotterRepository.insertPrescription(
                        exerciseId: exercise.id,
                        into: day
                    )
                    showingExercisePicker = false
                }
            }
        }
        .sheet(item: $editedPrescription) { prescription in
            NavigationStack {
                WorkoutExerciseEditorView(
                    prescription: prescription,
                    exerciseName: exerciseName(for: prescription.exerciseId)
                )
            }
        }
    }

    private var sortedPrescriptions: [WorkoutExerciseModel] {
        day.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    private func movePrescriptions(from source: IndexSet, to destination: Int) {
        var ordered = sortedPrescriptions
        ordered.move(fromOffsets: source, toOffset: destination)

        for (index, prescription) in ordered.enumerated() {
            prescription.orderIndex = index
        }
    }

    private func exerciseName(for id: UUID) -> String {
        exercises.first(where: { $0.id == id })?.name ?? "Exercise"
    }

    private func targetText(for prescription: WorkoutExerciseModel) -> String {
        if let seconds = prescription.targetDurationSeconds {
            return "\(prescription.numberOfSets) sets • \(seconds)s • \(prescription.restSeconds)s rest"
        }

        if let min = prescription.targetRepsMin, let max = prescription.targetRepsMax {
            return "\(prescription.numberOfSets) sets • \(min)-\(max) reps • \(prescription.restSeconds)s rest"
        }

        return "\(prescription.numberOfSets) sets • \(prescription.restSeconds)s rest"
    }
}

#Preview {
    NavigationStack {
        PlanListView()
    }
    .modelContainer(for: [
        WorkoutPlanModel.self,
        WorkoutDayModel.self,
        WorkoutExerciseModel.self,
        ExerciseModel.self
    ], inMemory: true)
}

private struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var plan: WorkoutPlanModel

    var body: some View {
        Form {
            Section("Plan") {
                TextField("Name", text: $plan.name)
                TextField("Goal", text: $plan.goal)
                TextField("Description", text: $plan.planDescription, axis: .vertical)
            }

            Section("State") {
                Toggle("Active", isOn: $plan.isActive)
                Toggle("Archived", isOn: $plan.isArchived)
            }
        }
        .navigationTitle(plan.name.isEmpty ? "Plan" : plan.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    plan.updatedAt = Date()
                    dismiss()
                }
                .disabled(plan.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct ExercisePickerView: View {
    let exercises: [ExerciseModel]
    let onSelect: (ExerciseModel) -> Void

    var body: some View {
        List(exercises.filter { !$0.isArchived }) { exercise in
            Button {
                onSelect(exercise)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                    Text("\(exercise.primaryMuscleGroup) • \(exercise.equipment.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Choose Exercise")
    }
}

private struct WorkoutExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var prescription: WorkoutExerciseModel
    let exerciseName: String

    var body: some View {
        Form {
            Section(exerciseName) {
                Stepper("Working Sets: \(prescription.numberOfSets)", value: $prescription.numberOfSets, in: 1...20)
                Stepper("Warm-up Sets: \(prescription.warmupSets)", value: $prescription.warmupSets, in: 0...10)
                Picker("Target", selection: targetTypeBinding) {
                    ForEach(SetTargetType.allCases) { targetType in
                        Text(targetType.rawValue).tag(targetType)
                    }
                }
            }

            Section("Reps Or Time") {
                Stepper("Min Reps: \(prescription.targetRepsMin ?? 0)", value: optionalIntBinding(\.targetRepsMin), in: 0...100)
                Stepper("Max Reps: \(prescription.targetRepsMax ?? 0)", value: optionalIntBinding(\.targetRepsMax), in: 0...100)
                Stepper("Duration: \(prescription.targetDurationSeconds ?? 0)s", value: optionalIntBinding(\.targetDurationSeconds), in: 0...7200, step: 15)
            }

            Section("Load And Rest") {
                Stepper("Starting Load: \(startingLoadText)", value: startingLoadBinding, in: 0...500, step: 2.5)
                Picker("Unit", selection: loadUnitBinding) {
                    ForEach(LoadUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                Stepper("Increment: \(incrementText)", value: incrementBinding, in: 0...50, step: 0.5)
                Stepper("Rest: \(prescription.restSeconds)s", value: $prescription.restSeconds, in: 0...900, step: 15)
            }

            Section("Notes") {
                TextField("Tempo", text: optionalStringBinding(\.tempo))
                TextField("Notes", text: $prescription.notes, axis: .vertical)
                Toggle("Auto Progression", isOn: $prescription.autoProgressionEnabled)
            }
        }
        .navigationTitle("Prescription")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var targetTypeBinding: Binding<SetTargetType> {
        Binding(
            get: { prescription.targetType },
            set: { prescription.targetType = $0 }
        )
    }

    private var loadUnitBinding: Binding<LoadUnit> {
        Binding(
            get: { prescription.loadUnit },
            set: { prescription.loadUnit = $0 }
        )
    }

    private var startingLoadText: String {
        String(format: "%.1f", prescription.startingLoad ?? 0)
    }

    private var incrementText: String {
        String(format: "%.1f", prescription.suggestedIncrement ?? 0)
    }

    private var startingLoadBinding: Binding<Double> {
        Binding(
            get: { prescription.startingLoad ?? 0 },
            set: { prescription.startingLoad = $0 }
        )
    }

    private var incrementBinding: Binding<Double> {
        Binding(
            get: { prescription.suggestedIncrement ?? 0 },
            set: { prescription.suggestedIncrement = $0 }
        )
    }

    private func optionalIntBinding(_ keyPath: ReferenceWritableKeyPath<WorkoutExerciseModel, Int?>) -> Binding<Int> {
        Binding(
            get: { prescription[keyPath: keyPath] ?? 0 },
            set: { prescription[keyPath: keyPath] = $0 }
        )
    }

    private func optionalStringBinding(_ keyPath: ReferenceWritableKeyPath<WorkoutExerciseModel, String?>) -> Binding<String> {
        Binding(
            get: { prescription[keyPath: keyPath] ?? "" },
            set: { prescription[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }
}

private struct PhoneWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("workout.promptForSetResults") private var promptForSetResults = true

    let plan: WorkoutPlanDTO
    let day: WorkoutDayDTO
    let exercises: [ExerciseDTO]
    @State private var state: WorkoutExecutionState
    @State private var showingSetResultEntry = false
    @State private var editedLog: WorkoutSetLogDTO?
    @State private var errorMessage: String?

    init(plan: WorkoutPlanDTO, day: WorkoutDayDTO, exercises: [ExerciseDTO]) {
        self.plan = plan
        self.day = day
        self.exercises = exercises
        _state = State(initialValue: WorkoutExecutionEngine.start(plan: plan, day: day, source: .iphone))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentExerciseName)
                        .font(.headline)
                    Text(setProgressText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if canCompleteSet {
                Section("Options") {
                    Toggle("Prompt for Set Results", isOn: $promptForSetResults)
                }

                Button {
                    if promptForSetResults {
                        showingSetResultEntry = true
                    } else {
                        completeCurrentSet()
                    }
                } label: {
                    Label("Complete Set", systemImage: "checkmark.circle.fill")
                }
                .sheet(isPresented: $showingSetResultEntry) {
                    NavigationStack {
                        SetResultEditorView(
                            title: "Set \(nextSetNumber)",
                            usesDuration: usesDuration,
                            loadUnit: currentExercise?.loadUnit ?? .kg,
                            reps: defaultReps,
                            durationSeconds: defaultDuration,
                            load: defaultLoad
                        ) { reps, durationSeconds, load in
                            completeCurrentSet(reps: reps, durationSeconds: durationSeconds, load: load)
                        }
                    }
                }

                Button {
                    skipCurrentSet()
                } label: {
                    Label("Skip Set", systemImage: "forward.end.fill")
                }
            }

            if !loggedSets.isEmpty {
                Section("Logged Sets") {
                    ForEach(loggedSets) { log in
                        Button {
                            if log.completionType == .completed {
                                editedLog = log
                            }
                        } label: {
                            LoggedSetSummaryRow(log: log)
                        }
                        .disabled(log.completionType != .completed)
                    }
                }
            }

            if isWorkoutComplete {
                Button {
                    finishWorkout()
                } label: {
                    Label("Finish Workout", systemImage: "flag.checkered")
                }
            }
        }
        .navigationTitle(day.name)
        .sheet(item: $editedLog) { log in
            NavigationStack {
                SetResultEditorView(
                    title: "\(log.exerciseNameSnapshot) Set \(log.setIndex)",
                    usesDuration: log.targetDurationSeconds != nil,
                    loadUnit: log.completedLoadUnit,
                    reps: log.completedReps ?? log.targetReps ?? 0,
                    durationSeconds: log.completedDurationSeconds ?? log.targetDurationSeconds ?? 0,
                    load: log.completedLoad ?? log.targetLoad ?? 0
                ) { reps, durationSeconds, load in
                    updateLoggedSet(log, reps: reps, durationSeconds: durationSeconds, load: load)
                }
            }
        }
        .alert("Workout Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var orderedExercises: [WorkoutExerciseDTO] {
        WorkoutExecutionEngine.orderedExercises(in: day, state: state)
    }

    private var currentExercise: WorkoutExerciseDTO? {
        guard orderedExercises.indices.contains(state.currentExerciseIndex) else {
            return nil
        }

        return orderedExercises[state.currentExerciseIndex]
    }

    private var currentExerciseName: String {
        guard let currentExercise else {
            return "Complete"
        }

        return exerciseName(for: currentExercise.exerciseId)
    }

    private var completedSetCount: Int {
        guard let currentExercise else {
            return 0
        }

        return WorkoutExecutionEngine.completedSetCount(for: currentExercise, in: state)
    }

    private var totalSetCount: Int {
        guard let currentExercise else {
            return 0
        }

        return WorkoutExecutionEngine.totalSetCount(for: currentExercise)
    }

    private var nextSetNumber: Int {
        min(completedSetCount + 1, max(totalSetCount, 1))
    }

    private var usesDuration: Bool {
        guard let currentExercise else {
            return false
        }

        return currentExercise.targetType == .fixedDuration || currentExercise.targetType == .durationRange
    }

    private var canCompleteSet: Bool {
        currentExercise != nil && !isWorkoutComplete
    }

    private var isWorkoutComplete: Bool {
        WorkoutExecutionEngine.nextIncompleteExerciseIndex(in: day, state: state) == nil
    }

    private var loggedSets: [WorkoutSetLogDTO] {
        state.session.setLogs.sorted { lhs, rhs in
            if lhs.completedAt == rhs.completedAt {
                return lhs.setIndex < rhs.setIndex
            }

            return lhs.completedAt < rhs.completedAt
        }
    }

    private var defaultReps: Int {
        currentExercise?.targetReps ?? currentExercise?.targetRepsMax ?? currentExercise?.targetRepsMin ?? 0
    }

    private var defaultDuration: Int {
        currentExercise?.targetDurationSeconds ?? currentExercise?.targetDurationMaxSeconds ?? currentExercise?.targetDurationMinSeconds ?? 0
    }

    private var defaultLoad: Double {
        currentExercise?.startingLoad ?? 0
    }

    private var setProgressText: String {
        guard totalSetCount > 0 else {
            return "No sets"
        }

        return "Set \(nextSetNumber) of \(totalSetCount)"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func completeCurrentSet() {
        completeCurrentSet(
            reps: usesDuration ? nil : defaultReps,
            durationSeconds: usesDuration ? defaultDuration : nil,
            load: currentExercise?.loadUnit == .bodyweight ? nil : defaultLoad
        )
    }

    private func completeCurrentSet(reps: Int?, durationSeconds: Int?, load: Double?) {
        guard let currentExercise else {
            return
        }

        WorkoutExecutionEngine.appendCompletedSet(
            to: &state,
            day: day,
            exercise: currentExercise,
            exerciseName: currentExerciseName,
            completedReps: reps,
            completedDurationSeconds: durationSeconds,
            completedLoad: currentExercise.loadUnit == .bodyweight ? nil : load
        )
    }

    private func skipCurrentSet() {
        guard let currentExercise else {
            return
        }

        WorkoutExecutionEngine.appendSkippedSet(
            to: &state,
            day: day,
            exercise: currentExercise,
            exerciseName: currentExerciseName,
            reason: "Skipped set"
        )
    }

    private func updateLoggedSet(_ log: WorkoutSetLogDTO, reps: Int?, durationSeconds: Int?, load: Double?) {
        WorkoutExecutionEngine.updateSetLog(
            in: &state,
            logId: log.id,
            completedReps: reps,
            completedDurationSeconds: durationSeconds,
            completedLoad: log.completedLoadUnit == .bodyweight ? nil : load
        )
    }

    private func finishWorkout() {
        WorkoutExecutionEngine.finish(&state)
        modelContext.insert(WorkoutSessionModel(dto: state.session))

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Unable to save workout."
        }
    }

    private func exerciseName(for id: UUID) -> String {
        exercises.first(where: { $0.id == id })?.name ?? "Exercise"
    }
}

private struct SetResultEditorView: View {
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
            Section("Result") {
                if usesDuration {
                    TextField("Seconds", text: $durationText)
                        .keyboardType(.numberPad)
                } else {
                    TextField("Reps", text: $repsText)
                        .keyboardType(.numberPad)
                }

                if loadUnit != .bodyweight {
                    TextField(loadUnit.rawValue, text: $loadText)
                        .keyboardType(.decimalPad)
                }
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

private struct LoggedSetSummaryRow: View {
    let log: WorkoutSetLogDTO

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(log.exerciseNameSnapshot) Set \(log.setIndex)")
                    .font(.headline)
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if log.completionType == .completed {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
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
