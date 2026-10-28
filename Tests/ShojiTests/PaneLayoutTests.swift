import Foundation
import Testing
@testable import Shoji

struct PaneLayoutTests {
    private let ids = (0..<5).map { _ in UUID() }

    @Test func fillsFreePanesThenReplacesTheUnfocusedOne() {
        var layout = PaneLayout(mode: .twoColumns)
        layout.open(ids[0], keeping: nil)
        layout.open(ids[1], keeping: nil)
        #expect(layout.visibleThreadIds == [ids[0], ids[1]])

        layout.open(ids[2], keeping: ids[1])
        #expect(layout.visibleThreadIds == [ids[2], ids[1]])

        layout.open(ids[1], keeping: ids[1])
        #expect(layout.visibleThreadIds == [ids[2], ids[1]])
    }

    @Test func hiddenPanesReturnWhenTheLayoutGrows() {
        var layout = PaneLayout(mode: .grid, openThreadIds: Array(ids.prefix(4)))
        layout.mode = .single
        #expect(layout.visibleThreadIds == [ids[0]])

        layout.open(ids[2], keeping: nil)
        #expect(layout.visibleThreadIds == [ids[2]])

        layout.mode = .grid
        #expect(layout.visibleThreadIds == [ids[2], ids[1], ids[3]])
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
        layout.open(ids[4], keeping: ids[0])
        #expect(layout.visibleThreadIds == [ids[0], ids[1], ids[4]])
    }
}
