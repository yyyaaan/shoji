import Foundation

struct PaneLayout: Codable, Equatable, Sendable {
    enum Mode: String, Codable, CaseIterable, Sendable {
        /// `threePanes` is one tall pane on the left with two stacked on the right.
        case single, twoColumns, threePanes, grid

        var capacity: Int {
            switch self {
            case .single: 1
            case .twoColumns: 2
            case .threePanes: 3
            case .grid: 4
            }
        }
    }

    var mode: Mode = .twoColumns {
        didSet { maximizedThreadId = nil }
    }
    /// In pane order; the first `mode.capacity` are on screen, the rest come back when the layout grows.
    var openThreadIds: [UUID] = []
    var maximizedThreadId: UUID?
    /// Share of the width given to the left column, and of the height to the top row.
    var columnSplit = 0.5
    var rowSplit = 0.5

    /// The threads in the layout's panes, maximized or not.
    var panes: [UUID] {
        Array(openThreadIds.prefix(mode.capacity))
    }

    var visibleThreadIds: [UUID] {
        maximizedThreadId.map { [$0] } ?? panes
    }

    /// Puts a thread on screen: in a free pane, else in place of `replaced` (the last pane when nil),
    /// which then comes back first when the layout grows.
    mutating func show(_ id: UUID, replacing replaced: UUID?) {
        maximizedThreadId = nil
        guard !panes.contains(id) else { return }
        openThreadIds.removeAll { $0 == id }
        let shown = panes
        guard shown.count == mode.capacity else {
            openThreadIds.append(id)
            return
        }
        let slot = replaced.flatMap { shown.firstIndex(of: $0) } ?? shown.count - 1
        openThreadIds.insert(openThreadIds[slot], at: shown.count)
        openThreadIds[slot] = id
    }

    mutating func close(_ id: UUID) {
        openThreadIds.removeAll { $0 == id }
        if maximizedThreadId == id { maximizedThreadId = nil }
    }

    mutating func toggleMaximize(_ id: UUID) {
        maximizedThreadId = maximizedThreadId == id ? nil : id
    }
}
