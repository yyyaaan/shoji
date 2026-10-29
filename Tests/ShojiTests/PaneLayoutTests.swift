import Foundation
import Testing
@testable import Shoji

/// The split tree on its own: showing, trading places, splitting, removing, ratios, presets and the saved shape.
struct PaneLayoutTests {
    private let ids = (0..<5).map { _ in UUID() }

    @Test func showReplacesTheChosenPaneOrStartsTheFirst() {
        var layout = PaneLayout()
        layout.show(ids[0], replacing: nil)
        #expect(layout.panes == [ids[0]])

        layout = PaneLayout(.twoColumns, [ids[0], ids[1]])
        layout.show(ids[2], replacing: ids[0])
        #expect(layout.panes == [ids[2], ids[1]])
        layout.show(ids[1], replacing: ids[2])
        #expect(layout.panes == [ids[2], ids[1]])
        layout.show(ids[3], replacing: nil)
        #expect(layout.panes == [ids[2], ids[3]])
    }

    @Test func droppingACardTakesThatPaneOrTradesPlaces() {
        var layout = PaneLayout(.threePanes, Array(ids.prefix(3)))
        layout.put(ids[2], inPaneOf: ids[0])
        #expect(layout.panes == [ids[2], ids[1], ids[0]])
        layout.put(ids[3], inPaneOf: ids[1])
        #expect(layout.panes == [ids[2], ids[3], ids[0]])
        layout.put(ids[3], inPaneOf: ids[4])
        #expect(layout.panes == [ids[2], ids[3], ids[0]])
    }

    @Test func splitsPutTheNewPaneOnTheChosenSide() {
        var layout = PaneLayout(.single, [ids[0]])
        layout.split(ids[0], side: .right, with: ids[1])
        #expect(layout.root == .split(axis: .columns, ratio: 0.5, first: .pane(id: ids[0]), second: .pane(id: ids[1])))
        layout.split(ids[1], side: .up, with: ids[2])
        #expect(layout.panes == [ids[0], ids[2], ids[1]])
        layout.split(ids[0], side: .left, with: ids[3])
        #expect(layout.panes == [ids[3], ids[0], ids[2], ids[1]])

        // A thread already on screen moves to the new pane, and its old split closes up.
        layout.split(ids[3], side: .down, with: ids[1])
        #expect(layout.panes == [ids[3], ids[1], ids[0], ids[2]])
    }

    @Test func removingAPaneGivesItsSpaceToTheOtherSide() {
        var layout = PaneLayout(.grid, Array(ids.prefix(4)))
        layout.toggleMaximize(ids[1])
        #expect(layout.root?.sibling(of: ids[1]) == .pane(id: ids[0]))

        layout.removePane(ids[1])
        #expect(layout.root == .split(
            axis: .rows, ratio: 0.5,
            first: .pane(id: ids[0]),
            second: .split(axis: .columns, ratio: 0.5, first: .pane(id: ids[2]), second: .pane(id: ids[3]))
        ))
        #expect(layout.maximizedThreadId == nil)

        for id in [ids[0], ids[2], ids[3]] { layout.removePane(id) }
        #expect(layout.root == nil)
    }

    @Test func ratiosFollowTheirSplit() {
        var layout = PaneLayout(.threePanes, Array(ids.prefix(3)))
        layout.setRatio(0.3, at: [])
        layout.setRatio(0.7, at: [1])
        #expect(layout.root?.ratio(at: []) == 0.3)
        #expect(layout.root?.ratio(at: [1]) == 0.7)

        let tiles = PaneTiles(layout.root, in: CGRect(x: 0, y: 0, width: 1014, height: 514))
        #expect(tiles.panes[ids[0]] == CGRect(x: 0, y: 0, width: 300, height: 514))
        #expect(tiles.panes[ids[1]] == CGRect(x: 314, y: 0, width: 700, height: 350))
        #expect(tiles.panes[ids[2]] == CGRect(x: 314, y: 364, width: 700, height: 150))
        #expect(tiles.handles.map(\.path) == [[1], []])
    }

    @Test func presetsFillWhatTheyCan() {
        #expect(PaneLayout.Preset.grid.tree([]) == nil)
        #expect(PaneLayout(.twoColumns, ids).panes == [ids[0], ids[1]])
        // Three in a grid: two up, one down.
        #expect(PaneLayout(.grid, Array(ids.prefix(3))).root == .split(
            axis: .rows, ratio: 0.5,
            first: .split(axis: .columns, ratio: 0.5, first: .pane(id: ids[0]), second: .pane(id: ids[1])),
            second: .pane(id: ids[2])
        ))
    }

    @Test func savesTheTreeWithAFixedLayoutForOlderShoji() throws {
        var layout = PaneLayout(.threePanes, Array(ids.prefix(3)))
        layout.toggleMaximize(ids[1])
        let data = try JSONEncoder().encode(layout)
        #expect(try JSONDecoder().decode(PaneLayout.self, from: data) == layout)

        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["mode"] as? String == "threePanes")
        #expect(json["openThreadIds"] as? [String] == ids.prefix(3).map(\.uuidString))
    }
}
