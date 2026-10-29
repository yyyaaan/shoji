import AppKit

struct TerminalLaunch: Equatable, Sendable {
    var executable: String
    var arguments: [String]
    var environment: [String: String]
    var directory: String
}

enum TerminalEvent: Equatable, Sendable {
    case title(String)
    case bell
    case input
    case focused
    case commandStarted(String)
    case commandFinished(Int32)
    case directory(String)
    case exited(code: Int32?)
}

extension TerminalEvent {
    /// Reads a report from Shoji's zsh integration (`scripts/shoji.zsh`), which arrives as the payload
    /// of an iTerm2-style `OSC 1337 ; ShojiEvent=<kind>;<value>` sequence.
    init?(shojiReport content: String) {
        guard content.hasPrefix("ShojiEvent=") else { return nil }
        let parts = content.dropFirst("ShojiEvent=".count).split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
        let value = parts.count > 1 ? String(parts[1]) : ""
        switch parts.first {
        case "cmd":
            self = .commandStarted(value)
        case "done":
            guard let code = Int32(value) else { return nil }
            self = .commandFinished(code)
        case "cwd" where !value.isEmpty:
            self = .directory(value)
        default:
            return nil
        }
    }
}

/// The terminal engine as the rest of the app sees it; only `Terminal/` knows it is SwiftTerm.
@MainActor
protocol TerminalBackend: AnyObject {
    var view: NSView { get }
    var onEvent: ((TerminalEvent) -> Void)? { get set }
    func start(_ launch: TerminalLaunch)
    /// Asks the process to quit (SIGTERM); `exited` follows once it has.
    func terminate()
    func focus()
    func setFontSize(_ size: CGFloat)
    /// The default background only; text and cells with their own background stay opaque.
    func setBackgroundOpacity(_ opacity: Double)
    /// A paste, bracketed when the program asked for it.
    func paste(_ text: String)
}
