import Foundation
import Testing
@testable import Shoji

@MainActor
struct ThreadStoreTests {
    private let agent = ShojiThread(group: .agent, kind: .claude, title: "agent", folder: "/tmp", command: ["claude"])
    private let task = ShojiThread(group: .task, kind: .command, title: "task", folder: "/tmp", command: ["pnpm", "dev"])
    private let start = Date(timeIntervalSince1970: 1_000)

    private func makeStore() -> ThreadStore {
        ThreadStore(threads: [agent, task], now: start)
    }

    @Test func agentTurnLifecycle() {
        let store = makeStore()
        #expect(store.activity(for: agent.id).status == .idle)
        #expect(store.activity(for: task.id).status == .running)

        store.apply(StatusEvent(threadId: agent.id, signal: .working(sessionId: "s1")), at: start + 1)
        #expect(store.activity(for: agent.id).status == .working)
        #expect(store.thread(agent.id)?.resumeId == "s1")

        store.apply(StatusEvent(threadId: agent.id, signal: .needsYou(message: "Allow Bash")), at: start + 2)
        #expect(store.activity(for: agent.id) == ThreadActivity(status: .needsYou, since: start + 2, attention: 1, detail: "Allow Bash"))

        store.apply(StatusEvent(threadId: agent.id, signal: .userInput), at: start + 3)
        #expect(store.activity(for: agent.id).status == .working)
        #expect(store.activity(for: agent.id).detail == nil)

        store.apply(StatusEvent(threadId: agent.id, signal: .finished), at: start + 4)
        #expect(store.activity(for: agent.id).status == .done)
    }

    @Test func focusClearsAttentionAndMarksDoneAsSeen() {
        let store = makeStore()
        store.apply(StatusEvent(threadId: agent.id, signal: .needsYou(message: nil)))
        store.apply(StatusEvent(threadId: agent.id, signal: .finished))
        #expect(store.activity(for: agent.id).attention == 1)

        store.focus(agent.id)
        #expect(store.focusedThreadId == agent.id)
        #expect(store.activity(for: agent.id).attention == 0)
        #expect(store.activity(for: agent.id).status == .idle)
    }

    @Test func bellOnlyEscalatesWorkingAgents() {
        let store = makeStore()
        store.apply(StatusEvent(threadId: agent.id, signal: .bell))
        store.apply(StatusEvent(threadId: task.id, signal: .bell))
        #expect(store.activity(for: agent.id).status == .idle)
        #expect(store.activity(for: task.id).status == .running)

        store.apply(StatusEvent(threadId: agent.id, signal: .working(sessionId: nil)))
        store.apply(StatusEvent(threadId: agent.id, signal: .bell))
        #expect(store.activity(for: agent.id).status == .needsYou)
    }

    @Test func repeatedStatusKeepsItsStartTime() {
        let store = makeStore()
        store.apply(StatusEvent(threadId: agent.id, signal: .working(sessionId: nil)), at: start + 1)
        store.apply(StatusEvent(threadId: agent.id, signal: .working(sessionId: nil)), at: start + 60)
        #expect(store.activity(for: agent.id).since == start + 1)
    }

    @Test func titlesDropSpinnerGlyphs() {
        let store = makeStore()
        store.apply(StatusEvent(threadId: agent.id, signal: .title("✳ Fix login flow")))
        #expect(store.activity(for: agent.id).terminalTitle == "Fix login flow")
    }

    @Test func exitAndUnknownThreads() {
        let store = makeStore()
        store.apply(StatusEvent(threadId: task.id, signal: .exited(code: 1)))
        store.apply(StatusEvent(threadId: UUID(), signal: .finished))
        #expect(store.activity(for: task.id).status == .exited(code: 1))
        #expect(store.activities.count == 2)
    }
}
