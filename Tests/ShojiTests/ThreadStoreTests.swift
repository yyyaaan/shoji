import Foundation
import Testing
@testable import Shoji

@MainActor
struct ThreadStoreTests {
    private let first = ShojiThread(title: "first", folder: "/tmp", group: 0, order: 0)
    private let second = ShojiThread(folder: "~/code/web", group: 0, order: 1)
    private let start = Date(timeIntervalSince1970: 1_000)

    private func makeStore() -> ThreadStore {
        ThreadStore(threads: [first, second], now: start)
    }

    private func send(_ signal: StatusEvent.Signal, to id: UUID, in store: ThreadStore, at time: Date = .now) {
        store.apply(StatusEvent(threadId: id, signal: signal), at: time)
    }

    @Test func claudeTurnLifecycleInsideTheShell() {
        let store = makeStore()
        #expect(store.activity(for: first.id).status == .idle)

        send(.commandStarted("claude"), to: first.id, in: store, at: start + 1)
        #expect(store.activity(for: first.id).agent == .claude)
        #expect(store.activity(for: first.id).status == .idle)
        #expect(store.thread(first.id)?.command == "claude")

        send(.working(sessionId: "s1"), to: first.id, in: store, at: start + 2)
        #expect(store.activity(for: first.id).status == .working)
        #expect(store.thread(first.id)?.resumeId == "s1")

        send(.needsYou(message: "Allow Bash"), to: first.id, in: store, at: start + 3)
        let waiting = store.activity(for: first.id)
        #expect(waiting.status == .needsYou && waiting.since == start + 3 && waiting.attention == 1 && waiting.detail == "Allow Bash")
        send(.userInput, to: first.id, in: store, at: start + 4)
        #expect(store.activity(for: first.id).status == .working)
        send(.finished, to: first.id, in: store, at: start + 5)
        #expect(store.activity(for: first.id).status == .done)

        // Quitting Claude lands back at the shell prompt with nothing left to resume.
        send(.commandFinished(code: 0), to: first.id, in: store, at: start + 6)
        #expect(store.activity(for: first.id).status == .idle)
        #expect(store.activity(for: first.id).agent == nil)
        #expect(store.thread(first.id)?.resumeId == nil)
        #expect(store.thread(first.id)?.command == nil)
    }

    @Test func hooksMarkAnAgentEvenWhenStartedThroughAnAlias() {
        let store = makeStore()
        send(.commandStarted("cc"), to: first.id, in: store)
        #expect(store.activity(for: first.id).agent == nil)
        send(.working(sessionId: nil), to: first.id, in: store)
        #expect(store.activity(for: first.id).agent == .claude)
    }

    @Test func commandsRunAndFinish() {
        let store = makeStore()
        send(.commandStarted("pnpm dev"), to: first.id, in: store, at: start + 1)
        #expect(store.activity(for: first.id).status == .running)

        send(.commandFinished(code: 130), to: first.id, in: store, at: start + 2)
        #expect(store.activity(for: first.id).status == .idle)

        send(.commandStarted("pnpm build"), to: first.id, in: store, at: start + 3)
        send(.commandFinished(code: 1), to: first.id, in: store, at: start + 4)
        #expect(store.activity(for: first.id).status == .exited(code: 1))
        #expect(store.activity(for: first.id).isAlive)

        store.focus(first.id)
        #expect(store.activity(for: first.id).status == .idle)
    }

    @Test func directoryReportsUpdateTheFolder() {
        let store = makeStore()
        send(.directory(NSHomeDirectory() + "/lab/shoji"), to: second.id, in: store)
        #expect(store.thread(second.id)?.folder == "~/lab/shoji")
        #expect(store.thread(second.id).map(store.name) == "shoji")
        #expect(store.activity(for: second.id).isIntegrated)
    }

    @Test func shellExitEndsTheThreadUntilRestart() {
        let store = makeStore()
        send(.commandStarted("claude"), to: first.id, in: store)
        send(.exited(code: 0), to: first.id, in: store)
        #expect(!store.activity(for: first.id).isAlive)
        #expect(store.activity(for: first.id).agent == nil)
        store.focus(first.id)
        #expect(store.activity(for: first.id).status == .exited(code: 0))

        send(.launched, to: first.id, in: store, at: start + 9)
        #expect(store.activity(for: first.id) == ThreadActivity(launchedAt: start + 9))
    }

    @Test func launchHandsOverThePrefilledCommandButKeepsTheSession() {
        let saved = ShojiThread(resumeId: "s1", command: "claude")
        let store = ThreadStore(threads: [saved])
        send(.launched, to: saved.id, in: store)
        #expect(store.thread(saved.id)?.command == nil)
        #expect(store.thread(saved.id)?.resumeId == "s1")
    }

    @Test func focusClearsAttentionAndMarksDoneAsSeen() {
        let store = makeStore()
        send(.needsYou(message: nil), to: first.id, in: store)
        send(.finished, to: first.id, in: store)
        #expect(store.activity(for: first.id).attention == 1)

        store.focus(first.id)
        #expect(store.focusedThreadId == first.id)
        #expect(store.activity(for: first.id).attention == 0)
        #expect(store.activity(for: first.id).status == .idle)
    }

    @Test func bellOnlyEscalatesWorkingAgents() {
        let store = makeStore()
        send(.commandStarted("make"), to: second.id, in: store)
        send(.bell, to: second.id, in: store)
        #expect(store.activity(for: second.id).status == .running)

        send(.working(sessionId: nil), to: first.id, in: store)
        send(.bell, to: first.id, in: store)
        #expect(store.activity(for: first.id).status == .needsYou)
    }

    @Test func repeatedStatusKeepsItsStartTime() {
        let store = makeStore()
        send(.working(sessionId: nil), to: first.id, in: store, at: start + 1)
        send(.working(sessionId: nil), to: first.id, in: store, at: start + 60)
        #expect(store.activity(for: first.id).since == start + 1)
    }

    @Test func titlesDropSpinnerGlyphs() {
        let store = makeStore()
        send(.title("✳ Fix login flow"), to: first.id, in: store)
        #expect(store.activity(for: first.id).terminalTitle == "Fix login flow")
    }

    @Test func unknownThreadsAreIgnored() {
        let store = makeStore()
        send(.finished, to: UUID(), in: store)
        #expect(store.activities.count == 2)
    }

    @Test func newThreadOpensNextToTheFocusedCardInItsFolder() {
        let store = makeStore()
        store.focus(first.id)
        let id = store.newThread()
        #expect(store.shelfOrder.map(\.id) == [first.id, id, second.id])
        #expect(store.thread(id)?.folder == "/tmp")
        #expect(store.layout.visibleThreadIds.contains(id))
        #expect(store.focusRequest == id)

        let empty = ThreadStore(threads: [])
        let home = empty.newThread()
        #expect(empty.thread(home)?.folder == "~")
        #expect(empty.thread(home).map(empty.name) == "~")
    }

    @Test func numbersOnlyTellApartThreadsInSameNamedFolders() {
        let store = ThreadStore(threads: [])
        let a = store.newThread()
        let b = store.newThread()
        let names = { [a, b].map { store.thread($0).map(store.name) } }
        #expect(names() == ["~", "~ 2"])

        // Whoever arrives in a folder later carries the number.
        send(.directory(NSHomeDirectory() + "/lab/shoji"), to: a, in: store)
        #expect(names() == ["shoji", "~"])
        send(.directory("/tmp/shoji"), to: b, in: store)
        #expect(names() == ["shoji", "shoji 2"])
        store.move(b, by: -1)
        #expect(names() == ["shoji", "shoji 2"])

        store.rename(a, to: "api")
        #expect(names() == ["api", "shoji"])
        store.close(a)
        #expect(store.thread(b).map(store.name) == "shoji")
    }

    @Test func closeAsksOnlyWhenSomethingWouldBeLost() {
        let store = makeStore()
        // Before the shell integration reports in, Shoji can't tell the shell is idle.
        store.requestClose(first.id)
        #expect(store.closeRequest == first.id)
        store.closeRequest = nil

        send(.directory("/tmp"), to: first.id, in: store)
        send(.commandStarted("pnpm dev"), to: first.id, in: store)
        store.requestClose(first.id)
        #expect(store.closeRequest == first.id)

        store.close(first.id)
        #expect(store.thread(first.id) == nil)
        #expect(store.closeRequest == nil)
        #expect(store.activities[first.id] == nil)

        send(.directory("/tmp"), to: second.id, in: store)
        store.requestClose(second.id)
        #expect(store.thread(second.id) == nil)
    }

    @Test func renameTrimsAndEmptyFallsBackToTheFolder() {
        let store = makeStore()
        store.rename(second.id, to: "  web  ")
        #expect(store.thread(second.id).map(store.name) == "web")
        store.rename(second.id, to: "   ")
        #expect(store.thread(second.id)?.title == nil)
        #expect(store.thread(second.id).map(store.name) == "web")
    }

    @Test func movingAcrossBarsJoinsTheNeighbouringGroup() {
        let third = ShojiThread(title: "third", group: 1, order: 0)
        let store = ThreadStore(threads: [first, second, third])
        let titles = { store.shelf.map { $0.map(store.name) } }
        #expect(titles() == [["first", "web"], ["third"]])
        #expect(!store.canMove(first.id, by: -1))
        #expect(!store.canMove(third.id, by: 1))

        store.move(second.id, by: 1)
        #expect(titles() == [["first"], ["web", "third"]])
        store.move(first.id, by: 1)
        #expect(titles() == [["first", "web", "third"]])
        store.move(third.id, by: -1)
        #expect(titles() == [["first", "third", "web"]])

        store.toggleBarBefore(third.id)
        #expect(titles() == [["first"], ["third", "web"]])
        #expect(store.hasBarBefore(third.id))
        store.toggleBarBefore(third.id)
        #expect(titles() == [["first", "third", "web"]])
    }

    @Test func droppingACardPlacesItBesideTheTarget() {
        let third = ShojiThread(title: "third", group: 1, order: 0)
        let store = ThreadStore(threads: [first, second, third])
        let titles = { store.shelf.map { $0.map(store.name) } }

        store.place(first.id, nextTo: third.id, after: true)
        #expect(titles() == [["web"], ["third", "first"]])
        store.place(second.id, nextTo: first.id, after: false)
        #expect(titles() == [["third", "web", "first"]])
        store.place(first.id, nextTo: third.id, after: false)
        #expect(titles() == [["first", "third", "web"]])
        store.place(first.id, nextTo: first.id, after: true)
        #expect(titles() == [["first", "third", "web"]])
    }

    @Test func openingACardReplacesThePaneYouAreIn() {
        let threads = (0..<4).map { ShojiThread(title: "\($0)", order: $0) }
        let ids = threads.map(\.id)
        let store = ThreadStore(threads: threads, layout: PaneLayout(mode: .twoColumns, openThreadIds: [ids[0], ids[1]]))
        store.focus(ids[0])
        store.open(ids[2])
        #expect(store.layout.panes == [ids[2], ids[1]])
        #expect(store.focusRequest == ids[2])

        // Already on screen: only focus moves.
        store.open(ids[1])
        #expect(store.layout.panes == [ids[2], ids[1]])
        #expect(store.focusRequest == ids[1])
    }

    @Test func withNoPaneFocusedOpeningSparesPanesThatNeedYou() {
        let threads = (0..<4).map { ShojiThread(title: "\($0)", order: $0) }
        let ids = threads.map(\.id)
        let store = ThreadStore(threads: threads, layout: PaneLayout(mode: .twoColumns, openThreadIds: [ids[0], ids[1]]))
        send(.needsYou(message: nil), to: ids[1], in: store)
        store.open(ids[2])
        #expect(store.layout.panes == [ids[2], ids[1]])
    }

    @Test func switchingLayoutsKeepsYourPaneAndFillsNewOnes() {
        let threads = (0..<5).map { ShojiThread(title: "\($0)", order: $0) }
        let ids = threads.map(\.id)
        let store = ThreadStore(threads: threads, layout: PaneLayout(mode: .grid, openThreadIds: Array(ids.prefix(4))))
        store.focus(ids[3])
        store.layoutMode = .twoColumns
        #expect(store.layout.panes == [ids[0], ids[3]])
        store.layoutMode = .grid
        #expect(store.layout.panes == [ids[0], ids[3], ids[2], ids[1]])

        let single = ThreadStore(threads: threads, layout: PaneLayout(mode: .single, openThreadIds: [ids[2]]))
        single.focus(ids[2])
        single.open(ids[4])
        single.focus(ids[4])
        single.layoutMode = .threePanes
        #expect(single.layout.panes == [ids[4], ids[2], ids[0]])
    }

    @Test func openingPassesOverPinnedPanesUntilAllArePinned() {
        let threads = (0..<5).map { ShojiThread(title: "\($0)", order: $0) }
        let ids = threads.map(\.id)
        let store = ThreadStore(threads: threads, layout: PaneLayout(mode: .twoColumns, openThreadIds: [ids[0], ids[1]]))
        store.focus(ids[0])
        store.togglePin(ids[0])
        store.open(ids[2])
        #expect(store.layout.panes == [ids[0], ids[2]])

        // Dropping a card is explicit, so it takes even a pinned pane.
        store.show(ids[3], inPaneOf: ids[0])
        #expect(store.layout.panes == [ids[3], ids[2]])
        #expect(store.layout.pinnedThreadIds.isEmpty)

        store.togglePin(ids[3])
        store.togglePin(ids[2])
        store.focus(ids[3])
        store.open(ids[4])
        #expect(store.layout.panes == [ids[4], ids[2]])
    }

    @Test func shrinkingKeepsPinnedPanesOnScreen() {
        let threads = (0..<4).map { ShojiThread(title: "\($0)", order: $0) }
        let ids = threads.map(\.id)
        let store = ThreadStore(threads: threads, layout: PaneLayout(mode: .grid, openThreadIds: ids))
        store.togglePin(ids[2])
        store.focus(ids[3])
        store.layoutMode = .twoColumns
        #expect(Set(store.layout.panes) == [ids[3], ids[2]])
    }

    @Test func recentSwitchStepsInTheOrderOfUse() {
        let threads = (0..<4).map { ShojiThread(title: "\($0)", order: $0) }
        let ids = threads.map(\.id)
        let store = ThreadStore(threads: threads)
        for id in [ids[2], ids[0], ids[1]] {
            store.open(id)
            store.focus(id)
        }

        // A quick ⌃Tab goes back to the previous thread.
        store.stepRecent(by: 1)
        #expect(store.recentSwitch?.threadIds == [ids[1], ids[0], ids[2], ids[3]])
        store.finishRecentSwitch()
        #expect(store.recentSwitch == nil)
        #expect(store.focusRequest == ids[0])
        store.focus(ids[0])

        // Holding ⌃ keeps stepping, wrapping around; ⌃⇧Tab steps back.
        store.stepRecent(by: 1)
        store.stepRecent(by: 1)
        store.stepRecent(by: 1)
        #expect(store.recentSwitch?.selected == ids[3])
        store.stepRecent(by: 1)
        #expect(store.recentSwitch?.selected == ids[0])
        store.stepRecent(by: -1)
        #expect(store.recentSwitch?.selected == ids[3])
        store.cancelRecentSwitch()
        #expect(store.recentSwitch == nil && store.focusRequest == nil)

        store.stepRecent(by: -1)
        #expect(store.recentSwitch?.selected == ids[3])
    }
}
