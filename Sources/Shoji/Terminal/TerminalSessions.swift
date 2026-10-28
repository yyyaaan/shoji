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

    /// Starts a terminal for every new thread and stops the ones whose thread was closed.
    func sync() {
        let ids = Set(store.threads.map(\.id))
        for (id, backend) in backends where !ids.contains(id) {
            backend.terminate()
            backends[id] = nil
        }
        for thread in store.threads where backends[thread.id] == nil {
            start(thread)
        }
    }

    /// Replaces the thread's terminal with a fresh launch (a Claude thread resumes its session).
    func restart(_ id: UUID) {
        guard let thread = store.thread(id) else { return }
        backends.removeValue(forKey: id)?.terminate()
        start(thread)
    }

    private func start(_ thread: ShojiThread) {
        let backend = makeBackend()
        let id = thread.id
        // A restarted thread's old process still reports its exit; only the current backend speaks for the thread.
        backend.onEvent = { [weak self, weak backend] event in
            guard let self, let backend, self.backends[id] === backend else { return }
            self.handle(event, from: id)
        }
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
        case .commandStarted(let line): signal = .commandStarted(line)
        case .commandFinished(let code): signal = .commandFinished(code: code)
        case .directory(let path): signal = .directory(path)
        case .exited(let code): signal = .exited(code: code)
        }
        store.apply(StatusEvent(threadId: id, signal: signal))
    }
}
