import Foundation

public enum SyncMessageType: String, Codable, CaseIterable, Identifiable, Hashable {
    case snapshotRequest
    case snapshotResponse
    case workoutCompleted
    case workoutAck

    public var id: String { rawValue }
}

public struct SyncMessage: Codable, Identifiable, Hashable {
    public var id: UUID
    public var type: SyncMessageType
    public var createdAt: Date
    public var payload: Data?

    public init(
        id: UUID = UUID(),
        type: SyncMessageType,
        createdAt: Date = Date(),
        payload: Data? = nil
    ) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.payload = payload
    }

    public static func snapshotRequest() -> SyncMessage {
        SyncMessage(type: .snapshotRequest)
    }

    public static func snapshotResponse(_ snapshot: SyncSnapshot, encoder: JSONEncoder = JSONEncoder()) throws -> SyncMessage {
        let payload = try encoder.encode(snapshot)
        return SyncMessage(type: .snapshotResponse, payload: payload)
    }

    public func decodeSnapshot(decoder: JSONDecoder = JSONDecoder()) throws -> SyncSnapshot? {
        guard type == .snapshotResponse, let payload else { return nil }
        return try decoder.decode(SyncSnapshot.self, from: payload)
    }
}
