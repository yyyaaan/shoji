import Foundation
import Testing
@testable import Shoji

/// The shelf: card order, groups and bars, names, and adding or closing threads.
@MainActor
struct ShelfTests {
    private let first = ShojiThread(title: "first", folder: "/tmp", group: 0, order: 0)
    private let second = ShojiThread(folder: "~/code/web", group: 0, order: 1)
    private let third = ShojiThread(title: "third", group: 1, order: 0)

    private func makeStore() -> ThreadStore {
        ThreadStore(threads: [first, second])
    }

    @Test func shelfOrderFollowsGroupsThenOrder() {
        let store = ThreadStore(threads: [third, second, first])
        #expect(store.shelfOrder.map(\.id) == [first.id, second.id, third.id])
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

        // The stones pick the folder.
        let picked = store.newThread(folder: "~/code/shoji")
        #expect(store.thread(picked)?.folder == "~/code/shoji")
        #expect(store.shelfOrder.map(\.id) == [first.id, picked, id, second.id])
        #expect(store.focusRequest == picked)
    }

    @Test func numbersOnlyTellApartThreadsInSameNamedFolders() {
        let store = ThreadStore(threads: [])
        let a = store.newThread()
        let b = store.newThread()
        let names = { [a, b].map { store.thread($0).map(store.name) } }
        #expect(names() == ["~", "~ 2"])

        // The newer thread carries the number, whichever got there first.
        store.send(.directory(NSHomeDirectory() + "/lab/shoji"), to: b)
        #expect(names() == ["~", "shoji"])
        store.send(.directory("/tmp/shoji"), to: a)
        #expect(names() == ["shoji", "shoji 2"])

        // A cd into a subfolder and back changes nothing in the end.
        store.send(.directory("/tmp/shoji/Sources"), to: a)
        #expect(names() == ["Sources", "shoji"])
        store.send(.directory("/tmp/shoji"), to: a)
        #expect(names() == ["shoji", "shoji 2"])
        store.move(b, by: -1)
        #expect(names() == ["shoji", "shoji 2"])

        store.rename(a, to: "api")
        #expect(names() == ["api", "shoji"])
        store.close(a)
        #expect(store.thread(b).map(store.name) == "shoji")
    }

    @Test func agentsGoByTheirTopicWhileTheyRun() {
        let store = ThreadStore(threads: [])
        let a = store.newThread()
        let b = store.newThread()
        let names = { [a, b].map { store.thread($0).map(store.name) } }

        // A title that only names the agent or repeats its command isn't a topic.
        store.send(.commandStarted("claude"), to: b)
        store.send(.title("✳ Claude Code"), to: b)
        store.send(.commandStarted("codex resume 019a"), to: a)
        store.send(.title("codex resume 019a"), to: a)
        #expect(names() == ["~", "~ 2"])

        store.send(.title("✳ Fix login flow"), to: b)
        #expect(names() == ["~", "Fix login flow"])
        store.rename(b, to: "auth")
        #expect(names() == ["~", "auth"])
        store.rename(b, to: "")

        // Gone with the agent; the next one starts without it.
        store.send(.commandFinished(code: 0), to: b)
        #expect(names() == ["~", "~ 2"])
        store.send(.commandStarted("claude"), to: b)
        #expect(names() == ["~", "~ 2"])
    }

    @Test func renameTrimsAndEmptyFallsBackToTheFolder() {
        let store = makeStore()
        store.rename(second.id, to: "  web  ")
        #expect(store.thread(second.id).map(store.name) == "web")
        store.rename(second.id, to: "   ")
        #expect(store.thread(second.id)?.title == nil)
        #expect(store.thread(second.id).map(store.name) == "web")
    }

    @Test func closeAsksOnlyWhenSomethingWouldBeLost() {
        let store = makeStore()
        // Before the shell integration reports in, Shoji can't tell the shell is idle.
        store.requestClose(first.id)
        #expect(store.closeRequest == first.id)
        store.closeRequest = nil

        store.send(.directory("/tmp"), to: first.id)
        store.send(.commandStarted("pnpm dev"), to: first.id)
        store.requestClose(first.id)
        #expect(store.closeRequest == first.id)

        store.close(first.id)
        #expect(store.thread(first.id) == nil)
        #expect(store.closeRequest == nil)
        #expect(store.activities[first.id] == nil)

        store.send(.directory("/tmp"), to: second.id)
        store.requestClose(second.id)
        #expect(store.thread(second.id) == nil)
    }

    @Test func movingAcrossBarsJoinsTheNeighbouringGroup() {
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
}
