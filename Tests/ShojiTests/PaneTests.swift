import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Shoji

/// Which pane a thread lands in: card clicks, ⌥-click, drops, splits, Arrange and closing; what other drops paste.
/// `PaneLayoutTests` covers the layout value on its own.
@MainActor
struct PaneTests {
    @Test func openShowsTheThreadInThePaneYouAreIn() {
        let (threads, ids) = numberedThreads(4)
        let store = ThreadStore(threads: threads, layout: PaneLayout(.twoColumns, [ids[0], ids[1]]))
        store.focus(ids[0])
        store.open(ids[2])
        #expect(store.layout.panes == [ids[2], ids[1]])
        #expect(store.focusRequest == ids[2])
        #expect(store.paneGlow == nil)

        // Already on screen: only focus moves, and that pane glows. A thread that's gone changes nothing.
        store.open(ids[1])
        #expect(store.layout.panes == [ids[2], ids[1]])
        #expect(store.focusRequest == ids[1])
        #expect(store.paneGlow?.threadId == ids[1])
        store.open(UUID())
        #expect(store.layout.panes == [ids[2], ids[1]])

        // Going where you already are doesn't glow; going back again glows again.
        let glow = store.paneGlow
        store.focus(ids[1])
        store.open(ids[1])
        #expect(store.paneGlow == glow)
        store.focus(ids[2])
        store.open(ids[1])
        #expect(store.paneGlow?.threadId == ids[1] && store.paneGlow != glow)

        // With no pane focused, panes that want you are spared: a question, or a finished turn Hachi points at.
        let asking = ThreadStore(threads: threads, layout: PaneLayout(.twoColumns, [ids[0], ids[1]]))
        asking.send(.needsYou(message: nil), to: ids[1])
        asking.open(ids[2])
        #expect(asking.layout.panes == [ids[2], ids[1]])
        let finished = ThreadStore(threads: threads, layout: PaneLayout(.twoColumns, [ids[0], ids[1]]))
        finished.send(.working(sessionId: nil), to: ids[1])
        finished.send(.finished, to: ids[1])
        finished.open(ids[3])
        #expect(finished.layout.panes == [ids[3], ids[1]])
    }

    @Test func bringHereComesToYourPane() {
        let (threads, ids) = numberedThreads(3)
        let store = ThreadStore(threads: threads, layout: PaneLayout(.threePanes, ids))
        store.focus(ids[0])
        store.bringHere(ids[2])
        #expect(store.layout.panes == [ids[2], ids[1], ids[0]])
        #expect(store.focusRequest == ids[2])

        // Off screen, it takes your pane.
        let one = ThreadStore(threads: threads, layout: PaneLayout(.single, [ids[0]]))
        one.focus(ids[0])
        one.bringHere(ids[2])
        #expect(one.layout.panes == [ids[2]])
    }

    @Test func arrangeKeepsYourPaneAndFillsNewOnes() {
        let (threads, ids) = numberedThreads(5)
        let store = ThreadStore(threads: threads, layout: PaneLayout(.grid, Array(ids.prefix(4))))
        store.focus(ids[3])
        store.arrange(.twoColumns)
        #expect(store.layout.panes == [ids[0], ids[3]])
        store.arrange(.grid)
        #expect(store.layout.panes == [ids[0], ids[3], ids[1], ids[2]])

        let single = ThreadStore(threads: threads, layout: PaneLayout(.single, [ids[2]]))
        single.focus(ids[2])
        single.open(ids[4])
        single.focus(ids[4])
        single.arrange(.threePanes)
        #expect(single.layout.panes == [ids[4], ids[2], ids[0]])
    }

    @Test func splittingShowsYourMostRecentHiddenThreadElseANewShell() throws {
        let (threads, ids) = numberedThreads(3)
        let store = ThreadStore(threads: threads, layout: PaneLayout(.single, [ids[0]]))
        for id in [ids[2], ids[0]] {
            store.open(id)
            store.focus(id)
        }
        #expect(store.split(side: .right))
        #expect(store.layout.panes == [ids[0], ids[2]])
        #expect(store.focusRequest == ids[2])

        store.focus(ids[2])
        #expect(store.split(side: .down))
        #expect(store.layout.panes == [ids[0], ids[2], ids[1]])

        // Every thread is on screen: a new shell in the split pane's folder, its card right after that one.
        #expect(store.split(ids[0], side: .down))
        let shell = try #require(store.layout.panes.first { !ids.contains($0) })
        #expect(store.layout.panes == [ids[0], shell, ids[2], ids[1]])
        #expect(store.shelfOrder.map(\.id) == [ids[0], shell, ids[1], ids[2]])

        // No split leaves a pane too small to use.
        let small = ThreadStore(threads: threads, layout: PaneLayout(.single, [ids[0]]))
        small.paneAreaSize = CGSize(width: 700, height: 300)
        #expect(!small.split(ids[0], side: .down))
        #expect(small.split(ids[0], side: .right))
        #expect(!small.split(ids[0], side: .left))
        #expect(small.layout.panes == [ids[0], ids[1]])
    }

    @Test func droppingACardOnAnEdgeSplitsThere() {
        let (threads, ids) = numberedThreads(3)
        let store = ThreadStore(threads: threads, layout: PaneLayout(.twoColumns, [ids[0], ids[1]]))
        #expect(store.split(ids[1], side: .down, showing: ids[2]))
        #expect(store.layout.panes == [ids[0], ids[1], ids[2]])

        // A card already on screen moves there.
        #expect(store.split(ids[2], side: .left, showing: ids[0]))
        #expect(store.layout.panes == [ids[1], ids[0], ids[2]])
        #expect(!store.split(ids[0], side: .up, showing: ids[0]))

        // The outer quarter on each side is that edge.
        let size = CGSize(width: 400, height: 200)
        #expect(DropZone(CGPoint(x: 90, y: 100), in: size) == .edge(.left))
        #expect(DropZone(CGPoint(x: 200, y: 190), in: size) == .edge(.down))
        #expect(DropZone(CGPoint(x: 200, y: 100), in: size) == .center)
    }

    @Test func cardDragsCarryOnlyTheirThreadAndFilesPasteLikeTerminal() async {
        let id = UUID()
        let provider = CardDrag.item(for: id)
        #expect(provider.registeredTypeIdentifiers == [UTType.shojiThread.identifier])
        let loaded = await withCheckedContinuation { done in
            _ = CardDrag.load([provider]) { done.resume(returning: $0) }
        }
        #expect(loaded == id)

        #expect(FileDrop.text(for: ["/Users/yan/Desktop/Screenshot 2026-10-29 at 12.04.png"]) == #"/Users/yan/Desktop/Screenshot\ 2026-10-29\ at\ 12.04.png "#)
        #expect(FileDrop.text(for: ["/tmp/a'b(1)", "/tmp/日本.txt"]) == #"/tmp/a\'b\(1\) /tmp/日本.txt "#)
    }

    @Test func theCompactFormStartsFromTheRightEdgeEachTime() throws {
        let (threads, ids) = numberedThreads(4)
        let store = ThreadStore(threads: threads, layout: PaneLayout(.threePanes, Array(ids.prefix(3))))
        store.focus(ids[0])

        // The full form's right-hand column, top to bottom; nothing beside it, no third row.
        store.isCompact = true
        #expect(store.layout.root == .split(axis: .rows, ratio: 0.5, first: .pane(id: ids[1]), second: .pane(id: ids[2])))
        #expect(store.focusRequest == ids[1])
        #expect(!store.split(side: .right))
        #expect(!store.split(side: .down))
        store.arrange(.grid)
        #expect(store.layout.panes == [ids[1], ids[2]])

        // A row's dropdown picks its thread, trading places with the other row.
        store.show(ids[3], inPaneOf: ids[2])
        store.show(ids[1], inPaneOf: ids[3])
        #expect(store.layout.panes == [ids[3], ids[1]])
        let shell = store.newThread(inPaneOf: ids[1])
        #expect(store.layout.panes == [ids[3], shell])

        // Picks last until the window widens; the full form comes back as it was, and narrowing starts over.
        store.isCompact = false
        #expect(store.layout.panes == Array(ids.prefix(3)))
        store.isCompact = true
        #expect(store.layout.panes == [ids[1], ids[2]])

        // Closing a thread leaves its row empty and takes it out of the full form; closing the row lets one split down again.
        store.close(ids[2])
        let empty = try #require(store.layout.panes.last)
        #expect(store.layout.panes == [ids[1], empty] && store.thread(empty) == nil)
        store.closePane(empty)
        #expect(store.layout.panes == [ids[1]])
        #expect(store.split(ids[1], side: .down))
        store.isCompact = false
        #expect(store.layout.panes == [ids[0], ids[1]])
    }

    @Test func closingLeavesAnEmptyPaneUntilFilledOrClosed() throws {
        let (threads, ids) = numberedThreads(4)
        var layout = PaneLayout(.twoColumns, [ids[0], ids[2]])
        layout.toggleMaximize(ids[2])
        let store = ThreadStore(threads: threads, layout: layout)
        store.focus(ids[0])
        store.focus(ids[2])

        // ⌘W: the pane stays, empty, maximized as it was, and keeps the keyboard.
        store.close(ids[2])
        let empty = try #require(store.layout.panes.last)
        #expect(store.layout.panes == [ids[0], empty] && store.thread(empty) == nil)
        #expect(store.layout.maximizedPaneId == empty)
        #expect(store.focusedPaneId == empty && store.focusedThreadId == nil)
        #expect(store.focusRequest == empty)

        // A go-to fills it; a new thread there sits after your last card.
        store.focus(empty)
        store.openThread(at: 1)
        #expect(store.layout.panes == [ids[0], ids[1]])
        store.close(ids[1])
        let next = try #require(store.layout.panes.last)
        let shell = store.newThread(inPaneOf: next)
        #expect(store.layout.panes == [ids[0], shell])
        #expect(store.shelfOrder.map(\.id) == [ids[0], shell, ids[3]])

        // Unfocused, an empty pane is still the first a go-to fills.
        store.close(shell)
        store.focus(ids[0])
        store.open(ids[3])
        #expect(store.layout.panes == [ids[0], ids[3]])

        // ⌘W again closes it, and that isn't something ⇧⌘T brings back.
        store.close(ids[3])
        let last = try #require(store.layout.panes.last)
        store.closePane(last)
        #expect(store.layout.panes == [ids[0]])
        store.reopenClosed()
        #expect(store.thread(ids[3]) != nil)
        #expect(store.layout.panes == [ids[0], ids[3]])

        // Close Pane keeps the thread on the shelf; the last pane stays, even empty.
        store.focus(ids[3])
        store.closePane(ids[3])
        #expect(store.thread(ids[3]) != nil)
        #expect(store.focusRequest == ids[0])
        store.closePane(ids[0])
        #expect(store.layout.panes == [ids[0]])
        store.close(ids[0])
        let alone = try #require(store.layout.panes.first)
        store.closePane(alone)
        #expect(store.layout.panes == [alone] && store.thread(alone) == nil)
    }
}
