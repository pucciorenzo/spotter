import SwiftUI

struct ExerciseListView: View {
    let dataProvider: any SpotterDataProviding
    @State private var searchText = ""
    @State private var selectedCategories: Set<String> = []
    @State private var showingCreateExercise = false
    @State private var createExerciseSourceID = "create-exercise-toolbar"
    @State private var showsNavigationTitle = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var createTransitionNamespace

    private var categories: [String] {
        ["All"] + Array(Set(dataProvider.exercises.map(\.primaryCategory))).sorted()
    }

    private var exercises: [SpotterExerciseSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return dataProvider.exercises.filter { exercise in
            let matchesCategory = selectedCategories.isEmpty || selectedCategories.contains(exercise.primaryCategory)
            let matchesQuery = query.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(query)
                || exercise.primaryCategory.localizedCaseInsensitiveContains(query)
                || exercise.equipment.localizedCaseInsensitiveContains(query)
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
                                            detail: "\(exercise.primaryCategory) - \(exercise.equipment)",
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
                .padding(.bottom, 34)
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
            CreateExerciseView()
                .spotterZoomDestination(createExerciseSourceID, in: createTransitionNamespace, reduceMotion: reduceMotion)
        }
        .spotterScreenChrome()
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
                        subtitle: "\(exercise.equipment) - \(exercise.movementPattern)"
                    )

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            DetailRow(title: "Tracking", value: exercise.trackingType)
                            DetailRow(title: "Primary", value: exercise.primaryCategory)
                            DetailRow(title: "Secondary", value: exercise.secondaryCategories.joined(separator: ", "))
                            DetailRow(title: "Equipment", value: exercise.equipment)
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
                .padding(.bottom, 34)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit Exercise")
            }
        }
        .spotterScreenChrome()
    }
}

private struct CreateExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = ""
    @State private var equipment = ""

    var body: some View {
        ZStack {
            SpotterBackground()

            VStack(spacing: 14) {
                TextField("Exercise Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .spotterTextFieldStyle()

                TextField("Primary Category", text: $category)
                    .textInputAutocapitalization(.words)
                    .spotterTextFieldStyle()

                TextField("Equipment", text: $equipment)
                    .textInputAutocapitalization(.words)
                    .spotterTextFieldStyle()

                GlassButton(title: "Create Exercise", systemImage: "plus") {
                    SpotterHaptics.notification(.success)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(22)
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
