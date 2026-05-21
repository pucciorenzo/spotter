import Foundation
import SpotterShared
@preconcurrency import WatchConnectivity

@MainActor
protocol WatchActiveWorkoutSyncing: ObservableObject {
    var activeWorkoutState: WorkoutExecutionState? { get }
    func publishActiveWorkoutState(_ state: WorkoutExecutionState)
}

@MainActor
final class WatchPhoneSyncManager: NSObject, ObservableObject {
    @Published private(set) var snapshot: SyncSnapshot?
    @Published private(set) var activeWorkoutState: WorkoutExecutionState?
    @Published private(set) var activationStateDescription = "Not activated"
    @Published private(set) var queuedCompletedWorkoutCount = 0
    @Published private(set) var lastErrorMessage: String?

    private let cacheStore: WatchCacheStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let session: WCSession?
    private var lastSentActiveWorkoutFingerprint: String?

    override convenience init() {
        self.init(cacheStore: WatchCacheStore())
    }

    init(cacheStore: WatchCacheStore) {
        self.cacheStore = cacheStore
        snapshot = cacheStore.loadSnapshot()
        activeWorkoutState = cacheStore.loadActiveWorkout()
        queuedCompletedWorkoutCount = cacheStore.loadQueuedCompletedWorkouts().count
        session = WCSession.isSupported() ? .default : nil

        super.init()

        if let session {
            session.delegate = self
            session.activate()
        } else {
            activationStateDescription = "WatchConnectivity unavailable"
        }
    }

    func requestSnapshot() {
        guard let session else { return }

        do {
            let data = try encoder.encode(SyncMessage.snapshotRequest())

            if session.isReachable {
                session.sendMessage(["message": data]) { [weak self] reply in
                    Task { @MainActor in
                        self?.handleIncomingMessage(reply)
                    }
                } errorHandler: { [weak self] error in
                    Task { @MainActor in
                        self?.lastErrorMessage = error.localizedDescription
                    }
                }
            } else {
                session.transferUserInfo(["message": data])
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func requestActiveWorkoutState() {
        guard let session else { return }

        do {
            let data = try encoder.encode(SyncMessage.activeWorkoutRequest())
            let dictionary = ["message": data]

            if session.isReachable {
                session.sendMessage(dictionary) { [weak self] reply in
                    Task { @MainActor in
                        self?.handleIncomingMessage(reply)
                    }
                } errorHandler: { [weak self] error in
                    Task { @MainActor in
                        self?.lastErrorMessage = error.localizedDescription
                    }
                }
            } else {
                session.transferUserInfo(dictionary)
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func syncQueuedCompletedWorkouts() {
        queuedCompletedWorkoutCount = cacheStore.loadQueuedCompletedWorkouts().count

        guard let session else { return }

        for completedSession in cacheStore.loadQueuedCompletedWorkouts() {
            do {
                let payload = SyncWorkoutPayload(sentAt: Date(), session: completedSession)
                let message = try SyncMessage.workoutCompleted(payload, encoder: encoder)
                let data = try encoder.encode(message)
                let dictionary = ["message": data]

                if session.isReachable {
                    session.sendMessage(dictionary) { [weak self] reply in
                        Task { @MainActor in
                            self?.handleIncomingMessage(reply)
                        }
                    } errorHandler: { [weak self] error in
                        Task { @MainActor in
                            self?.lastErrorMessage = error.localizedDescription
                        }
                    }
                } else {
                    session.transferUserInfo(dictionary)
                }
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func publishActiveWorkoutState(_ state: WorkoutExecutionState) {
        guard state.syncFingerprint != lastSentActiveWorkoutFingerprint else {
            return
        }

        activeWorkoutState = state
        lastSentActiveWorkoutFingerprint = state.syncFingerprint

        do {
            try cacheStore.saveActiveWorkout(state)
        } catch {
            lastErrorMessage = error.localizedDescription
        }

        guard let session else { return }

        do {
            let message = try SyncMessage.activeWorkoutUpdated(state, encoder: encoder)
            let data = try encoder.encode(message)
            let dictionary = ["message": data]

            try session.updateApplicationContext(dictionary)

            if session.isReachable {
                session.sendMessage(dictionary) { [weak self] reply in
                    Task { @MainActor in
                        self?.handleIncomingMessage(reply)
                    }
                } errorHandler: { [weak self] error in
                    Task { @MainActor in
                        self?.lastErrorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func clearActiveWorkoutState() {
        activeWorkoutState = nil
        lastSentActiveWorkoutFingerprint = nil

        do {
            try cacheStore.clearActiveWorkout()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func handleSnapshot(_ snapshot: SyncSnapshot) {
        self.snapshot = snapshot
        lastErrorMessage = nil

        do {
            try cacheStore.saveSnapshot(snapshot)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func handleWorkoutAck(_ ack: SyncWorkoutAckPayload) {
        do {
            try cacheStore.removeQueuedCompletedWorkout(id: ack.sessionId)
            queuedCompletedWorkoutCount = cacheStore.loadQueuedCompletedWorkouts().count
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func handleActiveWorkoutState(_ state: WorkoutExecutionState) {
        let mergedState = activeWorkoutState?.mergedWithRemote(state) ?? state
        guard mergedState.syncFingerprint != activeWorkoutState?.syncFingerprint else {
            return
        }

        activeWorkoutState = mergedState
        lastErrorMessage = nil

        do {
            try cacheStore.saveActiveWorkout(mergedState)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func handleIncomingMessage(_ dictionary: [String: Any]) {
        guard
            let data = dictionary["message"] as? Data,
            let message = try? decoder.decode(SyncMessage.self, from: data)
        else {
            return
        }

        switch message.type {
        case .snapshotResponse:
            guard let snapshot = try? message.decodeSnapshot(decoder: decoder) else { return }
            handleSnapshot(snapshot)
        case .activeWorkoutUpdated:
            guard let state = try? message.decodeActiveWorkoutState(decoder: decoder) else { return }
            handleActiveWorkoutState(state)
        case .workoutAck:
            guard let ack = try? message.decodeWorkoutAck(decoder: decoder) else { return }
            handleWorkoutAck(ack)
        case .snapshotRequest, .activeWorkoutRequest, .workoutCompleted:
            return
        }
    }
}

extension WatchPhoneSyncManager: WatchActiveWorkoutSyncing {}

extension WatchPhoneSyncManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            activationStateDescription = String(describing: activationState)
            lastErrorMessage = error?.localizedDescription
            requestSnapshot()
            requestActiveWorkoutState()
            syncQueuedCompletedWorkouts()
            if let activeWorkoutState {
                publishActiveWorkoutState(activeWorkoutState)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            handleIncomingMessage(applicationContext)
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
            handleIncomingMessage(message)
            replyHandler([:])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            handleIncomingMessage(userInfo)
        }
    }
}
