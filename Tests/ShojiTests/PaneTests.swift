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

        // Already on screen: only focus moves.
        store.open(ids[1])
        #expect(store.layout.panes == [ids[2], ids[1]])
        #expect(store.focusRequest == ids[1])
    }

    @Test func withNoPaneFocusedOpenSparesPanesThatWantYou() {
        let (threads, ids) = numberedThreads(4)
        let store = ThreadStore(threads: threads, layout: PaneLayout(.twoColumns, [ids[0], ids[1]]))
        store.send(.needsYou(message: nil), to: ids[1])
        store.open(ids[2])
        #expect(store.layout.panes == [ids[2], ids[1]])

        // A pane Hachi points at for a finished turn is spared too.
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

        // A plain click, ⌘1–9, ⌃Tab and ⌘J go to the thread where it is.
        store.focus(ids[2])
        store.open(ids[1])
        #expect(store.layout.panes == [ids[2], ids[1], ids[0]])
        #expect(store.focusRequest == ids[1])

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
    }

    @Test func splitsLeaveNoPaneTooSmallToUse() {
        let (threads, ids) = numberedThreads(2)
        let store = ThreadStore(threads: threads, layout: PaneLayout(.single, [ids[0]]))
        store.paneAreaSize = CGSize(width: 700, height: 300)
        #expect(!store.split(ids[0], side: .down))
        #expect(store.split(ids[0], side: .right))
        #expect(!store.split(ids[0], side: .left))
        #expect(store.layout.panes == [ids[0], ids[1]])
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

    @Test func cardDragsCarryOnlyTheirThread() async {
        let id = UUID()
        let provider = CardDrag.item(for: id)
        #expect(provider.registeredTypeIdentifiers == [UTType.shojiThread.identifier])
        let loaded = await withCheckedContinuation { done in
            _ = CardDrag.load([provider]) { done.resume(returning: $0) }
        }
        #expect(loaded == id)
    }

    @Test func droppedFilesPasteAsEscapedPathsLikeTerminal() {
        #expect(FileDrop.text(for: ["/Users/yan/Desktop/Screenshot 2026-10-29 at 12.04.png"]) == #"/Users/yan/Desktop/Screenshot\ 2026-10-29\ at\ 12.04.png "#)
        #expect(FileDrop.text(for: ["/tmp/a'b(1)", "/tmp/日本.txt"]) == #"/tmp/a\'b\(1\) /tmp/日本.txt "#)
    }

    @Test func closingAPaneKeepsItsThreadAndTheLastPaneStays() {
        let (threads, ids) = numberedThreads(3)
        let store = ThreadStore(threads: threads, layout: PaneLayout(.threePanes, ids))
        store.focus(ids[1])
        store.closePane(ids[1])
        #expect(store.layout.panes == [ids[0], ids[2]])
        #expect(store.thread(ids[1]) != nil)
        #expect(store.focusRequest == ids[2])

        store.closePane(ids[0])
        store.closePane(ids[2])
        #expect(store.layout.panes == [ids[2]])

        // Closing the last pane's thread shows your most recent other thread there.
        store.close(ids[2])
        #expect(store.layout.panes == [ids[1]])
    }

    @Test func closingTheFocusedThreadFocusesAnotherPane() {
        let (threads, ids) = numberedThreads(3)
        let store = ThreadStore(threads: threads, layout: PaneLayout(.twoColumns, [ids[0], ids[2]]))
        store.focus(ids[2])
        store.close(ids[2])
        #expect(store.focusedThreadId == nil)
        #expect(store.focusRequest == ids[0])
    }
}
