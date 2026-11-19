import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// Where a dragged card lands: an edge splits the pane, the middle takes it.
enum DropZone: Equatable {
    case center
    case edge(PaneLayout.Side)

    /// The outer quarter of the pane on each side counts as that edge.
    init(_ point: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { self = .center; return }
        let distances: [(PaneLayout.Side, CGFloat)] = [
            (.left, point.x / size.width), (.right, 1 - point.x / size.width),
            (.up, point.y / size.height), (.down, 1 - point.y / size.height),
        ]
        guard let nearest = distances.min(by: { $0.1 < $1.1 }), nearest.1 < 0.25 else { self = .center; return }
        self = .edge(nearest.0)
    }

    var alignment: Alignment {
        switch self {
        case .center: .center
        case .edge(.left): .leading
        case .edge(.right): .trailing
        case .edge(.up): .top
        case .edge(.down): .bottom
        }
    }
}

/// Files and text from other apps paste like Terminal; a file as its path, so screenshots reach Claude Code.
struct PaneDrop: DropDelegate {
    static let types: [UTType] = [.shojiThread, .fileURL, .plainText]

    let target: UUID
    let size: CGSize
    @Binding var zone: DropZone?
    let store: ThreadStore
    let terminal: (any TerminalBackend)?

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: Self.types)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let isCard = info.hasItemsConforming(to: [.shojiThread])
        var next: DropZone? = isCard ? DropZone(info.location, in: size) : .center
        // Only a split that would happen gets a preview.
        if case .edge(let side) = next, !store.canSplit(target, side: side) { next = nil }
        if zone != next { zone = next }
        return DropProposal(operation: next == nil ? .forbidden : isCard ? .move : .copy)
    }

    func dropExited(info: DropInfo) {
        zone = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        zone = nil
        let (target, store) = (target, store)
        if info.hasItemsConforming(to: [.shojiThread]) {
            let landing = DropZone(info.location, in: size)
            return CardDrag.load(info.itemProviders(for: [.shojiThread])) { id in
                switch landing {
                case .center: store.show(id, inPaneOf: target)
                case .edge(let side): if !store.split(target, side: side, showing: id) { NSSound.beep() }
                }
            }
        }
        guard let terminal else { return false }
        let files = info.itemProviders(for: [.fileURL])
        let texts = info.itemProviders(for: [.plainText])
        Task {
            var text = ""
            if !files.isEmpty {
                var paths: [String] = []
                for provider in files {
                    let url = await withCheckedContinuation { done in
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in done.resume(returning: url) }
                    }
                    if let url { paths.append(url.path) }
                }
                text = FileDrop.text(for: paths)
            } else if let provider = texts.first {
                text = await withCheckedContinuation { done in
                    _ = provider.loadObject(ofClass: String.self) { text, _ in done.resume(returning: text ?? "") }
                }
            }
            guard !text.isEmpty else { return }
            // Invariant 6: a paste the user dropped, sent as dropped.
            Logger(subsystem: "fi.yan.shoji", category: "terminal").info("Pasted a drop of \(text.count) characters into \(target, privacy: .public)")
            terminal.paste(text)
            store.open(target)
        }
        return true
    }
}

enum FileDrop {
    /// As Terminal pastes dropped files: backslash-escaped, a space after each.
    static func text(for paths: [String]) -> String {
        paths.map { path in
            path.reduce(into: "") { escaped, character in
                if !(character.isLetter || character.isNumber || "/._-+@%:,=".contains(character)) { escaped.append("\\") }
                escaped.append(character)
            }
        }
        .map { $0 + " " }
        .joined()
    }
}
