import Foundation
import SpotterShared
import SwiftData
@preconcurrency import WatchConnectivity

@MainActor
final class PhoneWatchSyncManager: NSObject, ObservableObject {
    @Published private(set) var activationStateDescription = "Not activated"
    @Published private(set) var lastSnapshotSentAt: Date?
    @Published private(set) var lastWorkoutImportedAt: Date?
    @Published private(set) var activeWorkoutState: WorkoutExecutionState?
    @Published private(set) var lastErrorMessage: String?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let session: WCSession?
    private var latestSnapshot: SyncSnapshot?
    private var modelContext: ModelContext?
    private var activeWorkoutStateRepository: ActiveWorkoutStateRepositoryProtocol?
    private var lastSentActiveWorkoutFingerprint: String?

    override init() {
        if WCSession.isSupported() {
            session = .default
        } else {
            session = nil
        }

        super.init()

        if let session {
            session.delegate = self
            session.activate()
        } else {
            activationStateDescription = "WatchConnectivity unavailable"
        }
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        let repository = SwiftDataActiveWorkoutStateRepository(context: modelContext)
        activeWorkoutStateRepository = repository
        activeWorkoutState = try? repository.loadActiveWorkout()?.state
        sendActiveWorkoutState()
    }

    func publishSnapshot(_ snapshot: SyncSnapshot) {
        latestSnapshot = snapshot

        guard let session else { return }

        do {
            let message = try SyncMessage.snapshotResponse(snapshot, encoder: encoder)
            let data = try encoder.encode(message)

            try session.updateApplicationContext(["message": data])
            lastSnapshotSentAt = Date()
            lastErrorMessage = nil

            if session.isReachable {
                session.sendMessage(["message": data], replyHandler: nil) { [weak self] error in
                    Task { @MainActor in
                        self?.lastErrorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func publishActiveWorkoutState(_ state: WorkoutExecutionState) {
        guard state.syncFingerprint != lastSentActiveWorkoutFingerprint else {
            return
        }

        activeWorkoutState = state
        lastSentActiveWorkoutFingerprint = state.syncFingerprint
        autosaveActiveWorkoutState(state)

        guard let session else { return }

        do {
            let message = try SyncMessage.activeWorkoutUpdated(state, encoder: encoder)
            let data = try encoder.encode(message)
            let dictionary = ["message": data]

            try session.updateApplicationContext(dictionary)
            lastErrorMessage = nil

            if session.isReachable {
                session.sendMessage(dictionary, replyHandler: nil) { [weak self] error in
                    Task { @MainActor in
                        self?.lastErrorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func sendActiveWorkoutState(replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let activeWorkoutState else {
            replyHandler?([:])
            return
        }

        do {
            let message = try SyncMessage.activeWorkoutUpdated(activeWorkoutState, encoder: encoder)
            let data = try encoder.encode(message)
            let dictionary = ["message": data]

            if let replyHandler {
                replyHandler(dictionary)
            } else if let session {
                try session.updateApplicationContext(dictionary)
                if session.isReachable {
                    session.sendMessage(dictionary, replyHandler: nil)
                }
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            replyHandler?([:])
        }
    }

    private func sendLatestSnapshot(replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let latestSnapshot else {
            replyHandler?([:])
            return
        }

        do {
            let message = try SyncMessage.snapshotResponse(latestSnapshot, encoder: encoder)
            let data = try encoder.encode(message)

            if let replyHandler {
                replyHandler(["message": data])
            } else if let session, session.isReachable {
                session.sendMessage(["message": data], replyHandler: nil)
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            replyHandler?([:])
        }
    }

    private func importCompletedWorkout(
        from message: SyncMessage,
        replyHandler: (([String: Any]) -> Void)?
    ) {
        guard
            let modelContext,
            let payload = try? message.decodeWorkoutPayload(decoder: decoder)
        else {
            replyHandler?([:])
            return
        }

        do {
            try SpotterRepository.importCompletedWorkout(payload.session, in: modelContext)
            if activeWorkoutState?.session.id == payload.session.id {
                activeWorkoutState = nil
                try activeWorkoutStateRepository?.clearActiveWorkout()
            }
            lastWorkoutImportedAt = Date()
            lastErrorMessage = nil
            sendWorkoutAck(for: payload.session.id, replyHandler: replyHandler)
        } catch {
            lastErrorMessage = error.localizedDescription
            replyHandler?([:])
        }
    }

    private func sendWorkoutAck(
        for sessionId: UUID,
        replyHandler: (([String: Any]) -> Void)? = nil
    ) {
        do {
            let ackPayload = SyncWorkoutAckPayload(sessionId: sessionId, receivedAt: Date())
            let message = try SyncMessage.workoutAck(ackPayload, encoder: encoder)
            let data = try encoder.encode(message)
            let dictionary = ["message": data]

            if let replyHandler {
                replyHandler(dictionary)
            } else if let session {
                session.transferUserInfo(dictionary)
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            replyHandler?([:])
        }
    }

    private func handleIncomingMessage(_ dictionary: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard
            let data = dictionary["message"] as? Data,
            let message = try? decoder.decode(SyncMessage.self, from: data)
        else {
            replyHandler?([:])
            return
        }

        switch message.type {
        case .snapshotRequest:
            sendLatestSnapshot(replyHandler: replyHandler)
        case .activeWorkoutUpdated:
            if let incomingState = try? message.decodeActiveWorkoutState(decoder: decoder) {
                let mergedState = activeWorkoutState?.mergedWithRemote(incomingState) ?? incomingState
                if mergedState.syncFingerprint != activeWorkoutState?.syncFingerprint {
                    autosaveActiveWorkoutState(mergedState)
                    activeWorkoutState = mergedState.session.status == .inProgress ? mergedState : nil
                }
            }
            sendActiveWorkoutState(replyHandler: replyHandler)
        case .activeWorkoutRequest:
            sendActiveWorkoutState(replyHandler: replyHandler)
        case .workoutCompleted:
            importCompletedWorkout(from: message, replyHandler: replyHandler)
        case .snapshotResponse, .workoutAck:
            replyHandler?([:])
        }
    }

    private func autosaveActiveWorkoutState(_ state: WorkoutExecutionState) {
        do {
            try activeWorkoutStateRepository?.saveActiveWorkout(state, planSnapshot: nil, daySnapshot: nil)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

extension PhoneWatchSyncManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            activationStateDescription = String(describing: activationState)
            lastErrorMessage = error?.localizedDescription
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            activationStateDescription = "Inactive"
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            activationStateDescription = "Deactivated"
            session.activate()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleIncomingMessage(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            handleIncomingMessage(message, replyHandler: replyHandler)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            handleIncomingMessage(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            handleIncomingMessage(applicationContext)
        }
    }
}
