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
    /// Kept on screen: opening other threads passes over their panes. Pins follow threads, and end when one
    /// leaves the panes for good (closed or replaced).
    var pinnedThreadIds: [UUID] = []
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
        replace(slot: replaced.flatMap { shown.firstIndex(of: $0) } ?? shown.count - 1, with: id)
    }

    /// Drag and drop: puts a thread in `target`'s pane; one already on screen trades places with it.
    mutating func put(_ id: UUID, inPaneOf target: UUID) {
        maximizedThreadId = nil
        let shown = panes
        guard id != target, let slot = shown.firstIndex(of: target) else { return }
        if let from = shown.firstIndex(of: id) {
            openThreadIds.swapAt(from, slot)
        } else {
            // Off screen, so after `slot`: removing it doesn't move the slot.
            openThreadIds.removeAll { $0 == id }
            replace(slot: slot, with: id)
        }
    }

    private mutating func replace(slot: Int, with id: UUID) {
        let replaced = openThreadIds[slot]
        openThreadIds[slot] = id
        openThreadIds.insert(replaced, at: min(mode.capacity, openThreadIds.count))
        pinnedThreadIds.removeAll { $0 == replaced }
    }

    mutating func close(_ id: UUID) {
        openThreadIds.removeAll { $0 == id }
        pinnedThreadIds.removeAll { $0 == id }
        if maximizedThreadId == id { maximizedThreadId = nil }
    }

    mutating func togglePin(_ id: UUID) {
        if pinnedThreadIds.contains(id) {
            pinnedThreadIds.removeAll { $0 == id }
        } else if panes.contains(id) {
            pinnedThreadIds.append(id)
        }
    }

    mutating func toggleMaximize(_ id: UUID) {
        maximizedThreadId = maximizedThreadId == id ? nil : id
    }
}

extension PaneLayout {
    /// Every key may be missing, so files from before a field existed still load (pins came after v0.2).
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? mode
        openThreadIds = try container.decodeIfPresent([UUID].self, forKey: .openThreadIds) ?? []
        maximizedThreadId = try container.decodeIfPresent(UUID.self, forKey: .maximizedThreadId)
        pinnedThreadIds = try container.decodeIfPresent([UUID].self, forKey: .pinnedThreadIds) ?? []
        columnSplit = try container.decodeIfPresent(Double.self, forKey: .columnSplit) ?? columnSplit
        rowSplit = try container.decodeIfPresent(Double.self, forKey: .rowSplit) ?? rowSplit
    }
}
