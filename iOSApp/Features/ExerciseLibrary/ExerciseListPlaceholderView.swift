import Foundation
import SpotterShared
import SwiftData
import SwiftUI

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseModel.name) private var exercises: [ExerciseModel]
    @State private var showingArchived = false
    @State private var editedExercise: ExerciseModel?

    var body: some View {
        List {
            Toggle("Show Archived", isOn: $showingArchived)

            ForEach(filteredExercises) { exercise in
                Button {
                    editedExercise = exercise
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.headline)
                        Text(detailText(for: exercise))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        SpotterRepository.delete(exercise, from: modelContext)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        exercise.isArchived.toggle()
                        exercise.updatedAt = Date()
                    } label: {
                        Label(exercise.isArchived ? "Restore" : "Archive", systemImage: "archivebox")
                    }
                    .tint(.orange)
                }
            }
        }
        .navigationTitle("Exercises")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let exercise = SpotterRepository.insertExercise(named: "New Exercise", in: modelContext)
                    editedExercise = exercise
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editedExercise) { exercise in
            NavigationStack {
                ExerciseEditorView(exercise: exercise)
            }
        }
    }

    private var filteredExercises: [ExerciseModel] {
        exercises.filter { showingArchived || !$0.isArchived }
    }

    private func detailText(for exercise: ExerciseModel) -> String {
        let archived = exercise.isArchived ? " • Archived" : ""
        return "\(exercise.primaryMuscleGroup.isEmpty ? "No muscle group" : exercise.primaryMuscleGroup) • \(exercise.equipment.rawValue)\(archived)"
    }
}

#Preview {
    NavigationStack {
        ExerciseListView()
    }
    .modelContainer(for: [ExerciseModel.self], inMemory: true)
}

private struct ExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: ExerciseModel

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $exercise.name)
                TextField("Primary Muscle Group", text: $exercise.primaryMuscleGroup)
                TextField("Description", text: $exercise.exerciseDescription, axis: .vertical)
            }

            Section("Defaults") {
                Picker("Category", selection: categoryBinding) {
                    ForEach(ExerciseCategory.allCases) { category in
                        Text(category.rawValue.capitalized).tag(category)
                    }
                }

                Picker("Equipment", selection: equipmentBinding) {
                    ForEach(EquipmentType.allCases) { equipment in
                        Text(equipment.rawValue.capitalized).tag(equipment)
                    }
                }

                Picker("Measurement", selection: measurementBinding) {
                    ForEach(MeasurementType.allCases) { measurement in
                        Text(measurement.rawValue.capitalized).tag(measurement)
                    }
                }

                Stepper("Rest: \(exercise.defaultRestSeconds)s", value: $exercise.defaultRestSeconds, in: 0...600, step: 15)

                Picker("Load Unit", selection: loadUnitBinding) {
                    ForEach(LoadUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
            }

            Section("Flags") {
                Toggle("Unilateral", isOn: $exercise.isUnilateral)
                Toggle("Warm-up Exercise", isOn: $exercise.isWarmup)
                Toggle("Archived", isOn: $exercise.isArchived)
            }

            Section("Notes") {
                TextField("Notes", text: $exercise.notes, axis: .vertical)
            }
        }
        .navigationTitle(exercise.name.isEmpty ? "Exercise" : exercise.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    exercise.updatedAt = Date()
                    dismiss()
                }
                .disabled(exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var categoryBinding: Binding<ExerciseCategory> {
        Binding(
            get: { exercise.category },
            set: { exercise.category = $0 }
        )
    }

    private var equipmentBinding: Binding<EquipmentType> {
        Binding(
            get: { exercise.equipment },
            set: { exercise.equipment = $0 }
        )
    }

    private var measurementBinding: Binding<MeasurementType> {
        Binding(
            get: { exercise.defaultMeasurementType },
            set: { exercise.defaultMeasurementType = $0 }
        )
    }

    private var loadUnitBinding: Binding<LoadUnit> {
        Binding(
            get: { exercise.defaultLoadUnit },
            set: { exercise.defaultLoadUnit = $0 }
        )
    }
}
