import Foundation
import SpotterShared
import SwiftData
@preconcurrency import WatchConnectivity

@MainActor
final class PhoneWatchSyncManager: NSObject, ObservableObject {
    @Published private(set) var activationStateDescription = "Not activated"
    @Published private(set) var lastSnapshotSentAt: Date?
    @Published private(set) var lastWorkoutImportedAt: Date?
    @Published private(set) var lastErrorMessage: String?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let session: WCSession?
    private var latestSnapshot: SyncSnapshot?
    private var modelContext: ModelContext?

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
        case .workoutCompleted:
            importCompletedWorkout(from: message, replyHandler: replyHandler)
        case .snapshotResponse, .workoutAck:
            replyHandler?([:])
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
}
