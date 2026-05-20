import Foundation
import HealthKit

@MainActor
protocol HealthWorkoutManaging: ObservableObject {
    var isHealthDataAvailable: Bool { get }
    var authorizationStatusText: String { get }
    var isParallelWorkoutActive: Bool { get }
    var durationSeconds: Int { get }
    var activeEnergyKilocalories: Double { get }
    var currentHeartRateBPM: Double? { get }
    var lastErrorMessage: String? { get }

    func requestAuthorization()
    func startParallelWorkout(named workoutName: String)
    func finishParallelWorkout()
    func refreshMetrics()
    func tick()
}

@MainActor
final class HealthKitWorkoutManager: ObservableObject, HealthWorkoutManaging {
    @Published private(set) var authorizationStatusText = "Not Connected"
    @Published private(set) var isParallelWorkoutActive = false
    @Published private(set) var durationSeconds = 0
    @Published private(set) var activeEnergyKilocalories = 0.0
    @Published private(set) var currentHeartRateBPM: Double?
    @Published private(set) var lastErrorMessage: String?

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var startedAt: Date?
    private var authorizationRequested = false
    private var isFinishingWorkout = false

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() {
        Task {
            await requestAuthorizationIfNeeded(forcePrompt: true)
        }
    }

    func startParallelWorkout(named workoutName: String) {
        Task {
            await startWorkout(named: workoutName)
        }
    }

    func finishParallelWorkout() {
        Task {
            await finishWorkout()
        }
    }

    func refreshMetrics() {
        refreshWorkoutMetrics()
    }

    func tick() {
        guard let startedAt else { return }
        durationSeconds = max(0, Int(Date().timeIntervalSince(startedAt)))
        refreshWorkoutMetrics()
    }

    private func requestAuthorizationIfNeeded(forcePrompt: Bool = false) async {
        guard isHealthDataAvailable else {
            authorizationStatusText = "Unavailable"
            return
        }

        if authorizationRequested && !forcePrompt {
            return
        }

        do {
            try await requestHealthAuthorization()
            authorizationRequested = true
            updateAuthorizationStatus()
            lastErrorMessage = nil
        } catch {
            authorizationStatusText = "Not Connected"
            lastErrorMessage = error.localizedDescription
        }
    }

    private func startWorkout(named workoutName: String) async {
        guard !isParallelWorkoutActive, !isFinishingWorkout else { return }
        await requestAuthorizationIfNeeded()

        guard authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
            authorizationStatusText = "Permission Needed"
            return
        }

        do {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .traditionalStrengthTraining
            configuration.locationType = .indoor

            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            try await addMetadata(
                [
                    HKMetadataKeyWorkoutBrandName: "Spotter",
                    "SpotterWorkoutName": workoutName
                ],
                to: builder
            )

            let startedAt = Date()
            session.startActivity(with: startedAt)
            try await beginCollection(builder: builder, at: startedAt)

            workoutSession = session
            workoutBuilder = builder
            self.startedAt = startedAt
            isParallelWorkoutActive = true
            durationSeconds = 0
            activeEnergyKilocalories = 0
            currentHeartRateBPM = nil
            authorizationStatusText = "Connected"
            lastErrorMessage = nil
        } catch {
            isParallelWorkoutActive = false
            lastErrorMessage = error.localizedDescription
        }
    }

    private func finishWorkout() async {
        guard !isFinishingWorkout else { return }

        guard let builder = workoutBuilder,
              let session = workoutSession else {
            resetWorkoutState()
            return
        }

        isFinishingWorkout = true
        let endedAt = Date()
        if session.state != .ended {
            session.end()
        }

        do {
            try await endCollection(builder: builder, at: endedAt)
            _ = try await finishWorkout(builder: builder)
            refreshWorkoutMetrics()
            resetWorkoutState(keepMetrics: true)
            lastErrorMessage = nil
        } catch {
            resetWorkoutState(keepMetrics: true)
            lastErrorMessage = error.localizedDescription
        }
    }

    private func refreshWorkoutMetrics() {
        guard let builder = workoutBuilder else { return }

        if let energyType = quantityType(.activeEnergyBurned),
           let quantity = builder.statistics(for: energyType)?.sumQuantity() {
            activeEnergyKilocalories = quantity.doubleValue(for: .kilocalorie())
        }

        if let heartRateType = quantityType(.heartRate),
           let quantity = builder.statistics(for: heartRateType)?.mostRecentQuantity() {
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            currentHeartRateBPM = quantity.doubleValue(for: bpmUnit)
        }
    }

    private func requestHealthAuthorization() async throws {
        let readTypes = Set([
            HKObjectType.workoutType(),
            quantityType(.activeEnergyBurned),
            quantityType(.heartRate)
        ].compactMap { $0 })

        let shareTypes = Set([
            HKObjectType.workoutType(),
            quantityType(.activeEnergyBurned)
        ].compactMap { $0 })

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.authorizationDenied)
                }
            }
        }
    }

    private func addMetadata(_ metadata: [String: Any], to builder: HKLiveWorkoutBuilder) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.addMetadata(metadata) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.workoutStartFailed)
                }
            }
        }
    }

    private func beginCollection(builder: HKLiveWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: date) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.workoutStartFailed)
                }
            }
        }
    }

    private func endCollection(builder: HKLiveWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: date) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.workoutFinishFailed)
                }
            }
        }
    }

    private func finishWorkout(builder: HKLiveWorkoutBuilder) async throws -> HKWorkout {
        try await withCheckedThrowingContinuation { continuation in
            builder.finishWorkout { workout, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let workout {
                    continuation.resume(returning: workout)
                } else {
                    continuation.resume(throwing: HealthKitError.workoutFinishFailed)
                }
            }
        }
    }

    private func updateAuthorizationStatus() {
        guard isHealthDataAvailable else {
            authorizationStatusText = "Unavailable"
            return
        }

        switch authorizationStatus(for: HKObjectType.workoutType()) {
        case .notDetermined:
            authorizationStatusText = "Not Connected"
        case .sharingAuthorized:
            authorizationStatusText = "Connected"
        case .sharingDenied:
            authorizationStatusText = "Denied"
        @unknown default:
            authorizationStatusText = "Unknown"
        }
    }

    private func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }

    private func quantityType(_ identifier: HKQuantityTypeIdentifier) -> HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: identifier)
    }

    private func resetWorkoutState(keepMetrics: Bool = false) {
        workoutSession = nil
        workoutBuilder = nil
        startedAt = nil
        isParallelWorkoutActive = false
        isFinishingWorkout = false

        if !keepMetrics {
            durationSeconds = 0
            activeEnergyKilocalories = 0
            currentHeartRateBPM = nil
        }
    }
}

private enum HealthKitError: LocalizedError {
    case authorizationDenied
    case workoutStartFailed
    case workoutFinishFailed

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Health permission was not granted."
        case .workoutStartFailed:
            return "Apple workout could not start."
        case .workoutFinishFailed:
            return "Apple workout could not finish."
        }
    }
}
