import SwiftUI

struct TodayView: View {
    let dataProvider: any SpotterDataProviding
    @ObservedObject var activeWorkoutRepository: MockActiveWorkoutRepository
    let showActiveWorkout: () -> Void

    private var snapshot: SpotterTodaySnapshot {
        dataProvider.today
    }

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    TodayHeader(snapshot: snapshot)

                    if let session = activeWorkoutRepository.session {
                        ActiveWorkoutBanner(session: session, action: showActiveWorkout)
                    }

                    if let suggestedWorkout = snapshot.suggestedWorkout {
                        SuggestedWorkoutCard(workout: suggestedWorkout) {
                            activeWorkoutRepository.startMockWorkout()
                            showActiveWorkout()
                        }
                    } else {
                        TodayEmptyPlanCard()
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(snapshot.metrics) { metric in
                            MetricCard(
                                title: metric.title,
                                value: metric.value,
                                caption: metric.caption,
                                systemImage: metric.systemImage
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Workouts")
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(snapshot.recentWorkouts) { workout in
                                    RecentWorkoutCard(workout: workout)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .spotterScreenChrome()
    }
}

private struct TodayHeader: View {
    let snapshot: SpotterTodaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.greeting)
                    .font(.largeTitle.weight(.semibold))
                Text(snapshot.status)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(SpotterPalette.textSecondary)
            }

            HStack(spacing: 10) {
                TodayStatusPill(title: "\(snapshot.sessionsThisWeek) this week", systemImage: "calendar")
                TodayStatusPill(title: snapshot.lastWorkout, systemImage: "clock")
                TodayStatusPill(title: snapshot.recoveryStatus, systemImage: "heart")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SuggestedWorkoutCard: View {
    let workout: SpotterSuggestedWorkout
    let startWorkout: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout.dayPosition)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SpotterPalette.accentSoft)
                        Text(workout.dayName)
                            .font(.title2.weight(.semibold))
                        Text(workout.planName)
                            .font(.subheadline)
                            .foregroundStyle(SpotterPalette.textSecondary)
                    }

                    Spacer()

                    WorkoutProgressRing(progress: 0.48)
                }

                HStack(spacing: 10) {
                    TodayStatusPill(title: "\(workout.exerciseCount) exercises", systemImage: "list.bullet")
                    TodayStatusPill(title: workout.estimatedDuration, systemImage: "timer")
                }

                VStack(spacing: 8) {
                    ForEach(workout.firstExercises, id: \.self) { exercise in
                        HStack {
                            Text(exercise)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SpotterPalette.textTertiary)
                        }
                    }
                }
                .foregroundStyle(SpotterPalette.textSecondary)

                GlassButton(title: "Start", systemImage: "play.fill", action: startWorkout)
            }
        }
    }
}

private struct ActiveWorkoutBanner: View {
    let session: ActiveWorkoutSession
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(SpotterPalette.accentSoft)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.currentExercise?.name ?? session.dayName)
                        .font(.headline)
                    Text("\(session.dayName) - \(session.completedSetCount)/\(session.totalSetCount) sets")
                        .font(.caption)
                        .foregroundStyle(SpotterPalette.textSecondary)
                }

                Spacer()

                Text("Resume")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SpotterPalette.accentSoft)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct TodayEmptyPlanCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(SpotterPalette.accentSoft)

                Text("No plan yet")
                    .font(.title2.weight(.semibold))
                Text("Create a plan and Spotter will keep the next workout one tap away.")
                    .font(.subheadline)
                    .foregroundStyle(SpotterPalette.textSecondary)

                GlassButton(title: "Create Plan", systemImage: "plus")
            }
        }
    }
}

private struct RecentWorkoutCard: View {
    let workout: SpotterRecentWorkout

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text(workout.name)
                    .font(.headline)
                Text(workout.dateText)
                    .font(.caption)
                    .foregroundStyle(SpotterPalette.textSecondary)

                HStack(spacing: 10) {
                    Label(workout.duration, systemImage: "timer")
                    Label(workout.volume, systemImage: "chart.bar")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(SpotterPalette.textSecondary)
            }
            .frame(width: 190, alignment: .leading)
        }
    }
}

private struct TodayStatusPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(SpotterPalette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.08), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
            }
    }
}

#Preview {
    NavigationStack {
        TodayView(
            dataProvider: MockSpotterRepository.preview,
            activeWorkoutRepository: MockActiveWorkoutRepository(),
            showActiveWorkout: {}
        )
            .preferredColorScheme(.dark)
    }
}
