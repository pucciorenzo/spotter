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

    func clearActiveWorkout() throws {
        let url = try activeWorkoutURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    private func snapshotURL() throws -> URL {
        try cacheDirectory().appendingPathComponent("sync-snapshot.json")
    }

    private func activeWorkoutURL() throws -> URL {
        try cacheDirectory().appendingPathComponent("active-workout.json")
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
