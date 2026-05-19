import SpotterShared
import SwiftUI

struct ExerciseListPlaceholderView: View {
    private let exercises = DemoSeedData.exercises

    var body: some View {
        List(exercises) { exercise in
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                Text("\(exercise.primaryMuscleGroup) • \(exercise.equipment.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Exercises")
    }
}

#Preview {
    NavigationStack {
        ExerciseListPlaceholderView()
    }
}
