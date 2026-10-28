import Foundation
import Observation

/// Owns one live terminal per thread, kept alive while panes come and go, and turns
/// terminal callbacks into status events.
@MainActor @Observable
final class TerminalSessions {
    static let baseFontSize: CGFloat = 13

    private(set) var backends: [UUID: any TerminalBackend] = [:]
    /// Applied to every terminal, current and future (app zoom).
    @ObservationIgnored var fontSize = baseFontSize {
        didSet { backends.values.forEach { $0.setFontSize(fontSize) } }
    }
    @ObservationIgnored private let store: ThreadStore
    @ObservationIgnored private let context: LaunchContext
    @ObservationIgnored private let makeBackend: () -> any TerminalBackend

    init(store: ThreadStore, context: LaunchContext, makeBackend: @escaping () -> any TerminalBackend = { SwiftTermBackend() }) {
        self.store = store
        self.context = context
        self.makeBackend = makeBackend
    }

    func terminal(for id: UUID) -> (any TerminalBackend)? {
        backends[id]
    }

    func startAll() {
        for thread in store.threads where backends[thread.id] == nil {
            start(thread)
        }
    }

    private func start(_ thread: ShojiThread) {
        let backend = makeBackend()
        let id = thread.id
        backend.onEvent = { [weak self] in self?.handle($0, from: id) }
        backend.setFontSize(fontSize)
        backends[id] = backend
        backend.start(thread.launch(in: context))
        store.apply(StatusEvent(threadId: id, signal: .launched))
    }

    private func handle(_ event: TerminalEvent, from id: UUID) {
        let signal: StatusEvent.Signal
        switch event {
        case .focused:
            store.focus(id)
            return
        case .input: signal = .userInput
        case .bell: signal = .bell
        case .title(let title): signal = .title(title)
        case .exited(let code): signal = .exited(code: code)
        }
        store.apply(StatusEvent(threadId: id, signal: signal))
    }
}
