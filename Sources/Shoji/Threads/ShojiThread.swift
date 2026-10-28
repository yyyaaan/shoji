import Foundation

/// A shell Shoji hosts and keeps across relaunches. What runs inside (claude, `pnpm dev`, nothing) changes
/// as the user works; see `ThreadActivity`. Persisted in `threads.json`.
/// Not named `Thread` to avoid shadowing `Foundation.Thread`.
struct ShojiThread: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    /// Given by the user; without one the card shows the folder's name.
    var title: String?
    /// Where the shell last was; a relaunch starts there.
    var folder: String
    /// Cards between two bars on the shelf share a group; the numbers only order groups and cards.
    var group: Int
    var order: Int
    /// The Claude session running in the thread; a relaunch resumes it.
    var resumeId: String?
    /// The command running when Shoji last saved; a relaunch leaves it at the prompt, ready to run again.
    var command: String?

    init(
        id: UUID = UUID(),
        title: String? = nil,
        folder: String = "~",
        group: Int = 0,
        order: Int = 0,
        resumeId: String? = nil,
        command: String? = nil
    ) {
        self.id = id
        self.title = title
        self.folder = folder
        self.group = group
        self.order = order
        self.resumeId = resumeId
        self.command = command
    }

    var displayTitle: String { title ?? (displayFolder as NSString).lastPathComponent }
    var displayFolder: String { (folder as NSString).abbreviatingWithTildeInPath }
}
