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
    case exited(code: Int32?)
}

/// The terminal engine as the rest of the app sees it; only `Terminal/` knows it is SwiftTerm.
@MainActor
protocol TerminalBackend: AnyObject {
    var view: NSView { get }
    var onEvent: ((TerminalEvent) -> Void)? { get set }
    func start(_ launch: TerminalLaunch)
    func focus()
}
