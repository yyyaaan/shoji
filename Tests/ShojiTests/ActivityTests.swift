import Foundation
import Testing
@testable import Shoji

/// How status signals change a thread's activity: agents, commands, the shell, focus and attention.
@MainActor
struct ActivityTests {
    private let first = ShojiThread(title: "first", folder: "/tmp", group: 0, order: 0)
    private let second = ShojiThread(folder: "~/code/web", group: 0, order: 1)
    private let start = Date(timeIntervalSince1970: 1_000)

    private func makeStore() -> ThreadStore {
        ThreadStore(threads: [first, second], now: start)
    }

    @Test func claudeTurnLifecycleInsideTheShell() {
        let store = makeStore()
        #expect(store.activity(for: first.id).status == .idle)

        store.send(.commandStarted("claude"), to: first.id, at: start + 1)
        #expect(store.activity(for: first.id).agent == .claude)
        #expect(store.activity(for: first.id).status == .idle)
        #expect(store.thread(first.id)?.command == "claude")

        store.send(.working(sessionId: "s1"), to: first.id, at: start + 2)
        #expect(store.activity(for: first.id).status == .working)
        #expect(store.thread(first.id)?.resumeId == "s1")

        store.send(.needsYou(message: "Allow Bash"), to: first.id, at: start + 3)
        let waiting = store.activity(for: first.id)
        #expect(waiting.status == .needsYou && waiting.since == start + 3 && waiting.attention == 1 && waiting.detail == "Allow Bash")
        store.send(.userInput, to: first.id, at: start + 4)
        #expect(store.activity(for: first.id).status == .working)
        store.send(.finished, to: first.id, at: start + 5)
        #expect(store.activity(for: first.id).status == .done)

        // Quitting Claude lands back at the shell prompt with nothing left to resume.
        store.send(.commandFinished(code: 0), to: first.id, at: start + 6)
        #expect(store.activity(for: first.id).status == .idle)
        #expect(store.activity(for: first.id).agent == nil)
        #expect(store.thread(first.id)?.resumeId == nil)
        #expect(store.thread(first.id)?.command == nil)
    }

    @Test func codexTurnLifecycleInsideTheShell() {
        let store = makeStore()
        store.send(.commandStarted("codex --full-auto"), to: first.id, at: start + 1)
        #expect(store.activity(for: first.id).agent == .codex)
        #expect(store.activity(for: first.id).status == .idle)

        store.send(.working(sessionId: "c1"), to: first.id, at: start + 2)
        #expect(store.activity(for: first.id).status == .working)
        #expect(store.thread(first.id)?.resumeId == "c1")
        #expect(store.thread(first.id)?.resumeAgent == .codex)
        #expect(store.activity(for: first.id).agent == .codex)
        store.send(.needsYou(message: "Allow Bash: ls"), to: first.id, at: start + 3)
        #expect(store.activity(for: first.id).detail == "Allow Bash: ls")
        store.send(.finished, to: first.id, at: start + 4)
        #expect(store.activity(for: first.id).status == .done)

        // A dead shell forgets the command but keeps the session and its CLI for Restart.
        store.send(.exited(code: 1), to: first.id, at: start + 5)
        #expect(store.thread(first.id)?.command == nil)
        #expect(store.thread(first.id)?.resumeId == "c1" && store.thread(first.id)?.resumeAgent == .codex)
    }

    @Test func hooksMarkAnAgentEvenWhenStartedThroughAnAlias() {
        let store = makeStore()
        store.send(.commandStarted("cc"), to: first.id)
        #expect(store.activity(for: first.id).agent == nil)
        store.send(.working(sessionId: nil), to: first.id)
        #expect(store.activity(for: first.id).agent == .claude)
    }

    @Test func commandsRunAndFinish() {
        let store = makeStore()
        store.send(.commandStarted("pnpm dev"), to: first.id, at: start + 1)
        #expect(store.activity(for: first.id).status == .running)

        store.send(.commandFinished(code: 130), to: first.id, at: start + 2)
        #expect(store.activity(for: first.id).status == .idle)

        store.send(.commandStarted("pnpm build"), to: first.id, at: start + 3)
        store.send(.commandFinished(code: 1), to: first.id, at: start + 4)
        #expect(store.activity(for: first.id).status == .exited(code: 1))
        #expect(store.activity(for: first.id).isAlive)

        store.focus(first.id)
        #expect(store.activity(for: first.id).status == .idle)
    }

    @Test func quittingWouldStopOnlyBusyThreads() {
        let store = makeStore()
        #expect(store.busyThreads.isEmpty)
        // An agent at its own prompt resumes on relaunch, so it isn't busy.
        store.send(.commandStarted("pnpm dev"), to: first.id)
        store.send(.commandStarted("claude"), to: second.id)
        #expect(store.busyThreads.map(\.id) == [first.id])
        store.send(.working(sessionId: nil), to: second.id)
        #expect(store.busyThreads.map(\.id) == [first.id, second.id])
        store.send(.needsYou(message: nil), to: second.id)
        #expect(store.busyThreads.map(\.id) == [first.id, second.id])
        store.send(.finished, to: second.id)
        store.send(.commandFinished(code: 130), to: first.id)
        #expect(store.busyThreads.isEmpty)
    }

    @Test func directoryReportsUpdateTheFolder() {
        let store = makeStore()
        store.send(.directory(NSHomeDirectory() + "/lab/shoji"), to: second.id)
        #expect(store.thread(second.id)?.folder == "~/lab/shoji")
        #expect(store.thread(second.id).map(store.name) == "shoji")
        #expect(store.activity(for: second.id).isIntegrated)
    }

    @Test func shellExitEndsTheThreadUntilRestart() {
        let store = makeStore()
        store.send(.commandStarted("claude"), to: first.id)
        store.send(.exited(code: 0), to: first.id)
        #expect(!store.activity(for: first.id).isAlive)
        #expect(store.activity(for: first.id).agent == nil)
        store.focus(first.id)
        #expect(store.activity(for: first.id).status == .exited(code: 0))

        store.send(.launched, to: first.id, at: start + 9)
        #expect(store.activity(for: first.id) == ThreadActivity(launchedAt: start + 9))
    }

    @Test func launchHandsOverThePrefilledCommandButKeepsTheSession() {
        let saved = ShojiThread(resumeId: "s1", command: "claude")
        let store = ThreadStore(threads: [saved])
        store.send(.launched, to: saved.id)
        #expect(store.thread(saved.id)?.command == nil)
        #expect(store.thread(saved.id)?.resumeId == "s1")
    }

    @Test func focusClearsAttentionAndMarksDoneAsSeen() {
        let store = makeStore()
        store.send(.needsYou(message: nil), to: first.id)
        store.send(.finished, to: first.id)
        #expect(store.activity(for: first.id).attention == 1)

        store.focus(first.id)
        #expect(store.focusedThreadId == first.id)
        #expect(store.activity(for: first.id).attention == 0)
        #expect(store.activity(for: first.id).status == .idle)
    }

    @Test func bellOnlyEscalatesWorkingAgents() {
        let store = makeStore()
        store.send(.commandStarted("make"), to: second.id)
        store.send(.bell, to: second.id)
        #expect(store.activity(for: second.id).status == .running)

        store.send(.working(sessionId: nil), to: first.id)
        store.send(.bell, to: first.id)
        #expect(store.activity(for: first.id).status == .needsYou)
    }

    @Test func repeatedStatusKeepsItsStartTime() {
        let store = makeStore()
        store.send(.working(sessionId: nil), to: first.id, at: start + 1)
        store.send(.working(sessionId: nil), to: first.id, at: start + 60)
        #expect(store.activity(for: first.id).since == start + 1)
    }

    @Test func titlesDropSpinnerGlyphs() {
        let store = makeStore()
        store.send(.title("✳ Fix login flow"), to: first.id)
        #expect(store.activity(for: first.id).terminalTitle == "Fix login flow")
    }

    @Test func unknownThreadsAreIgnored() {
        let store = makeStore()
        store.send(.finished, to: UUID())
        #expect(store.activities.count == 2)
    }

    @Test func aTurnFinishedOutOfSightWantsYouUntilSeen() {
        let store = makeStore()
        store.focus(second.id)
        store.send(.working(sessionId: nil), to: first.id)
        store.send(.finished, to: first.id)
        #expect(store.activity(for: first.id).status == .done)
        #expect(store.wantsYou(first.id))

        // Waiting on an answer comes first wherever its card is: Hachi's count, the Dock badge, the menu bar.
        store.send(.needsYou(message: nil), to: second.id)
        #expect(store.wantingYou.map(\.id) == [second.id, first.id])
        store.send(.working(sessionId: nil), to: second.id)

        #expect(store.openNextNeedingYou())
        #expect(store.focusRequest == first.id)

        store.hachiOnFinish = false
        #expect(!store.wantsYou(first.id))
        #expect(!store.openNextNeedingYou())
        store.hachiOnFinish = true

        store.focus(first.id)
        #expect(!store.wantsYou(first.id))
        #expect(store.activity(for: first.id).status == .idle)

        // Watching it finish is the quiet tick.
        store.send(.working(sessionId: nil), to: first.id)
        store.send(.finished, to: first.id)
        #expect(store.activity(for: first.id).status == .done && !store.wantsYou(first.id))

        // A new turn clears the mark before anyone looks.
        store.focus(second.id)
        store.send(.working(sessionId: nil), to: first.id)
        store.send(.finished, to: first.id)
        #expect(store.wantsYou(first.id))
        store.send(.working(sessionId: nil), to: first.id)
        #expect(!store.wantsYou(first.id))
    }

    @Test func withShojiInTheBackgroundEvenTheFocusedPaneIsOutOfSight() {
        let store = makeStore()
        store.focus(first.id)
        store.isAppActive = false
        store.send(.working(sessionId: nil), to: first.id)
        store.send(.finished, to: first.id)
        #expect(store.wantsYou(first.id))

        store.isAppActive = true
        #expect(!store.wantsYou(first.id))
        #expect(store.activity(for: first.id).status == .idle)
    }
}
