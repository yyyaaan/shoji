import Foundation

/// The single path for status changes (AGENTS.md invariant 5), applied by `ThreadStore` on the main actor.
struct StatusEvent: Equatable, Sendable {
    enum Signal: Equatable, Sendable {
        case launched
        case working(sessionId: String?)
        case needsYou(message: String?)
        case finished
        case userInput
        case bell
        case title(String)
        case exited(code: Int32?)
    }

    let threadId: UUID
    let signal: Signal
}

extension StatusEvent {
    /// Decodes one `shoji-hook` message: the thread id on the first line, then the CLI's JSON payload.
    init?(hookMessage data: Data) {
        guard let newline = data.firstIndex(of: UInt8(ascii: "\n")),
              let threadId = UUID(uuidString: String(decoding: data[..<newline], as: UTF8.self)),
              let payload = try? JSONDecoder().decode(HookPayload.self, from: data[data.index(after: newline)...]),
              let signal = payload.signal
        else { return nil }
        self.init(threadId: threadId, signal: signal)
    }
}

/// The fields Shoji reads from Claude Code hook input and Codex `notify` payloads.
private struct HookPayload: Decodable {
    let hookEventName: String?
    let type: String?
    let sessionId: String?
    let message: String?
    let notificationType: String?

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case type
        case sessionId = "session_id"
        case message
        case notificationType = "notification_type"
    }

    var signal: StatusEvent.Signal? {
        switch hookEventName ?? type {
        case "UserPromptSubmit", "PostToolUse":
            .working(sessionId: sessionId)
        case "Notification":
            // idle_prompt repeats "waiting for input" after a finished turn; that's Done, not Needs you.
            ["idle_prompt", "auth_success"].contains(notificationType) ? nil : .needsYou(message: message)
        case "Stop", "agent-turn-complete":
            .finished
        default:
            nil
        }
    }
}
