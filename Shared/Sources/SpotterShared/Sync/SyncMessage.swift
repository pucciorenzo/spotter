import Foundation

public enum SyncMessageType: String, Codable, CaseIterable, Identifiable, Hashable {
    case snapshotRequest
    case snapshotResponse
    case activeWorkoutUpdated
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

    public static func workoutCompleted(_ payload: SyncWorkoutPayload, encoder: JSONEncoder = JSONEncoder()) throws -> SyncMessage {
        let payload = try encoder.encode(payload)
        return SyncMessage(type: .workoutCompleted, payload: payload)
    }

    public static func activeWorkoutUpdated(_ state: WorkoutExecutionState, encoder: JSONEncoder = JSONEncoder()) throws -> SyncMessage {
        let payload = try encoder.encode(state)
        return SyncMessage(type: .activeWorkoutUpdated, payload: payload)
    }

    public static func workoutAck(_ payload: SyncWorkoutAckPayload, encoder: JSONEncoder = JSONEncoder()) throws -> SyncMessage {
        let payload = try encoder.encode(payload)
        return SyncMessage(type: .workoutAck, payload: payload)
    }

    public func decodeSnapshot(decoder: JSONDecoder = JSONDecoder()) throws -> SyncSnapshot? {
        guard type == .snapshotResponse, let payload else { return nil }
        return try decoder.decode(SyncSnapshot.self, from: payload)
    }

    public func decodeWorkoutPayload(decoder: JSONDecoder = JSONDecoder()) throws -> SyncWorkoutPayload? {
        guard type == .workoutCompleted, let payload else { return nil }
        return try decoder.decode(SyncWorkoutPayload.self, from: payload)
    }

    public func decodeActiveWorkoutState(decoder: JSONDecoder = JSONDecoder()) throws -> WorkoutExecutionState? {
        guard type == .activeWorkoutUpdated, let payload else { return nil }
        return try decoder.decode(WorkoutExecutionState.self, from: payload)
    }

    public func decodeWorkoutAck(decoder: JSONDecoder = JSONDecoder()) throws -> SyncWorkoutAckPayload? {
        guard type == .workoutAck, let payload else { return nil }
        return try decoder.decode(SyncWorkoutAckPayload.self, from: payload)
    }
}
