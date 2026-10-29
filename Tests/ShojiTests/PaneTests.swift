import Foundation
import Testing
@testable import Shoji

/// Which pane a thread lands in: card clicks, ⌥-click, drops, pins, layout switches and closing.
/// `PaneLayoutTests` covers the layout value on its own.
@MainActor
struct PaneTests {
    @Test func openShowsTheThreadInThePaneYouAreIn() {
        let (threads, ids) = numberedThreads(4)
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

    @Test func withNoPaneFocusedOpenSparesPanesThatWantYou() {
        let (threads, ids) = numberedThreads(4)
        let store = ThreadStore(threads: threads, layout: PaneLayout(mode: .twoColumns, openThreadIds: [ids[0], ids[1]]))
        store.send(.needsYou(message: nil), to: ids[1])
        store.open(ids[2])
        #expect(store.layout.panes == [ids[2], ids[1]])

        // A pane Hachi points at for a finished turn is spared too.
        let finished = ThreadStore(threads: threads, layout: PaneLayout(mode: .twoColumns, openThreadIds: [ids[0], ids[1]]))
        finished.send(.working(sessionId: nil), to: ids[1])
        finished.send(.finished, to: ids[1])
        finished.open(ids[3])
        #expect(finished.layout.panes == [ids[3], ids[1]])
    }

    @Test func openPassesOverPinnedPanesUntilAllArePinned() {
        let (threads, ids) = numberedThreads(5)
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

    @Test func bringHereComesToYourPane() {
        let (threads, ids) = numberedThreads(3)
        let store = ThreadStore(threads: threads, layout: PaneLayout(mode: .threePanes, openThreadIds: ids))
        store.focus(ids[0])
        store.bringHere(ids[2])
        #expect(store.layout.panes == [ids[2], ids[1], ids[0]])
        #expect(store.focusRequest == ids[2])

        // A plain click, ⌘1–9, ⌃Tab and ⌘J go to the thread where it is.
        store.focus(ids[2])
        store.open(ids[1])
        #expect(store.layout.panes == [ids[2], ids[1], ids[0]])
        #expect(store.focusRequest == ids[1])

        // Off screen, it still comes to your pane rather than a free one; yours moves aside.
        let two = ThreadStore(threads: threads, layout: PaneLayout(mode: .twoColumns, openThreadIds: [ids[0]]))
        two.focus(ids[0])
        two.bringHere(ids[2])
        #expect(two.layout.panes == [ids[2], ids[0]])
    }

    @Test func switchingLayoutsKeepsYourPaneAndPinnedOnesAndFillsNewOnes() {
        let (threads, ids) = numberedThreads(5)
        let store = ThreadStore(threads: threads, layout: PaneLayout(mode: .grid, openThreadIds: Array(ids.prefix(4))))
        store.focus(ids[3])
        store.layoutMode = .twoColumns
        #expect(store.layout.panes == [ids[0], ids[3]])
        store.layoutMode = .grid
        #expect(store.layout.panes == [ids[0], ids[3], ids[2], ids[1]])

        let pinned = ThreadStore(threads: threads, layout: PaneLayout(mode: .grid, openThreadIds: Array(ids.prefix(4))))
        pinned.togglePin(ids[2])
        pinned.focus(ids[3])
        pinned.layoutMode = .twoColumns
        #expect(Set(pinned.layout.panes) == [ids[3], ids[2]])

        let single = ThreadStore(threads: threads, layout: PaneLayout(mode: .single, openThreadIds: [ids[2]]))
        single.focus(ids[2])
        single.open(ids[4])
        single.focus(ids[4])
        single.layoutMode = .threePanes
        #expect(single.layout.panes == [ids[4], ids[2], ids[0]])
    }

    @Test func closingTheFocusedThreadFocusesAnotherPane() {
        let (threads, ids) = numberedThreads(3)
        let store = ThreadStore(threads: threads, layout: PaneLayout(mode: .twoColumns, openThreadIds: [ids[0], ids[2]]))
        store.focus(ids[2])
        store.close(ids[2])
        #expect(store.focusedThreadId == nil)
        #expect(store.focusRequest == ids[0])
    }
}
