import Foundation
import SwiftUI
import Testing
@testable import Shoji

/// Keyboard navigation: ⌘J, ⌘] / ⌘[, ⌃Tab, zoom steps and how shortcuts are spelled.
@MainActor
struct NavigationTests {
    @Test func nextNeedingYouWrapsFromTheFocusedThread() {
        let (threads, ids) = numberedThreads(3)
        let store = ThreadStore(threads: threads)
        #expect(!store.openNextNeedingYou())
        store.send(.needsYou(message: nil), to: ids[0])
        store.focus(ids[1])
        #expect(store.openNextNeedingYou())
        #expect(store.focusRequest == ids[0])
        #expect(store.layout.visibleThreadIds.contains(ids[0]))
    }

    @Test func paneFocusCyclesThroughVisiblePanes() {
        let (threads, ids) = numberedThreads(3)
        let store = ThreadStore(threads: threads, layout: PaneLayout(mode: .twoColumns, openThreadIds: [ids[0], ids[2]]))
        store.focusPane(offset: 1)
        #expect(store.focusRequest == ids[0])
        store.focus(ids[0])
        store.focusPane(offset: 1)
        #expect(store.focusRequest == ids[2])
        store.focus(ids[2])
        store.focusPane(offset: 1)
        #expect(store.focusRequest == ids[0])
    }

    @Test func recentSwitchStepsInTheOrderOfUse() {
        let (threads, ids) = numberedThreads(4)
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
        #expect(Shortcut.grid.caps == ["⌥", "⌘", "4"])
        #expect(Shortcut.zoomIn.caps == ["⌘", "+"])
    }
}
