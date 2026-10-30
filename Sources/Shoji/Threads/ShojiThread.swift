import Foundation

/// A shell Shoji hosts and keeps across relaunches. What runs inside (claude, `pnpm dev`, nothing) changes
/// as the user works; see `ThreadActivity`. Persisted in `threads.json`.
/// Not named `Thread` to avoid shadowing `Foundation.Thread`.
struct ShojiThread: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    /// Given by the user; without one the thread goes by its folder's name (`ThreadStore.name(of:)`).
    var title: String?
    /// Where the shell last was; a relaunch starts there.
    var folder: String
    /// Cards between two bars on the shelf share a group; the numbers only order groups and cards.
    var group: Int
    var order: Int
    /// The agent session running in the thread; a relaunch resumes it with `resumeAgent`'s CLI.
    var resumeId: String?
    /// Kept apart from `command`, which a relaunch or a dead shell clears while the session stays resumable.
    var resumeAgent: Agent?
    /// The command running when Shoji last saved; a relaunch leaves it at the prompt, ready to run again.
    var command: String?
    /// Text size levels away from the other terminals (⌥⌘+ / ⌥⌘−); nil when the same.
    var textSteps: Int?
    /// A narrow shelf card, status and name only; nil when full size.
    var isMini: Bool?

    init(
        id: UUID = UUID(),
        title: String? = nil,
        folder: String = "~",
        group: Int = 0,
        order: Int = 0,
        resumeId: String? = nil,
        resumeAgent: Agent? = nil,
        command: String? = nil,
        textSteps: Int? = nil,
        isMini: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.folder = folder
        self.group = group
        self.order = order
        self.resumeId = resumeId
        self.resumeAgent = resumeAgent
        self.command = command
        self.textSteps = textSteps
        self.isMini = isMini
    }

    /// What an unnamed thread goes by.
    var folderName: String { (displayFolder as NSString).lastPathComponent }
    var displayFolder: String { (folder as NSString).abbreviatingWithTildeInPath }
}
