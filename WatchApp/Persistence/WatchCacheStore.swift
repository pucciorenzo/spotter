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
        let directory = cacheDirectory()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL(), options: [.atomic])
    }

    private func snapshotURL() throws -> URL {
        try cacheDirectory().appendingPathComponent("sync-snapshot.json")
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
