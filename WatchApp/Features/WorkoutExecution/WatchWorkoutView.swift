import Foundation
import SpotterShared
import SwiftUI

struct WatchWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncManager: WatchPhoneSyncManager
    @StateObject private var viewModel: WatchWorkoutViewModel
    @State private var now = Date()

    init(plan: WorkoutPlanDTO, day: WorkoutDayDTO) {
        _viewModel = StateObject(wrappedValue: WatchWorkoutViewModel(plan: plan, day: day))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.currentExerciseName)
                        .font(.headline)
                    if let substitutionText = viewModel.currentSubstitutionText {
                        Text(substitutionText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(setProgressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let restText = viewModel.formattedRest(at: now) {
                Section {
                    HStack {
                        Image(systemName: "timer")
                        Text(restText)
                            .font(.title3.monospacedDigit())
                    }
                    .foregroundStyle(restIsOver ? .green : .primary)
                }
            }

            if viewModel.canCompleteSet {
                Section {
                    if viewModel.usesDuration {
                        CrownNumberField(
                            title: "Duration",
                            suffix: "s",
                            value: $viewModel.durationValue,
                            range: 0...3600,
                            step: 5
                        )
                    } else {
                        CrownNumberField(
                            title: "Reps",
                            suffix: "",
                            value: $viewModel.repsValue,
                            range: 0...200,
                            step: 1
                        )
                    }

                    if viewModel.currentExercise?.loadUnit != .bodyweight {
                        CrownNumberField(
                            title: "Load",
                            suffix: viewModel.currentExercise?.loadUnit.rawValue ?? "",
                            value: $viewModel.loadValue,
                            range: 0...500,
                            step: 2.5
                        )
                    }
                }

                Button {
                    viewModel.completeCurrentSet()
                } label: {
                    Label("Complete Set", systemImage: "checkmark.circle.fill")
                }

                Section {
                    Button {
                        viewModel.skipCurrentSet()
                    } label: {
                        Label("Skip Set", systemImage: "forward.end.fill")
                    }

                    Button(role: .destructive) {
                        viewModel.skipCurrentExercise()
                    } label: {
                        Label("Skip Exercise", systemImage: "figure.strengthtraining.traditional")
                    }

                    HStack {
                        Button {
                            viewModel.moveCurrentExerciseUp()
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .disabled(!viewModel.canMoveCurrentExerciseUp)

                        Button {
                            viewModel.moveCurrentExerciseDown()
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .disabled(!viewModel.canMoveCurrentExerciseDown)
                    }

                    NavigationLink {
                        WatchExerciseReplacementView(viewModel: viewModel)
                    } label: {
                        Label("Change Exercise", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(viewModel.replacementExercises.isEmpty)
                }
            }

            if viewModel.isWorkoutComplete {
                Button {
                    viewModel.finishWorkout()
                } label: {
                    Label("Finish Workout", systemImage: "flag.checkered")
                }
            }

            Button(role: .destructive) {
                viewModel.cancelWorkout()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
        }
        .navigationTitle(viewModel.state.session.dayNameSnapshot)
        .onAppear {
            viewModel.configure(snapshot: syncManager.snapshot)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
            viewModel.tickRest(at: date)
        }
        .onChange(of: viewModel.didFinish) { _, didFinish in
            if didFinish {
                syncManager.syncQueuedCompletedWorkouts()
                dismiss()
            }
        }
        .alert("Workout Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var setProgressText: String {
        guard viewModel.totalSetCount > 0 else {
            return "No sets"
        }

        let type = viewModel.isCurrentSetWarmup ? "Warm-up" : "Working"
        return "\(type) set \(viewModel.nextSetNumber) of \(viewModel.totalSetCount)"
    }

    private var restIsOver: Bool {
        (viewModel.restRemainingSeconds(at: now) ?? 1) <= 0
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

private struct WatchExerciseReplacementView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WatchWorkoutViewModel

    var body: some View {
        List(viewModel.replacementExercises) { exercise in
            Button {
                viewModel.substituteCurrentExercise(with: exercise)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                    Text(exercise.primaryMuscleGroup)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Change")
    }
}

private struct CrownNumberField: View {
    let title: String
    let suffix: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(displayText)
                .font(.title3.monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusable(true)
                .digitalCrownRotation(
                    $value,
                    from: range.lowerBound,
                    through: range.upperBound,
                    by: step,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
        }
    }

    private var displayText: String {
        let formattedValue = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)

        guard !suffix.isEmpty else {
            return formattedValue
        }

        return "\(formattedValue) \(suffix)"
    }
}

#Preview {
    NavigationStack {
        WatchWorkoutView(
            plan: DemoSeedData.plans[0],
            day: DemoSeedData.plans[0].days[0]
        )
    }
    .environmentObject(WatchPhoneSyncManager(cacheStore: WatchCacheStore()))
}
