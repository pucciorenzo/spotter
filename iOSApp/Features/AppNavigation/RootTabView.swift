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
    @State private var activeWorkoutFocusMode = false
    private let dataProvider: any SpotterDataProviding = MockSpotterRepository.preview
    private let workoutTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            tabContent

            if showingActiveWorkout {
                ActiveWorkoutPresentation(
                    isPresented: $showingActiveWorkout,
                    isFocusMode: $activeWorkoutFocusMode
                ) {
                    ActiveWorkoutView(
                        repository: activeWorkoutRepository,
                        healthKitManager: healthKitManager,
                        liveActivityManager: liveActivityManager,
                        isFocusMode: $activeWorkoutFocusMode,
                        close: closeActiveWorkout
                    )
                }
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: activeWorkoutRepository.session?.id)
        .environmentObject(watchSyncManager)
        .task {
            watchSyncManager.configure(modelContext: modelContext)
            SeedData.insertDemoDataIfNeeded(in: modelContext)
            publishWatchSnapshot()
        }
        .onChange(of: snapshotVersion) { _, _ in
            publishWatchSnapshot()
        }
        .onChange(of: showingActiveWorkout) { _, isShowing in
            if !isShowing {
                activeWorkoutFocusMode = false
            }
        }
        .onReceive(workoutTicker) { _ in
            activeWorkoutRepository.tickRest()
        }
        .onOpenURL { url in
            guard url.scheme == "spotter", url.host == "active-workout" else {
                return
            }
            showingActiveWorkout = activeWorkoutRepository.session != nil
        }
    }

    private var tabContent: some View {
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let session = activeWorkoutRepository.session {
                ActiveWorkoutMiniBar(session: session) {
                    SpotterHaptics.impact(.light)
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                        showingActiveWorkout = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 64)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func closeActiveWorkout() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            showingActiveWorkout = false
            activeWorkoutFocusMode = false
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
                                    "\(exercise.restSeconds)",
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
                    dayVersion,
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
                    "\(session.setLogs.count)",
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

private struct ActiveWorkoutPresentation<Content: View>: View {
    @Binding var isPresented: Bool
    @Binding var isFocusMode: Bool
    @State private var dragOffset: CGFloat = 0
    let content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            SpotterPalette.backgroundBottom
                .ignoresSafeArea()

            content()
                .padding(.top, isFocusMode ? 0 : 22)
                .offset(y: isFocusMode ? 0 : max(0, dragOffset))
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .simultaneousGesture(isFocusMode ? nil : closeGesture)

            if !isFocusMode {
                dragHandle
                    .padding(.top, 4)
                    .gesture(closeGesture)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onChange(of: isFocusMode) { _, newValue in
            if newValue {
                dragOffset = 0
            }
        }
    }

    private var dragHandle: some View {
        Capsule()
            .fill(.white.opacity(0.36))
            .frame(width: 36, height: 5)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .accessibilityLabel("Close workout")
    }

    private var closeGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                let shouldClose = value.translation.height > 92 || value.predictedEndTranslation.height > 150
                if shouldClose {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        isPresented = false
                        isFocusMode = false
                    }
                } else {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

private struct ActiveWorkoutMiniBar: View {
    let session: ActiveWorkoutSession
    let action: () -> Void

    private var isResting: Bool {
        session.restStartedAt != nil
    }

    private var primaryText: String {
        if isResting {
            return "Rest \(formattedTime(max(0, session.restRemainingSeconds)))"
        }

        return session.currentExercise?.name ?? session.dayName
    }

    private var secondaryText: String {
        if isResting {
            if session.restRemainingSeconds <= 0 {
                return "Rest complete"
            }

            if let target = session.nextPendingTarget {
                return "Next: \(target.exercise.name) Set \(target.set.index)"
            }

            return session.currentExercise?.name ?? "Next set"
        }

        guard let currentSet = session.currentSet else {
            return "\(session.completedSetCount) of \(session.totalSetCount) sets"
        }

        let totalSets = session.currentExercise?.sets.count ?? 0
        let setText = totalSets > 0 ? "Set \(currentSet.index) of \(totalSets)" : "Set \(currentSet.index)"

        switch currentSet.kind {
        case .duration:
            return "\(setText) · \(currentSet.durationSeconds)s"
        case .repsWeight:
            return "\(setText) · \(currentSet.reps) reps"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isResting ? "timer" : "figure.strengthtraining.traditional")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.08), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SpotterPalette.textPrimary)
                        .lineLimit(1)

                    Text(secondaryText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(SpotterPalette.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SpotterPalette.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(Color.black.opacity(0.22), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.30), radius: 22, y: 12)
            .spotterInteractiveGlass(in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if isResting {
            return "Active workout, rest \(formattedTime(max(0, session.restRemainingSeconds))) remaining"
        }

        return "Active workout, \(primaryText), \(secondaryText)"
    }

    private func formattedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }
}

private extension View {
    @ViewBuilder
    func spotterInteractiveGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(true), in: shape)
        } else {
            self
        }
    }
}

#Preview {
    RootTabView()
}
