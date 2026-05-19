import Foundation
import SpotterShared
@preconcurrency import WatchConnectivity

@MainActor
final class WatchPhoneSyncManager: NSObject, ObservableObject {
    @Published private(set) var snapshot: SyncSnapshot?
    @Published private(set) var activationStateDescription = "Not activated"
    @Published private(set) var lastErrorMessage: String?

    private let cacheStore: WatchCacheStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let session: WCSession?

    override convenience init() {
        self.init(cacheStore: WatchCacheStore())
    }

    init(cacheStore: WatchCacheStore) {
        self.cacheStore = cacheStore
        snapshot = cacheStore.loadSnapshot()
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

    private func handleSnapshot(_ snapshot: SyncSnapshot) {
        self.snapshot = snapshot
        lastErrorMessage = nil

        do {
            try cacheStore.saveSnapshot(snapshot)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func handleIncomingMessage(_ dictionary: [String: Any]) {
        guard
            let data = dictionary["message"] as? Data,
            let message = try? decoder.decode(SyncMessage.self, from: data),
            let snapshot = try? message.decodeSnapshot(decoder: decoder)
        else {
            return
        }

        handleSnapshot(snapshot)
    }
}

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

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            handleIncomingMessage(userInfo)
        }
    }
}
