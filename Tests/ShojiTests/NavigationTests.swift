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
        let store = ThreadStore(threads: threads, layout: PaneLayout(.twoColumns, [ids[0], ids[2]]))
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
        #expect(TextZoom.step(1, by: 1) == 1.1)
        #expect(TextZoom.step(1, by: -1) == 0.85)
        #expect(TextZoom.step(2, by: 1) == 2)
        #expect(TextZoom.step(0.75, by: -1) == 0.6)
        #expect(TextZoom.step(0.5, by: -1) == 0.5)
        #expect(TextZoom.step(1.17, by: 1) == 1.25)
        #expect(TextZoom.step(1.17, by: -1) == 1.1)

        // A pane's own steps count from the nearest level and stop at the ends; none keeps the size as is.
        #expect(TextZoom.level(1, steps: -1) == 0.85)
        #expect(TextZoom.level(1.17, steps: 0) == 1.17)
        #expect(TextZoom.level(1.17, steps: 1) == 1.25)
        #expect(TextZoom.level(2, steps: 3) == 2)
    }

    @Test func aPaneKeepsItsTextSizeRelativeToTheOthers() {
        let (threads, ids) = numberedThreads(2)
        let store = ThreadStore(threads: threads)
        store.stepTextSize(of: ids[0], by: -1, global: 1)
        #expect(TextZoom.level(1, steps: store.thread(ids[0])?.textSteps ?? 0) == 0.85)
        // ⌘− moves everything a level; the pane stays a level smaller.
        #expect(TextZoom.level(0.85, steps: store.thread(ids[0])?.textSteps ?? 0) == 0.75)

        // At the smallest level there's nowhere to go, so the steps don't pile up unseen.
        store.stepTextSize(of: ids[0], by: -1, global: 0.6)
        store.stepTextSize(of: ids[0], by: -1, global: 0.6)
        #expect(store.thread(ids[0])?.textSteps == -1)

        store.stepTextSize(of: ids[0], by: nil, global: 1)
        #expect(store.thread(ids[0])?.textSteps == nil)
        store.stepTextSize(of: ids[1], by: 1, global: 1)
        store.stepTextSize(of: ids[1], by: -1, global: 1)
        #expect(store.thread(ids[1])?.textSteps == nil)
    }

    @Test func shortcutCapsFollowMacOrder() {
        #expect(Shortcut.toggleMaximize.caps == ["⇧", "⌘", "↩"])
        #expect(Shortcut.grid.caps == ["⌥", "⌘", "4"])
        #expect(Shortcut.zoomIn.caps == ["⌘", "+"])
    }
}
