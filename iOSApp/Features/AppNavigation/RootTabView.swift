import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseModel.name) private var exercises: [ExerciseModel]
    @Query(sort: \WorkoutPlanModel.name) private var plans: [WorkoutPlanModel]
    @Query(sort: \WorkoutSessionModel.startedAt, order: .reverse) private var workoutSessions: [WorkoutSessionModel]
    @StateObject private var watchSyncManager = PhoneWatchSyncManager()
    @StateObject private var activeWorkoutRepository = MockActiveWorkoutRepository()
    @StateObject private var healthKitManager = HealthKitWorkoutManager()
    @StateObject private var liveActivityManager = ActiveWorkoutLiveActivityManager()
    @State private var showingActiveWorkout = false
    private let dataProvider: any SpotterDataProviding = MockSpotterRepository.preview

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                NavigationStack {
                    TodayView(
                        dataProvider: dataProvider,
                        activeWorkoutRepository: activeWorkoutRepository,
                        showActiveWorkout: { showingActiveWorkout = true }
                    )
                }
                .spotterNavigationChrome()
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }

                NavigationStack {
                    PlanListView(
                        dataProvider: dataProvider,
                        activeWorkoutRepository: activeWorkoutRepository,
                        showActiveWorkout: { showingActiveWorkout = true }
                    )
                }
                .spotterNavigationChrome()
                .tabItem {
                    Label("Plans", systemImage: "list.bullet.rectangle")
                }

                NavigationStack {
                    ExerciseListView(dataProvider: dataProvider)
                }
                .spotterNavigationChrome()
                .tabItem {
                    Label("Exercises", systemImage: "figure.strengthtraining.traditional")
                }

                NavigationStack {
                    ProgressScreenView(dataProvider: dataProvider)
                }
                .spotterNavigationChrome()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }

                NavigationStack {
                    ProfileView(
                        dataProvider: dataProvider,
                        healthKitManager: healthKitManager
                    )
                }
                .spotterNavigationChrome()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
            }

            if let session = activeWorkoutRepository.session {
                ActiveWorkoutMiniPlayer(session: session) {
                    showingActiveWorkout = true
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 58)
            }
        }
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            ActiveWorkoutView(
                repository: activeWorkoutRepository,
                healthKitManager: healthKitManager,
                liveActivityManager: liveActivityManager
            )
        }
        .environmentObject(watchSyncManager)
        .task {
            watchSyncManager.configure(modelContext: modelContext)
            SeedData.insertDemoDataIfNeeded(in: modelContext)
            publishWatchSnapshot()
        }
        .onChange(of: snapshotVersion) { _, _ in
            publishWatchSnapshot()
        }
        .onOpenURL { url in
            guard url.scheme == "spotter", url.host == "active-workout" else {
                return
            }
            showingActiveWorkout = activeWorkoutRepository.session != nil
        }
    }

    private var snapshotVersion: String {
        let exerciseVersion = exercises
            .map { "\($0.id.uuidString):\($0.updatedAt.timeIntervalSince1970):\($0.isArchived)" }
            .joined(separator: "|")
        let planVersion = plans
            .map { plan in
                let dayVersion = plan.days
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .map { day in
                        let exerciseVersion = day.exercises
                            .sorted { $0.orderIndex < $1.orderIndex }
                            .map { exercise in
                                [
                                    exercise.id.uuidString,
                                    exercise.exerciseId.uuidString,
                                    "\(exercise.orderIndex)",
                                    "\(exercise.numberOfSets)",
                                    "\(exercise.warmupSets)",
                                    exercise.targetTypeRawValue,
                                    "\(exercise.targetRepsMin ?? -1)",
                                    "\(exercise.targetRepsMax ?? -1)",
                                    "\(exercise.targetDurationSeconds ?? -1)",
                                    "\(exercise.startingLoad ?? -1)",
                                    "\(exercise.restSeconds)"
                                ].joined(separator: ":")
                            }
                            .joined(separator: ",")

                        return "\(day.id.uuidString):\(day.name):\(day.orderIndex):\(exerciseVersion)"
                    }
                    .joined(separator: ";")

                return [
                    plan.id.uuidString,
                    "\(plan.updatedAt.timeIntervalSince1970)",
                    "\(plan.isActive)",
                    "\(plan.isArchived)",
                    dayVersion
                ].joined(separator: ":")
            }
            .joined(separator: "|")
        let sessionVersion = workoutSessions
            .filter { $0.status == .completed }
            .prefix(20)
            .map { session in
                [
                    session.id.uuidString,
                    "\(session.updatedAt.timeIntervalSince1970)",
                    "\(session.setLogs.count)"
                ].joined(separator: ":")
            }
            .joined(separator: "|")

        return "\(exerciseVersion)#\(planVersion)#\(sessionVersion)"
    }

    private func publishWatchSnapshot() {
        let snapshot = SnapshotBuilder.makeSnapshot(exercises: exercises, plans: plans, sessions: workoutSessions)
        watchSyncManager.publishSnapshot(snapshot)
    }
}

#Preview {
    RootTabView()
}

private struct ActiveWorkoutMiniPlayer: View {
    let session: ActiveWorkoutSession
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(SpotterPalette.accentSoft)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.currentExercise?.name ?? session.dayName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(session.dayName) - \(session.completedSetCount)/\(session.totalSetCount) sets - \(restText)")
                        .font(.caption)
                        .foregroundStyle(SpotterPalette.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text("Resume")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SpotterPalette.accentSoft)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 20, y: 12)
        }
        .buttonStyle(.plain)
    }

    private var restText: String {
        guard session.restStartedAt != nil else { return "rest idle" }
        if session.restRemainingSeconds >= 0 {
            return "rest \(formatTime(session.restRemainingSeconds))"
        }
        return "+\(formatTime(abs(session.restRemainingSeconds)))"
    }
}
