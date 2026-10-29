import CoreGraphics
import Foundation

/// The panes as a split tree; `panes` (reading order) is what `ThreadStore`'s opening rules use.
struct PaneLayout: Equatable, Sendable {
    /// Fixed layouts (Panes menu, ⌥⌘1–4).
    enum Preset: String, Codable, CaseIterable, Sendable {
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

        /// Fewer threads fill what they can; three in a grid are two up, one down.
        func tree(_ ids: [UUID], columnSplit: Double = 0.5, rowSplit: Double = 0.5) -> PaneNode? {
            let panes = ids.prefix(capacity).map { PaneNode.pane(id: $0) }
            func columns(_ first: PaneNode, _ second: PaneNode) -> PaneNode {
                .split(axis: .columns, ratio: columnSplit, first: first, second: second)
            }
            func rows(_ first: PaneNode, _ second: PaneNode) -> PaneNode {
                .split(axis: .rows, ratio: rowSplit, first: first, second: second)
            }
            switch panes.count {
            case 0: return nil
            case 1: return panes[0]
            case 2: return columns(panes[0], panes[1])
            case 3 where self == .threePanes: return columns(panes[0], rows(panes[1], panes[2]))
            case 3: return rows(columns(panes[0], panes[1]), panes[2])
            default: return rows(columns(panes[0], panes[1]), columns(panes[2], panes[3]))
            }
        }
    }

    enum Side: Sendable {
        case left, right, up, down
    }

    var root: PaneNode?
    var maximizedThreadId: UUID?

    /// The threads in the panes, maximized or not.
    var panes: [UUID] {
        root?.panes ?? []
    }

    var visibleThreadIds: [UUID] {
        maximizedThreadId.map { [$0] } ?? panes
    }

    /// In place of `replaced` (the last pane when nil), or as the only pane.
    mutating func show(_ id: UUID, replacing replaced: UUID?) {
        maximizedThreadId = nil
        guard !panes.contains(id) else { return }
        guard let target = replaced.flatMap({ panes.contains($0) ? $0 : nil }) ?? panes.last else {
            root = .pane(id: id)
            return
        }
        replace(target, with: id)
    }

    /// Drag and drop: puts a thread in `target`'s pane; one already on screen trades places with it.
    mutating func put(_ id: UUID, inPaneOf target: UUID) {
        maximizedThreadId = nil
        guard id != target, panes.contains(target) else { return }
        if panes.contains(id) {
            root = root?.mapPanes { .pane(id: $0 == id ? target : $0 == target ? id : $0) }
        } else {
            replace(target, with: id)
        }
    }

    /// `id` leaves its old pane if it had one.
    mutating func split(_ target: UUID, side: Side, with id: UUID) {
        maximizedThreadId = nil
        guard id != target, panes.contains(target) else { return }
        root = root?.removing(id)
        let axis: PaneNode.Axis = side == .left || side == .right ? .columns : .rows
        let (new, old) = (PaneNode.pane(id: id), PaneNode.pane(id: target))
        let first = side == .left || side == .up
        root = root?.mapPanes {
            $0 == target ? .split(axis: axis, ratio: 0.5, first: first ? new : old, second: first ? old : new) : .pane(id: $0)
        }
    }

    mutating func removePane(_ id: UUID) {
        root = root?.removing(id)
        if maximizedThreadId == id { maximizedThreadId = nil }
    }

    mutating func setRatio(_ ratio: Double, at path: [Int]) {
        root = root?.settingRatio(ratio, at: path)
    }

    mutating func toggleMaximize(_ id: UUID) {
        maximizedThreadId = maximizedThreadId == id ? nil : id
    }

    private mutating func replace(_ target: UUID, with id: UUID) {
        root = root?.mapPanes { .pane(id: $0 == target ? id : $0) }
    }
}

extension PaneLayout {
    init(_ preset: Preset, _ ids: [UUID]) {
        self.init(root: preset.tree(ids))
    }
}

extension PaneLayout: Codable {
    private enum CodingKeys: String, CodingKey {
        case root, maximizedThreadId
        // v0.3: a fixed layout and its pane order; pins are ignored.
        case mode, openThreadIds, columnSplit, rowSplit
    }

    /// Every key may be missing; a file from before splits becomes its fixed layout.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let root = try container.decodeIfPresent(PaneNode.self, forKey: .root) {
            self.root = root
        } else {
            let preset = try container.decodeIfPresent(Preset.self, forKey: .mode) ?? .twoColumns
            root = preset.tree(
                try container.decodeIfPresent([UUID].self, forKey: .openThreadIds) ?? [],
                columnSplit: try container.decodeIfPresent(Double.self, forKey: .columnSplit) ?? 0.5,
                rowSplit: try container.decodeIfPresent(Double.self, forKey: .rowSplit) ?? 0.5
            )
        }
        let panes = self.panes
        maximizedThreadId = try container.decodeIfPresent(UUID.self, forKey: .maximizedThreadId).flatMap { panes.contains($0) ? $0 : nil }
    }

    /// Also writes the nearest fixed layout, so v0.3 still opens the file.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(root, forKey: .root)
        try container.encodeIfPresent(maximizedThreadId, forKey: .maximizedThreadId)
        try container.encode(Preset.allCases.first { $0.capacity >= panes.count } ?? .grid, forKey: .mode)
        try container.encode(panes, forKey: .openThreadIds)
    }
}

/// One pane showing a thread, or a split: `first` left of or above `second`, `ratio` being first's share.
indirect enum PaneNode: Codable, Equatable, Sendable {
    enum Axis: String, Codable, Sendable {
        case columns, rows
    }

    case pane(id: UUID)
    case split(axis: Axis, ratio: Double, first: PaneNode, second: PaneNode)

    /// In reading order.
    var panes: [UUID] {
        switch self {
        case .pane(let id): [id]
        case .split(_, _, let first, let second): first.panes + second.panes
        }
    }

    func mapPanes(_ transform: (UUID) -> PaneNode) -> PaneNode {
        switch self {
        case .pane(let id): transform(id)
        case .split(let axis, let ratio, let first, let second):
            .split(axis: axis, ratio: ratio, first: first.mapPanes(transform), second: second.mapPanes(transform))
        }
    }

    /// The other side of `id`'s split takes its space; nil when it was the only pane.
    func removing(_ id: UUID) -> PaneNode? {
        switch self {
        case .pane(let pane):
            return pane == id ? nil : self
        case .split(let axis, let ratio, let first, let second):
            guard let first = first.removing(id) else { return second }
            guard let second = second.removing(id) else { return first }
            return .split(axis: axis, ratio: ratio, first: first, second: second)
        }
    }

    /// What takes `id`'s space when its pane goes.
    func sibling(of id: UUID) -> PaneNode? {
        guard case .split(_, _, let first, let second) = self else { return nil }
        if first == .pane(id: id) { return second }
        if second == .pane(id: id) { return first }
        return first.sibling(of: id) ?? second.sibling(of: id)
    }

    /// `path` picks a split from the root: 0 for `first`, 1 for `second` at each level.
    func ratio(at path: [Int]) -> Double? {
        guard case .split(_, let ratio, let first, let second) = self else { return nil }
        guard let step = path.first else { return ratio }
        return (step == 0 ? first : second).ratio(at: Array(path.dropFirst()))
    }

    func settingRatio(_ newRatio: Double, at path: [Int]) -> PaneNode {
        guard case .split(let axis, let ratio, let first, let second) = self else { return self }
        guard let step = path.first else { return .split(axis: axis, ratio: newRatio, first: first, second: second) }
        let rest = Array(path.dropFirst())
        return step == 0
            ? .split(axis: axis, ratio: ratio, first: first.settingRatio(newRatio, at: rest), second: second)
            : .split(axis: axis, ratio: ratio, first: first, second: second.settingRatio(newRatio, at: rest))
    }
}

/// Pane frames, and the gaps between them that work as split handles.
struct PaneTiles {
    struct Handle: Identifiable {
        /// See `PaneNode.ratio(at:)`.
        let path: [Int]
        let axis: PaneNode.Axis
        let rect: CGRect
        /// What the split's ratio is a share of.
        let length: CGFloat

        var id: [Int] { path }
    }

    static let gap: CGFloat = 14

    private(set) var panes: [UUID: CGRect] = [:]
    private(set) var handles: [Handle] = []

    init(_ root: PaneNode?, in rect: CGRect) {
        if let root { add(root, in: rect, path: []) }
    }

    private mutating func add(_ node: PaneNode, in rect: CGRect, path: [Int]) {
        let gap = Self.gap
        switch node {
        case .pane(let id):
            panes[id] = rect
        case .split(.columns, let ratio, let first, let second):
            let x = rect.minX + ((rect.width - gap) * ratio).rounded()
            add(first, in: CGRect(x: rect.minX, y: rect.minY, width: x - rect.minX, height: rect.height), path: path + [0])
            add(second, in: CGRect(x: x + gap, y: rect.minY, width: rect.maxX - x - gap, height: rect.height), path: path + [1])
            handles.append(Handle(path: path, axis: .columns, rect: CGRect(x: x, y: rect.minY, width: gap, height: rect.height), length: rect.width - gap))
        case .split(.rows, let ratio, let first, let second):
            let y = rect.minY + ((rect.height - gap) * ratio).rounded()
            add(first, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: y - rect.minY), path: path + [0])
            add(second, in: CGRect(x: rect.minX, y: y + gap, width: rect.width, height: rect.maxY - y - gap), path: path + [1])
            handles.append(Handle(path: path, axis: .rows, rect: CGRect(x: rect.minX, y: y, width: rect.width, height: gap), length: rect.height - gap))
        }
    }
}
