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

        func start(_ launch: TerminalLaunch) { launches.append(launch) }
        func terminate() { terminated = true }
        func focus() {}
        func setFontSize(_ size: CGFloat) {}
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
}
