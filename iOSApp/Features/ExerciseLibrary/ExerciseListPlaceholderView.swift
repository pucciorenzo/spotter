import SwiftUI

struct ExerciseListView: View {
    private let exercises = [
        ("Incline Press", "Chest • Barbell", "80 kg"),
        ("Chest-Supported Row", "Back • Machine", "72 kg"),
        ("Bulgarian Split Squat", "Legs • Dumbbell", "24 kg"),
        ("Cable Fly", "Chest • Cable", "24 kg"),
        ("Lateral Raise", "Shoulders • Dumbbell", "10 kg"),
        ("Dead Bug", "Core • Bodyweight", "45 s")
    ]

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(
                        eyebrow: "Library",
                        title: "Exercises",
                        subtitle: "A calm catalog for movements, defaults, and training notes."
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
                        LibraryChip(title: "Upper", isSelected: false)
                        LibraryChip(title: "Lower", isSelected: false)
                        LibraryChip(title: "Core", isSelected: false)
                    }

                    GlassCard {
                        VStack(spacing: 4) {
                            ForEach(Array(exercises.enumerated()), id: \.offset) { index, exercise in
                                ExerciseRow(name: exercise.0, detail: exercise.1, metric: exercise.2)
                                if index < exercises.count - 1 {
                                    Divider().overlay(.white.opacity(0.10))
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
