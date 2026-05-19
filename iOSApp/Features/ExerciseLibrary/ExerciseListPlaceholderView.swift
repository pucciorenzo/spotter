import SwiftData
import SwiftUI

struct ExerciseListView: View {
    @Query(sort: \ExerciseModel.name) private var exercises: [ExerciseModel]

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(
                        eyebrow: "Library",
                        title: "Exercises",
                        subtitle: "\(visibleExercises.count) available movements with defaults and notes."
                    )

                    GlassCard(cornerRadius: 26, padding: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(SpotterPalette.accentSoft)
                            Text("Search movements")
                                .font(.subheadline)
                                .foregroundStyle(SpotterPalette.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                    }

                    HStack(spacing: 10) {
                        LibraryChip(title: "All", isSelected: true)
                        LibraryChip(title: "Strength", isSelected: false)
                        LibraryChip(title: "Cardio", isSelected: false)
                    }

                    GlassCard {
                        if visibleExercises.isEmpty {
                            Text("No exercises yet. Add movements from plan setup.")
                                .font(.subheadline)
                                .foregroundStyle(SpotterPalette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(spacing: 4) {
                                ForEach(Array(visibleExercises.enumerated()), id: \.element.id) { index, exercise in
                                    ExerciseRow(
                                        name: exercise.name,
                                        detail: detailText(for: exercise),
                                        metric: metricText(for: exercise)
                                    )
                                    if index < visibleExercises.count - 1 {
                                        Divider().overlay(.white.opacity(0.10))
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
        .spotterScreenChrome()
    }

    private var visibleExercises: [ExerciseModel] {
        exercises.filter { !$0.isArchived }
    }

    private func detailText(for exercise: ExerciseModel) -> String {
        let muscle = exercise.primaryMuscleGroup.isEmpty ? "No muscle group" : exercise.primaryMuscleGroup
        return "\(muscle) - \(exercise.equipment.rawValue)"
    }

    private func metricText(for exercise: ExerciseModel) -> String {
        switch exercise.defaultMeasurementType {
        case .duration:
            return "\(exercise.defaultRestSeconds)s"
        default:
            return exercise.defaultLoadUnit.rawValue
        }
    }
}

private struct LibraryChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
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
}

#Preview {
    NavigationStack {
        ExerciseListView()
            .preferredColorScheme(.dark)
    }
}
