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
        .sheet(isPresented: $showingActiveWorkout) {
            ActiveWorkoutView(
                repository: activeWorkoutRepository,
                healthKitManager: healthKitManager,
                liveActivityManager: liveActivityManager
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
