import Foundation
import Testing
@testable import Shoji

struct PaneLayoutTests {
    private let ids = (0..<5).map { _ in UUID() }

    @Test func fillsFreePanesThenReplacesTheChosenOne() {
        var layout = PaneLayout(mode: .twoColumns)
        layout.show(ids[0], replacing: nil)
        layout.show(ids[1], replacing: nil)
        #expect(layout.visibleThreadIds == [ids[0], ids[1]])

        layout.show(ids[2], replacing: ids[0])
        #expect(layout.visibleThreadIds == [ids[2], ids[1]])
        #expect(layout.openThreadIds == [ids[2], ids[1], ids[0]])

        layout.show(ids[1], replacing: ids[2])
        #expect(layout.visibleThreadIds == [ids[2], ids[1]])

        layout.show(ids[3], replacing: nil)
        #expect(layout.visibleThreadIds == [ids[2], ids[3]])
    }

    @Test func hiddenPanesReturnWhenTheLayoutGrows() {
        var layout = PaneLayout(mode: .grid, openThreadIds: Array(ids.prefix(4)))
        layout.mode = .single
        #expect(layout.visibleThreadIds == [ids[0]])

        layout.show(ids[4], replacing: ids[0])
        #expect(layout.visibleThreadIds == [ids[4]])

        // The replaced thread comes back first.
        layout.mode = .grid
        #expect(layout.visibleThreadIds == [ids[4], ids[0], ids[1], ids[2]])
    }

    @Test func droppingACardTakesThatPaneOrTradesPlaces() {
        var layout = PaneLayout(mode: .threePanes, openThreadIds: Array(ids.prefix(3)))
        layout.put(ids[2], inPaneOf: ids[0])
        #expect(layout.panes == [ids[2], ids[1], ids[0]])

        layout.put(ids[3], inPaneOf: ids[1])
        #expect(layout.panes == [ids[2], ids[3], ids[0]])
        #expect(layout.openThreadIds == [ids[2], ids[3], ids[0], ids[1]])

        layout.put(ids[4], inPaneOf: ids[1])
        #expect(layout.panes == [ids[2], ids[3], ids[0]])
    }

    @Test func pinsEndWhenTheThreadLeavesThePanes() {
        var layout = PaneLayout(mode: .twoColumns, openThreadIds: [ids[0], ids[1]])
        layout.togglePin(ids[2])
        #expect(layout.pinnedThreadIds.isEmpty)

        layout.togglePin(ids[0])
        layout.togglePin(ids[1])
        layout.put(ids[2], inPaneOf: ids[0])
        #expect(layout.pinnedThreadIds == [ids[1]])
        layout.close(ids[1])
        #expect(layout.pinnedThreadIds.isEmpty)
    }

    @Test func layoutsWithoutNewerFieldsDecode() throws {
        let layout = try JSONDecoder().decode(PaneLayout.self, from: Data(#"{"mode": "grid", "openThreadIds": []}"#.utf8))
        #expect(layout.mode == .grid && layout.columnSplit == 0.5 && layout.pinnedThreadIds.isEmpty)
    }

    @Test func maximizeAndClose() {
        var layout = PaneLayout(mode: .twoColumns, openThreadIds: [ids[0], ids[1]])
        layout.toggleMaximize(ids[1])
        #expect(layout.visibleThreadIds == [ids[1]])

        layout.mode = .grid
        #expect(layout.maximizedThreadId == nil)

        layout.toggleMaximize(ids[0])
        layout.close(ids[0])
        #expect(layout.maximizedThreadId == nil)
        #expect(layout.visibleThreadIds == [ids[1]])
    }

    @Test func threePanesHoldsThree() {
        var layout = PaneLayout(mode: .threePanes, openThreadIds: Array(ids.prefix(4)))
        #expect(layout.visibleThreadIds == Array(ids.prefix(3)))
        layout.show(ids[4], replacing: ids[2])
        #expect(layout.visibleThreadIds == [ids[0], ids[1], ids[4]])
    }
}
