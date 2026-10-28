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
    /// Ordered; the first `mode.capacity` are on screen, the rest come back when the layout grows.
    var openThreadIds: [UUID] = []
    var maximizedThreadId: UUID?
    /// Share of the width given to the left column, and of the height to the top row.
    var columnSplit = 0.5
    var rowSplit = 0.5

    var visibleThreadIds: [UUID] {
        if let maximizedThreadId { return [maximizedThreadId] }
        return Array(openThreadIds.prefix(mode.capacity))
    }

    /// Puts a thread on screen. When every pane is taken, it replaces the last pane other than `focused`.
    mutating func open(_ id: UUID, keeping focused: UUID?) {
        maximizedThreadId = nil
        guard !visibleThreadIds.contains(id) else { return }
        openThreadIds.removeAll { $0 == id }
        let visible = openThreadIds.prefix(mode.capacity)
        if visible.count < mode.capacity {
            openThreadIds.insert(id, at: visible.endIndex)
        } else {
            let slot = visible.lastIndex { $0 != focused } ?? visible.endIndex - 1
            openThreadIds[slot] = id
        }
    }

    mutating func close(_ id: UUID) {
        openThreadIds.removeAll { $0 == id }
        if maximizedThreadId == id { maximizedThreadId = nil }
    }

    mutating func toggleMaximize(_ id: UUID) {
        maximizedThreadId = maximizedThreadId == id ? nil : id
    }
}
