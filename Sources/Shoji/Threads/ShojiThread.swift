import Foundation

/// A terminal session Shoji hosts: an agent CLI or a long-running task. Persisted in `threads.json`.
/// Not named `Thread` to avoid shadowing `Foundation.Thread`.
struct ShojiThread: Identifiable, Codable, Hashable, Sendable {
    enum Group: String, Codable, Sendable {
        case agent, task
    }

    enum Kind: String, Codable, Sendable {
        case claude, codex, command

        var label: String { rawValue.uppercased() }
    }

    let id: UUID
    var group: Group
    var kind: Kind
    var title: String
    var folder: String
    /// argv; empty means an interactive login shell.
    var command: [String]
    var resumeId: String?
    var order: Int

    init(
        id: UUID = UUID(),
        group: Group,
        kind: Kind,
        title: String,
        folder: String,
        command: [String],
        resumeId: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.group = group
        self.kind = kind
        self.title = title
        self.folder = folder
        self.command = command
        self.resumeId = resumeId
        self.order = order
    }

    var displayFolder: String { (folder as NSString).abbreviatingWithTildeInPath }
    var displayCommand: String { command.isEmpty ? "login shell" : command.joined(separator: " ") }
}
