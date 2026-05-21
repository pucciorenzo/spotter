import Foundation
import SpotterShared

struct WatchCacheStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
    }

    func loadSnapshot() -> SyncSnapshot? {
        do {
            let data = try Data(contentsOf: snapshotURL())
            return try decoder.decode(SyncSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    func saveSnapshot(_ snapshot: SyncSnapshot) throws {
        let directory = try cacheDirectory()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL(), options: [.atomic])
    }

    func loadActiveWorkout() -> WorkoutExecutionState? {
        do {
            let data = try Data(contentsOf: activeWorkoutURL())
            return try decoder.decode(WorkoutExecutionState.self, from: data)
        } catch {
            return nil
        }
    }

    func saveActiveWorkout(_ state: WorkoutExecutionState) throws {
        let directory = try cacheDirectory()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: activeWorkoutURL(), options: [.atomic])
    }

    func loadOrCreateDeviceIdentifier() -> String {
        do {
            let url = try deviceIdentifierURL()
            if let value = try? String(contentsOf: url, encoding: .utf8), !value.isEmpty {
                return value
            }

            let value = "watch-\(UUID().uuidString)"
            let directory = try cacheDirectory()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try value.write(to: url, atomically: true, encoding: .utf8)
            return value
        } catch {
            return "watch-\(UUID().uuidString)"
        }
    }

    func clearActiveWorkout() throws {
        let url = try activeWorkoutURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    func loadQueuedCompletedWorkouts() -> [WorkoutSessionDTO] {
        do {
            let data = try Data(contentsOf: completedWorkoutQueueURL())
            return try decoder.decode([WorkoutSessionDTO].self, from: data)
        } catch {
            return []
        }
    }

    func enqueueCompletedWorkout(_ session: WorkoutSessionDTO) throws {
        var sessions = loadQueuedCompletedWorkouts()
        guard !sessions.contains(where: { $0.id == session.id }) else {
            return
        }

        sessions.append(session)
        try saveQueuedCompletedWorkouts(sessions)
    }

    func removeQueuedCompletedWorkout(id: UUID) throws {
        let sessions = loadQueuedCompletedWorkouts().filter { $0.id != id }
        try saveQueuedCompletedWorkouts(sessions)
    }

    private func saveQueuedCompletedWorkouts(_ sessions: [WorkoutSessionDTO]) throws {
        let directory = try cacheDirectory()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(sessions)
        try data.write(to: completedWorkoutQueueURL(), options: [.atomic])
    }

    private func snapshotURL() throws -> URL {
        try cacheDirectory().appendingPathComponent("sync-snapshot.json")
    }

    private func activeWorkoutURL() throws -> URL {
        try cacheDirectory().appendingPathComponent("active-workout.json")
    }

    private func completedWorkoutQueueURL() throws -> URL {
        try cacheDirectory().appendingPathComponent("completed-workout-queue.json")
    }

    private func deviceIdentifierURL() throws -> URL {
        try cacheDirectory().appendingPathComponent("device-id.txt")
    }

    private func cacheDirectory() throws -> URL {
        try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("Spotter", isDirectory: true)
    }
}
