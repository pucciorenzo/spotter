import HealthKit
import SpotterShared
import SwiftUI
import SwiftData

struct SettingsPlaceholderView: View {
    @EnvironmentObject private var watchSyncManager: PhoneWatchSyncManager
    @AppStorage("workout.promptForSetResults") private var promptForSetResults = true
    @Query(sort: \WorkoutSessionModel.startedAt, order: .reverse) private var sessions: [WorkoutSessionModel]
    @StateObject private var healthKitExporter = HealthKitWorkoutExporter()

    var body: some View {
        List {
            Section("Defaults") {
                LabeledContent("Units", value: "kg")
                LabeledContent("Default Rest", value: "120s")
                Toggle("Prompt for Set Results", isOn: $promptForSetResults)
            }

            Section("Sync") {
                LabeledContent("Watch", value: watchSyncManager.activationStateDescription)
                if let lastSnapshotSentAt = watchSyncManager.lastSnapshotSentAt {
                    LabeledContent("Last Snapshot", value: lastSnapshotSentAt.formatted(date: .omitted, time: .shortened))
                }
                if let lastWorkoutImportedAt = watchSyncManager.lastWorkoutImportedAt {
                    LabeledContent("Last Watch Workout", value: lastWorkoutImportedAt.formatted(date: .omitted, time: .shortened))
                }
                if let lastErrorMessage = watchSyncManager.lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("HealthKit") {
                LabeledContent("Status", value: healthKitExporter.statusText)

                if let latestCompletedWorkout {
                    LabeledContent("Latest Workout", value: latestCompletedWorkout.dayNameSnapshot)
                    Button {
                        Task {
                            await healthKitExporter.export(latestCompletedWorkout)
                        }
                    } label: {
                        Label(
                            healthKitExporter.hasExported(latestCompletedWorkout) ? "Exported to Health" : "Export Latest Workout",
                            systemImage: "heart.text.square"
                        )
                    }
                    .disabled(!healthKitExporter.canExport(latestCompletedWorkout))
                } else {
                    Text("Complete a workout to export it to Apple Health.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await healthKitExporter.requestAuthorization()
                    }
                } label: {
                    Label("Allow Health Access", systemImage: "heart")
                }
                .disabled(!healthKitExporter.isHealthDataAvailable)

                if let message = healthKitExporter.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            healthKitExporter.refreshAuthorizationStatus()
        }
    }

    private var latestCompletedWorkout: WorkoutSessionModel? {
        sessions.first { $0.status == .completed }
    }
}

#Preview {
    NavigationStack {
        SettingsPlaceholderView()
    }
    .environmentObject(PhoneWatchSyncManager())
}

@MainActor
private final class HealthKitWorkoutExporter: ObservableObject {
    @Published private(set) var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published private(set) var message: String?

    private let healthStore = HKHealthStore()
    private let exportedWorkoutIdsKey = "healthKit.exportedWorkoutIds"

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var statusText: String {
        guard isHealthDataAvailable else {
            return "Unavailable"
        }

        switch authorizationStatus {
        case .notDetermined:
            return "Not Requested"
        case .sharingDenied:
            return "Denied"
        case .sharingAuthorized:
            return "Allowed"
        @unknown default:
            return "Unknown"
        }
    }

    func refreshAuthorizationStatus() {
        guard isHealthDataAvailable else {
            authorizationStatus = .sharingDenied
            return
        }

        authorizationStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
    }

    func requestAuthorization() async {
        guard isHealthDataAvailable else {
            message = "Health data is not available on this device."
            refreshAuthorizationStatus()
            return
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: []) { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: HealthKitExportError.authorizationFailed)
                    }
                }
            }

            message = "Health access updated."
        } catch {
            message = "Unable to update Health access."
        }

        refreshAuthorizationStatus()
    }

    func canExport(_ session: WorkoutSessionModel) -> Bool {
        isHealthDataAvailable
            && authorizationStatus == .sharingAuthorized
            && session.status == .completed
            && !hasExported(session)
    }

    func hasExported(_ session: WorkoutSessionModel) -> Bool {
        exportedWorkoutIds.contains(session.id.uuidString)
    }

    func export(_ session: WorkoutSessionModel) async {
        guard canExport(session) else {
            message = hasExported(session) ? "Workout already exported." : "Allow Health access before exporting."
            return
        }

        let duration = max(session.durationSeconds, 60)
        let endDate = session.endedAt ?? session.startedAt.addingTimeInterval(TimeInterval(duration))
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .unknown

        do {
            let builder = HKWorkoutBuilder(
                healthStore: healthStore,
                configuration: configuration,
                device: nil
            )
            try await builder.beginCollection(at: session.startedAt)
            try await builder.addMetadata([
                HKMetadataKeyWorkoutBrandName: "Spotter",
                HKMetadataKeySyncIdentifier: "spotter-\(session.id.uuidString)",
                HKMetadataKeySyncVersion: 1,
                "SpotterPlanName": session.planNameSnapshot,
                "SpotterDayName": session.dayNameSnapshot
            ])
            try await builder.endCollection(at: max(endDate, session.startedAt.addingTimeInterval(1)))
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.finishWorkout { workout, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if workout != nil {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: HealthKitExportError.saveFailed)
                    }
                }
            }

            markExported(session)
            message = "Workout exported to Apple Health."
        } catch {
            message = "Unable to export workout to Apple Health."
        }

        refreshAuthorizationStatus()
    }

    private var exportedWorkoutIds: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: exportedWorkoutIdsKey) ?? [])
    }

    private func markExported(_ session: WorkoutSessionModel) {
        var ids = exportedWorkoutIds
        ids.insert(session.id.uuidString)
        UserDefaults.standard.set(Array(ids).sorted(), forKey: exportedWorkoutIdsKey)
    }
}

private enum HealthKitExportError: Error {
    case authorizationFailed
    case saveFailed
}
