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

/// Agent CLIs Shoji recognises when they run in a thread.
enum Agent: String, Codable, Sendable {
    case claude, codex

    /// From the command's first word, so `claude --model opus` counts.
    init?(commandLine: String) {
        guard let executable = commandLine.split(whereSeparator: \.isWhitespace).first else { return nil }
        self.init(rawValue: (String(executable) as NSString).lastPathComponent)
    }

    var label: String { rawValue.uppercased() }
}

/// Runtime state of a thread; never persisted.
struct ThreadActivity: Equatable, Sendable {
    var status: ThreadStatus
    var since: Date
    /// Needs-you events the user hasn't looked at yet (card badge).
    var attention = 0
    /// Done while you weren't looking (Zed's unread dot); cleared once you look or the thread moves on.
    var isUnseen = false
    /// From hooks: what the thread waits on while it needs you, or the tool its agent last used while working.
    var detail: String?
    var terminalTitle: String?
    /// The agent CLI running in the shell right now.
    var agent: Agent?

    /// The agent's terminal title, unless it only names the agent or repeats its command line.
    var topic: String? {
        guard let agent, let title = terminalTitle, !title.isEmpty, !title.lowercased().hasPrefix(agent.rawValue) else { return nil }
        return title
    }
    /// The shell integration has reported in, so a thread without a command really sits at its prompt.
    var isIntegrated = false
    /// False once the shell itself has ended; Restart starts a new one.
    var isAlive = true

    init(status: ThreadStatus, since: Date, attention: Int = 0, detail: String? = nil, terminalTitle: String? = nil, agent: Agent? = nil) {
        self.status = status
        self.since = since
        self.attention = attention
        self.detail = detail
        self.terminalTitle = terminalTitle
        self.agent = agent
    }

    /// A fresh shell, at its prompt.
    init(launchedAt now: Date) {
        self.init(status: .idle, since: now)
    }

    mutating func transition(to status: ThreadStatus, at now: Date) {
        guard status != self.status else { return }
        self.status = status
        since = now
        isUnseen = false
    }
}
