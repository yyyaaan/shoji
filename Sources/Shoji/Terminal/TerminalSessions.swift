import Foundation
import Observation

/// Owns one live terminal per thread, kept alive while panes come and go, and turns
/// terminal callbacks into status events.
@MainActor @Observable
final class TerminalSessions {
    static let baseFontSize: CGFloat = 13

    private(set) var backends: [UUID: any TerminalBackend] = [:]
    /// The ⌘K quick terminal while it's open.
    private(set) var popup: Popup?
    /// Applied to every terminal, current and future (app zoom).
    @ObservationIgnored var fontSize = baseFontSize {
        didSet {
            backends.values.forEach { $0.setFontSize(fontSize) }
            popup?.backend.setFontSize(fontSize)
        }
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
        connect(backend, to: thread.id)
        backend.setFontSize(fontSize)
        backends[thread.id] = backend
        backend.start(thread.launch(in: context))
        store.apply(StatusEvent(threadId: thread.id, signal: .launched))
    }

    private func connect(_ backend: any TerminalBackend, to id: UUID) {
        // A restarted thread's old process still reports its exit; only the current backend speaks for the thread.
        backend.onEvent = { [weak self, weak backend] event in
            guard let self, let backend, self.backends[id] === backend else { return }
            self.handle(event, from: id)
        }
    }

    // MARK: Quick terminal (⌘K)

    /// A fresh shell floating over the panes, not a thread unless it's closed while running something.
    struct Popup {
        /// What it becomes on the shelf; its id is the shell's `SHOJI_THREAD_ID` from the start.
        var thread: ShojiThread
        let backend: any TerminalBackend
        /// The command it's running, from the zsh integration.
        var running: String?
    }

    func togglePopup() {
        if popup == nil { openPopup() } else { closePopup() }
    }

    /// Opens in the focused thread's folder (home without one).
    func openPopup() {
        guard popup == nil else { return }
        let thread = ShojiThread(folder: store.focusedThreadId.flatMap(store.thread)?.folder ?? "~")
        let backend = makeBackend()
        backend.onEvent = { [weak self, weak backend] event in
            guard let self, let backend, self.popup?.backend === backend else { return }
            self.handlePopup(event)
        }
        backend.setFontSize(fontSize)
        popup = Popup(thread: thread, backend: backend)
        backend.start(thread.launch(in: context))
    }

    /// ⌘K again, ⌘W, a click outside or `exit`. An idle shell ends; one still running a command becomes a thread
    /// on the shelf, so closing never stops anything.
    func closePopup() {
        guard let popup else { return }
        self.popup = nil
        if let running = popup.running {
            connect(popup.backend, to: popup.thread.id)
            backends[popup.thread.id] = popup.backend
            store.adopt(popup.thread, running: running)
        } else {
            popup.backend.terminate()
        }
        // Back to the pane you were in.
        if let id = store.focusedThreadId { store.open(id) }
    }

    private func handlePopup(_ event: TerminalEvent) {
        switch event {
        case .commandStarted(let line): popup?.running = line
        case .commandFinished: popup?.running = nil
        case .directory(let path): popup?.thread.folder = (path as NSString).abbreviatingWithTildeInPath
        case .exited:
            popup?.running = nil
            closePopup()
        case .focused, .input, .bell, .title: break
        }
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
