import AppKit
import Testing
@testable import Shoji

@MainActor
struct TerminalSessionsTests {
    final class FakeBackend: TerminalBackend {
        let view = NSView()
        var onEvent: ((TerminalEvent) -> Void)?
        var launches: [TerminalLaunch] = []
        var terminated = false
        var fontSize: CGFloat = 0

        func start(_ launch: TerminalLaunch) { launches.append(launch) }
        func terminate() { terminated = true }
        func focus() {}
        func setFontSize(_ size: CGFloat) { fontSize = size }
        func paste(_ text: String) {}
    }

    private let task = ShojiThread(title: "t", folder: "/tmp")
    private let context = LaunchContext(shell: "/bin/zsh", socketPath: "/tmp/s.sock", hookScript: nil, zsh: nil, environment: [:])

    @Test func syncFollowsTheThreadList() throws {
        let store = ThreadStore(threads: [task])
        var made: [FakeBackend] = []
        let sessions = TerminalSessions(store: store, context: context) {
            let backend = FakeBackend()
            made.append(backend)
            return backend
        }
        sessions.sync()
        #expect(made.count == 1)
        #expect(made[0].launches.count == 1)

        store.close(task.id)
        sessions.sync()
        #expect(made[0].terminated)
        #expect(sessions.terminal(for: task.id) == nil)
    }

    @Test func restartIgnoresTheOldProcessExiting() throws {
        let store = ThreadStore(threads: [task])
        var made: [FakeBackend] = []
        let sessions = TerminalSessions(store: store, context: context) {
            let backend = FakeBackend()
            made.append(backend)
            return backend
        }
        sessions.sync()
        let old = made[0]
        sessions.restart(task.id)
        #expect(old.terminated)
        #expect(made.count == 2)

        old.onEvent?(.exited(code: nil))
        #expect(store.activity(for: task.id).isAlive)
        made[1].onEvent?(.exited(code: 1))
        #expect(store.activity(for: task.id).status == .exited(code: 1))
    }

    @Test func eachTerminalFollowsTheTextSizePlusItsThreadsSteps() {
        let small = ShojiThread(folder: "/tmp", textSteps: -1)
        let store = ThreadStore(threads: [task, small])
        var made: [FakeBackend] = []
        let sessions = TerminalSessions(store: store, context: context) {
            let backend = FakeBackend()
            made.append(backend)
            return backend
        }
        sessions.sync()
        #expect(made.map(\.fontSize) == [13, 11])

        sessions.textZoom = 1.1
        #expect(made.map(\.fontSize) == [14.5, 13])
        store.stepTextSize(of: small.id, by: nil, global: 1.1)
        sessions.applyTextSizes()
        #expect(made.map(\.fontSize) == [14.5, 14.5])
    }

    @Test func quickTerminalEndsIdleOrJoinsTheShelfStillRunning() throws {
        let store = ThreadStore(threads: [task], layout: PaneLayout(.single, [task.id]))
        var made: [FakeBackend] = []
        let sessions = TerminalSessions(store: store, context: context) {
            let backend = FakeBackend()
            made.append(backend)
            return backend
        }
        sessions.sync()
        store.focus(task.id)

        // It opens in your thread's folder, and an idle shell just ends.
        sessions.togglePopup()
        let idle = try #require(made.last)
        #expect(idle.launches.first?.directory == "/tmp")
        idle.onEvent?(.focused)
        #expect(store.focusedThreadId == task.id)
        sessions.togglePopup()
        #expect(idle.terminated && sessions.popup == nil && store.threads.count == 1)

        // Still running something: the same shell becomes a card after yours, without a pane.
        sessions.togglePopup()
        let busy = try #require(made.last)
        busy.onEvent?(.directory("/tmp/site"))
        busy.onEvent?(.commandStarted("python3 -m http.server"))
        sessions.closePopup()
        let adopted = try #require(store.threads.last)
        #expect(!busy.terminated)
        #expect(sessions.terminal(for: adopted.id) === busy)
        #expect(store.shelfOrder.map(\.id) == [task.id, adopted.id])
        #expect(adopted.folder == "/tmp/site" && adopted.command == "python3 -m http.server")
        #expect(store.activity(for: adopted.id).status == .running)
        #expect(store.layout.panes == [task.id])
        busy.onEvent?(.commandFinished(0))
        #expect(store.activity(for: adopted.id).status == .idle)

        // `exit` closes it too.
        sessions.togglePopup()
        made.last?.onEvent?(.exited(code: 0))
        #expect(sessions.popup == nil)
    }
}
