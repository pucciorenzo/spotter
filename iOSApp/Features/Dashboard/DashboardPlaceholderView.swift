import SwiftUI

struct DashboardPlaceholderView: View {
    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(
                        eyebrow: "Today",
                        title: "spotter",
                        subtitle: "Upper body session ready. Keep pace calm and precise."
                    )

                    GlassCard {
                        HStack(alignment: .center, spacing: 18) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Push Strength")
                                    .font(.title2.weight(.semibold))
                                Text("Chest, shoulders, triceps")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 10) {
                                    Label("6 exercises", systemImage: "list.bullet")
                                    Label("54 min", systemImage: "timer")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            WorkoutProgressRing(progress: 0.42)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        MetricCard(title: "Week", value: "3", caption: "workouts", systemImage: "calendar")
                        MetricCard(title: "Volume", value: "12.5k", caption: "kg logged", systemImage: "chart.bar.fill")
                        MetricCard(title: "Sets", value: "48", caption: "completed", systemImage: "checkmark.circle.fill")
                        MetricCard(title: "Recovery", value: "82", caption: "readiness", systemImage: "waveform.path.ecg")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next Exercises")
                            .font(.headline)

                        GlassCard {
                            VStack(spacing: 4) {
                                ExerciseRow(name: "Incline Press", detail: "4 sets x 6-8 reps", metric: "80 kg")
                                Divider().overlay(.white.opacity(0.10))
                                ExerciseRow(name: "Cable Fly", detail: "3 sets x 10-12 reps", metric: "24 kg")
                                Divider().overlay(.white.opacity(0.10))
                                ExerciseRow(name: "Lateral Raise", detail: "4 sets x 12-15 reps", metric: "10 kg")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .scrollContentBackground(.hidden)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        DashboardPlaceholderView()
            .preferredColorScheme(.dark)
    }
}
