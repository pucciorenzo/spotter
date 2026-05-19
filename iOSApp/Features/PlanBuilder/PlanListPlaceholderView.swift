import SwiftUI

struct PlanListView: View {
    private let days = [
        ("Push Strength", "Chest, shoulders, triceps", "6 exercises", 0.42),
        ("Pull Volume", "Back, rear delts, biceps", "7 exercises", 0.20),
        ("Lower Control", "Squat pattern and hinges", "6 exercises", 0.0)
    ]

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(
                        eyebrow: "Plan",
                        title: "Training Week",
                        subtitle: "Built around steady progress and low-friction logging."
                    )

                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        NavigationLink {
                            WorkoutDayPrototypeView(
                                title: day.0,
                                subtitle: day.1
                            )
                        } label: {
                            GlassCard {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(day.0)
                                            .font(.title3.weight(.semibold))
                                        Text(day.1)
                                            .font(.subheadline)
                                            .foregroundStyle(SpotterPalette.textSecondary)
                                        Text(day.2)
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
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .spotterScreenChrome()
    }
}

private struct WorkoutDayPrototypeView: View {
    let title: String
    let subtitle: String

    private let exercises = [
        ("Incline Press", "4 sets x 6-8 reps", "80 kg"),
        ("Flat Dumbbell Press", "3 sets x 8-10 reps", "34 kg"),
        ("Cable Fly", "3 sets x 12 reps", "24 kg"),
        ("Lateral Raise", "4 sets x 12-15 reps", "10 kg"),
        ("Rope Pressdown", "3 sets x 10-12 reps", "32 kg")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(
                        eyebrow: "Workout Day",
                        title: title,
                        subtitle: subtitle
                    )

                    GlassCard {
                        HStack(spacing: 18) {
                            WorkoutProgressRing(progress: 0.0)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("54 min")
                                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                                Text("Estimated duration")
                                    .font(.subheadline)
                                    .foregroundStyle(SpotterPalette.textSecondary)
                                Text("2 warm-up sets included")
                                    .font(.caption)
                                    .foregroundStyle(SpotterPalette.accentSoft)
                            }
                            Spacer()
                        }
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
                .padding(.bottom, 116)
            }

            NavigationLink {
                ActiveWorkoutPrototypeView()
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
        }
        .spotterScreenChrome()
    }
}

private struct ActiveWorkoutPrototypeView: View {
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
                        title: "Incline Press",
                        subtitle: "Set 3 of 4. Rest finished; next set ready."
                    )

                    GlassCard {
                        VStack(spacing: 20) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Target")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(SpotterPalette.textSecondary)
                                    Text("6-8 reps")
                                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 6) {
                                    Text("Load")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(SpotterPalette.textSecondary)
                                    Text("82.5 kg")
                                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                }
                            }

                            ProgressView(value: 0.58)
                                .tint(SpotterPalette.accentSoft)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Rest")
                                .font(.headline)
                            HStack(alignment: .lastTextBaseline) {
                                Text("00:18")
                                    .font(.system(size: 54, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                Spacer()
                                Text("remaining")
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
