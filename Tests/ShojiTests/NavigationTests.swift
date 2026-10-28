import Foundation
import SwiftUI
import Testing
@testable import Shoji

@MainActor
struct NavigationTests {
    private let agents = (0..<2).map { ShojiThread(title: "a\($0)", folder: "/tmp", group: 0, order: $0) }
    private let task = ShojiThread(title: "t", folder: "/tmp", group: 1)

    private func makeStore() -> ThreadStore {
        ThreadStore(threads: [task] + agents.reversed())
    }

    @Test func shelfOrderFollowsGroupsThenOrder() {
        #expect(makeStore().shelfOrder.map(\.title) == ["a0", "a1", "t"])
    }

    @Test func nextNeedingYouWrapsFromTheFocusedThread() {
        let store = makeStore()
        #expect(!store.openNextNeedingYou())
        store.apply(StatusEvent(threadId: agents[0].id, signal: .needsYou(message: nil)))
        store.focus(agents[1].id)
        #expect(store.openNextNeedingYou())
        #expect(store.focusRequest == agents[0].id)
        #expect(store.layout.visibleThreadIds.contains(agents[0].id))
    }

    @Test func paneFocusCyclesThroughVisiblePanes() {
        let store = makeStore()
        store.layout = PaneLayout(mode: .twoColumns, openThreadIds: [agents[0].id, task.id])
        store.focusPane(offset: 1)
        #expect(store.focusRequest == agents[0].id)
        store.focus(agents[0].id)
        store.focusPane(offset: 1)
        #expect(store.focusRequest == task.id)
        store.focus(task.id)
        store.focusPane(offset: 1)
        #expect(store.focusRequest == agents[0].id)
    }

    @Test func minimizingTheFocusedPaneFocusesAnother() {
        let store = makeStore()
        store.layout = PaneLayout(mode: .twoColumns, openThreadIds: [agents[0].id, task.id])
        store.focus(task.id)
        store.minimize(task.id)
        #expect(store.focusedThreadId == nil)
        #expect(store.focusRequest == agents[0].id)
    }

    @Test func zoomStepsStopAtTheEnds() {
        #expect(Zoom.step(1, by: 1) == 1.1)
        #expect(Zoom.step(1, by: -1) == 0.85)
        #expect(Zoom.step(2, by: 1) == 2)
        #expect(Zoom.step(0.75, by: -1) == 0.75)
        #expect(Zoom.step(1.17, by: 1) == 1.25)
        #expect(Zoom.step(1.17, by: -1) == 1.1)
    }

    @Test func shortcutCapsFollowMacOrder() {
        #expect(Shortcut.toggleMaximize.caps == ["⇧", "⌘", "↩"])
        #expect(Shortcut.grid.caps == ["⌥", "⌘", "3"])
        #expect(Shortcut.zoomIn.caps == ["⌘", "+"])
    }
}
