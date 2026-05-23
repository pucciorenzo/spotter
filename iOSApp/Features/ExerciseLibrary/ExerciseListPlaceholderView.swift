import SpotterShared
import SwiftData
import SwiftUI

private let exerciseCategoryTags = [
    "Back",
    "Biceps",
    "Calves",
    "Cardio",
    "Chest",
    "Core",
    "Front Delts",
    "Glutes",
    "Hamstrings",
    "Lats",
    "Legs",
    "Mobility",
    "Posterior Chain",
    "Quads",
    "Rear Delts",
    "Shoulders",
    "Triceps"
]

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseModel.name) private var persistedExercises: [ExerciseModel]
    let dataProvider: any SpotterDataProviding
    @State private var searchText = ""
    @State private var selectedCategories: Set<String> = []
    @State private var showingCreateExercise = false
    @State private var createExerciseSourceID = "create-exercise-toolbar"
    @State private var showsNavigationTitle = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var createTransitionNamespace

    private var categories: [String] {
        ["All"] + categoryOptions
    }

    private var categoryOptions: [String] {
        let tags = exerciseSource.reduce(into: Set<String>()) { result, exercise in
            result.insert(exercise.primaryCategory)
            result.formUnion(exercise.secondaryCategories)
        }

        return Array(tags.union(exerciseCategoryTags)).sorted()
    }

    private var exerciseSource: [SpotterExerciseSummary] {
        if persistedExercises.isEmpty {
            return dataProvider.exercises
        }

        return persistedExercises
            .filter { !$0.isArchived }
            .map(Self.makeExerciseSummary)
    }

    private var exercises: [SpotterExerciseSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return exerciseSource.filter { exercise in
            let exerciseTags = Set([exercise.primaryCategory] + exercise.secondaryCategories)
            let matchesCategory = selectedCategories.isEmpty || !selectedCategories.isDisjoint(with: exerciseTags)
            let matchesQuery = query.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(query)
                || exercise.primaryCategory.localizedCaseInsensitiveContains(query)
                || exercise.secondaryCategories.contains { $0.localizedCaseInsensitiveContains(query) }
                || exercise.notes.localizedCaseInsensitiveContains(query)
            return matchesCategory && matchesQuery
        }
    }

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories, id: \.self) { category in
                                LibraryChip(
                                    title: category,
                                    isSelected: isCategorySelected(category)
                                ) {
                                    SpotterHaptics.selection()
                                    toggleCategory(category)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    if exercises.isEmpty {
                        SpotterStateView(
                            mode: .empty,
                            title: "No matching exercises",
                            message: "Adjust search or filters, or create a custom exercise.",
                            systemImage: "magnifyingglass"
                        )

                        createExerciseButton(sourceID: "create-exercise-empty") {
                            GlassButtonLabel(title: "Create Exercise", systemImage: "plus")
                        }
                        .padding(.horizontal, 20)
                    } else {
                        GlassCard(cornerRadius: 26, padding: 14) {
                            VStack(spacing: 4) {
                                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                                    NavigationLink {
                                        ExerciseDetailView(exercise: exercise)
                                    } label: {
                                        ExerciseRow(
                                            name: exercise.name,
                                            detail: "\(exercise.primaryCategory) - \(exercise.trackingType)",
                                            metric: exercise.trackingType
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    if index < exercises.count - 1 {
                                        Divider().overlay(.white.opacity(0.10))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, SpotterLayout.bottomScrollClearance)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > 24
            } action: { _, isScrolled in
                showsNavigationTitle = isScrolled
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: exercises.count)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Exercises")
        .toolbar {
            ToolbarItem(placement: .principal) {
                SpotterInlineNavigationTitle(title: "Exercises", isVisible: showsNavigationTitle)
            }

            ToolbarItem(placement: .topBarTrailing) {
                createExerciseButton(sourceID: "create-exercise-toolbar") {
                    GlassIconButtonLabel(systemImage: "plus")
                }
                .accessibilityLabel("Create Exercise")
            }
        }
        .navigationDestination(isPresented: $showingCreateExercise) {
            CreateExerciseView(categoryOptions: categoryOptions, onSave: saveExercise)
                .spotterZoomDestination(createExerciseSourceID, in: createTransitionNamespace, reduceMotion: reduceMotion)
        }
        .spotterScreenChrome()
    }

    private func saveExercise(_ exercise: ExerciseDTO) throws {
        try SwiftDataExerciseRepository(context: modelContext).saveExercise(exercise)
        SpotterHaptics.notification(.success)
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

    private func createExerciseButton<Label: View>(
        sourceID: String,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            createExerciseSourceID = sourceID
            showingCreateExercise = true
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .spotterZoomSource(sourceID, in: createTransitionNamespace, reduceMotion: reduceMotion)
    }

    private func isCategorySelected(_ category: String) -> Bool {
        category == "All" ? selectedCategories.isEmpty : selectedCategories.contains(category)
    }

    private func toggleCategory(_ category: String) {
        guard category != "All" else {
            selectedCategories.removeAll()
            return
        }

        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
}

private struct ExerciseDetailView: View {
    let exercise: SpotterExerciseSummary

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(
                        eyebrow: exercise.primaryCategory,
                        title: exercise.name,
                        subtitle: "\(exercise.movementPattern) - \(exercise.trackingType)"
                    )

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            DetailRow(title: "Tracking", value: exercise.trackingType)
                            DetailRow(title: "Primary", value: exercise.primaryCategory)
                            DetailRow(title: "Secondary", value: exercise.secondaryCategories.joined(separator: ", "))
                            DetailRow(title: "Pattern", value: exercise.movementPattern)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(exercise.notes)
                                .font(.subheadline)
                                .foregroundStyle(SpotterPalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, SpotterLayout.bottomScrollClearance)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .spotterScreenChrome()
    }
}

private struct CreateExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    let categoryOptions: [String]
    let onSave: (ExerciseDTO) throws -> Void
    @State private var name = ""
    @State private var primaryCategory = ""
    @State private var secondaryCategories: Set<String> = []
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Exercise Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .spotterTextFieldStyle()

                    ExerciseTagSection(
                        title: "Primary",
                        subtitle: primaryCategory.isEmpty ? "Choose one tag" : primaryCategory,
                        tags: categoryOptions,
                        selectedTags: primarySelection
                    ) { tag in
                        SpotterHaptics.selection()
                        if primaryCategory == tag {
                            primaryCategory = ""
                        } else {
                            primaryCategory = tag
                            secondaryCategories.remove(tag)
                        }
                    }

                    ExerciseTagSection(
                        title: "Secondary",
                        subtitle: secondaryCategories.isEmpty ? "Optional" : "\(secondaryCategories.count) selected",
                        tags: categoryOptions.filter { $0 != primaryCategory },
                        selectedTags: secondaryCategories
                    ) { tag in
                        SpotterHaptics.selection()
                        if secondaryCategories.contains(tag) {
                            secondaryCategories.remove(tag)
                        } else {
                            secondaryCategories.insert(tag)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Exercise save error")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        TextEditor(text: $notes)
                            .frame(minHeight: 132)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .foregroundStyle(SpotterPalette.textPrimary)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
                            }
                    }

                    GlassButton(title: "Create Exercise", systemImage: "plus") {
                        save()
                    }
                    .disabled(!canCreate)
                }
                .padding(22)
            }
        }
        .navigationTitle("New Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .spotterScreenChrome()
    }

    private var primarySelection: Set<String> {
        primaryCategory.isEmpty ? [] : [primaryCategory]
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !primaryCategory.isEmpty
    }

    private func save() {
        guard canCreate else {
            return
        }

        let now = Date()
        let exercise = ExerciseDTO(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            primaryMuscleGroup: primaryCategory,
            secondaryMuscleGroups: Array(secondaryCategories).sorted(),
            category: .strength,
            equipment: .other,
            description: notes,
            formCues: [],
            commonMistakes: [],
            videoURL: nil,
            notes: notes,
            defaultMeasurementType: .repetitions,
            defaultRestSeconds: 120,
            defaultLoadUnit: .kg,
            isUnilateral: false,
            isWarmup: false,
            isArchived: false,
            createdAt: now,
            updatedAt: now
        )

        do {
            try onSave(exercise)
            dismiss()
        } catch {
            SpotterHaptics.notification(.error)
            errorMessage = "Could not save exercise. Try again."
        }
    }
}

private struct ExerciseTagSection: View {
    let title: String
    let subtitle: String
    let tags: [String]
    let selectedTags: Set<String>
    let toggle: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 10)
    ]

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SpotterPalette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(tags, id: \.self) { tag in
                        LibraryChip(
                            title: tag,
                            isSelected: selectedTags.contains(tag)
                        ) {
                            toggle(tag)
                        }
                    }
                }
            }
        }
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(SpotterPalette.textSecondary)
            Spacer()
            Text(value.isEmpty ? "None" : value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct LibraryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? SpotterPalette.textPrimary : SpotterPalette.textSecondary)
                .background(isSelected ? AnyShapeStyle(SpotterPalette.accent.opacity(0.72)) : AnyShapeStyle(.thinMaterial))
                .clipShape(Capsule())
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private extension View {
    func spotterTextFieldStyle() -> some View {
        padding(.horizontal, 16)
            .frame(height: 54)
            .foregroundStyle(SpotterPalette.textPrimary)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
            }
    }
}

#Preview {
    NavigationStack {
        ExerciseListView(dataProvider: MockSpotterRepository.preview)
            .preferredColorScheme(.dark)
    }
}
