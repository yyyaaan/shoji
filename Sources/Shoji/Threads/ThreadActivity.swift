import Foundation

enum ThreadStatus: Equatable, Sendable {
    case working, needsYou, done, idle, running
    case exited(code: Int32?)

    var label: String {
        switch self {
        case .working: "Working"
        case .needsYou: "Needs you"
        case .done: "Done"
        case .idle: "Idle"
        case .running: "Running"
        case .exited(code: 0?): "Exited"
        case .exited(code: let code?): "Exit code \(code)"
        case .exited(code: nil): "Terminated"
        }
    }
}

/// Runtime state of a thread; never persisted.
struct ThreadActivity: Equatable, Sendable {
    var status: ThreadStatus
    var since: Date
    /// Needs-you events the user hasn't looked at yet (card badge).
    var attention = 0
    /// What the thread is waiting on, from the hook that raised needs-you.
    var detail: String?
    var terminalTitle: String?

    mutating func transition(to status: ThreadStatus, at now: Date) {
        guard status != self.status else { return }
        self.status = status
        since = now
    }
}
