import Foundation
import OSLog

/// `threads.json`: the user's threads and the window layout. Bump `currentVersion` and migrate in `load`
/// when another Shoji version couldn't read the new shape; optional additions don't need it (AGENTS invariant 9).
struct ThreadFile: Codable, Equatable {
    static let currentVersion = 1

    var schemaVersion = currentVersion
    var threads: [ShojiThread]
    /// Kept apart from `threads` so it can later belong to a window's workspace.
    var layout: PaneLayout

    enum LoadError: Error {
        case newerVersion(Int)
    }

    private struct Header: Decodable {
        var schemaVersion: Int
    }

    /// Nil when there is no file yet. A file Shoji can't read is moved aside, never overwritten.
    static func load(from url: URL) -> ThreadFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let version = try JSONDecoder().decode(Header.self, from: data).schemaVersion
            guard version <= currentVersion else { throw LoadError.newerVersion(version) }
            return try JSONDecoder().decode(ThreadFile.self, from: data)
        } catch {
            let backup = url.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            Logger(subsystem: "fi.yan.shoji", category: "threads")
                .error("Couldn't read \(url.path, privacy: .public), kept it as \(backup.lastPathComponent, privacy: .public): \(error)")
            return nil
        }
    }

    func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
