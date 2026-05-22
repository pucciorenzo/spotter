import SwiftUI

struct TodayView: View {
    let dataProvider: any SpotterDataProviding
    @ObservedObject var activeWorkoutRepository: MockActiveWorkoutRepository
    let showActiveWorkout: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsNavigationTitle = false

    private var snapshot: SpotterTodaySnapshot {
        dataProvider.today
    }

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    TodayHeader(snapshot: snapshot)

                    if let suggestedWorkout = snapshot.suggestedWorkout {
                        SuggestedWorkoutCard(
                            workout: suggestedWorkout,
                            activeSession: activeWorkoutRepository.session,
                            action: primaryWorkoutAction
                        )
                    } else {
                        TodayEmptyPlanCard()
                    }

                    LazyVGrid(columns: metricColumns, spacing: 14) {
                        ForEach(snapshot.metrics) { metric in
                            TodayMetricCard(
                                title: metric.title,
                                value: metric.value,
                                caption: metric.caption,
                                systemImage: metric.systemImage
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Workouts")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(SpotterPalette.textPrimary)

                        if snapshot.recentWorkouts.isEmpty {
                            TodayEmptyRecentCard()
                        } else {
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > 24
            } action: { _, isScrolled in
                showsNavigationTitle = isScrolled
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                SpotterInlineNavigationTitle(title: "Today", isVisible: showsNavigationTitle)
            }
        }
        .spotterScreenChrome()
    }

    private var metricColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private func primaryWorkoutAction() {
        if activeWorkoutRepository.session == nil {
            activeWorkoutRepository.startMockWorkout()
        }

        showActiveWorkout()
    }
}

private struct TodayHeader: View {
    let snapshot: SpotterTodaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.greeting)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textPrimary)
                Text(snapshot.status)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(SpotterPalette.textSecondary)
            }

            HStack(spacing: 8) {
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
    let activeSession: ActiveWorkoutSession?
    let action: () -> Void

    var body: some View {
        TodayGlassSurface(cornerRadius: 30, padding: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout.dayPosition)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SpotterPalette.accentSoft)
                        Text(workout.dayName)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(SpotterPalette.textPrimary)
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

                GlassButton(
                    title: activeSession == nil ? "Start" : "Resume",
                    systemImage: activeSession == nil ? "play.fill" : "arrow.clockwise",
                    action: action
                )
                .accessibilityLabel(activeSession == nil ? "Start \(workout.dayName)" : "Resume active workout")
                .accessibilityValue(activeSessionValue)
            }
        }
    }

    private var activeSessionValue: String {
        guard let activeSession else { return workout.dayName }
        return "\(activeSession.currentExercise?.name ?? activeSession.dayName), \(activeSession.completedSetCount) of \(activeSession.totalSetCount) sets"
    }
}

private struct TodayEmptyPlanCard: View {
    var body: some View {
        TodayGlassSurface(cornerRadius: 30, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(SpotterPalette.accentSoft)

                Text("No plan yet")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textPrimary)
                Text("Create a plan and Spotter will keep the next workout one tap away.")
                    .font(.subheadline)
                    .foregroundStyle(SpotterPalette.textSecondary)

                GlassButton(title: "Create Plan", systemImage: "plus")
                    .accessibilityLabel("Create workout plan")
            }
        }
    }
}

private struct RecentWorkoutCard: View {
    let workout: SpotterRecentWorkout

    var body: some View {
        TodayGlassSurface(cornerRadius: 24, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text(workout.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textPrimary)
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

private struct TodayMetricCard: View {
    let title: String
    let value: String
    let caption: String
    let systemImage: String

    var body: some View {
        TodayGlassSurface(cornerRadius: 24, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(SpotterPalette.accentSoft)

                Text(value)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(SpotterPalette.textPrimary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SpotterPalette.textPrimary)
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(SpotterPalette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        }
    }
}

private struct TodayEmptyRecentCard: View {
    var body: some View {
        TodayGlassSurface(cornerRadius: 26, padding: 20) {
            VStack(spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(SpotterPalette.accentSoft)
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.06), in: Circle())

                VStack(spacing: 6) {
                    Text("No workouts yet")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(SpotterPalette.textPrimary)
                    Text("Completed sessions will appear here after you finish logging.")
                        .font(.subheadline)
                        .foregroundStyle(SpotterPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
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
            .background(Color.black.opacity(0.12), in: Capsule())
            .glassEffect(.regular, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
    }
}

private struct TodayGlassSurface<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 28, padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 0.8)
                    .blur(radius: 0.7)
                    .padding(1)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
