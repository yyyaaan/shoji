import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct PaneView: View {
    let thread: ShojiThread

    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @Environment(\.zoom) private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(TextZoom.storageKey) private var textZoom = 1.0
    @State private var dropZone: DropZone?
    /// 0…1, the ivory glow after a go-to lands here.
    @State private var glow = 0.0
    @State private var size = CGSize.zero
    @State private var isHovering = false

    private var isFocused: Bool { store.focusedThreadId == thread.id }
    private var isMaximized: Bool { store.layout.maximizedThreadId == thread.id }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if let terminal = sessions?.terminal(for: thread.id) {
                    TerminalHost(terminal: terminal, wantsFocus: store.focusRequest == thread.id)
                } else {
                    Color.clear
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.terminalBackground)
        }
        .clipShape(.rect(cornerRadius: 18 * zoom))
        .overlay {
            RoundedRectangle(cornerRadius: 18 * zoom)
                .fill(Palette.working.opacity(dropZone == .center ? 0.08 : 0))
                .strokeBorder(dropZone == .center ? Palette.working : .white.opacity(isFocused ? 0.32 : 0.16), lineWidth: dropZone == .center ? 2 : 1)
                .allowsHitTesting(false)
        }
        // The half a card dropped on this edge would take.
        .overlay(alignment: dropZone?.alignment ?? .center) {
            if case .edge(let side) = dropZone {
                RoundedRectangle(cornerRadius: 18 * zoom)
                    .fill(Palette.working.opacity(0.14))
                    .strokeBorder(Palette.working, lineWidth: 2)
                    .frame(
                        width: side == .left || side == .right ? (size.width - PaneTiles.gap) / 2 : nil,
                        height: side == .up || side == .down ? (size.height - PaneTiles.gap) / 2 : nil
                    )
                    .allowsHitTesting(false)
            }
        }
        // "Here it is": a card click, ⌘1–9, ⌃Tab, ⌘J, Hachi or a notification moved focus to this pane.
        .overlay {
            RoundedRectangle(cornerRadius: 18 * zoom)
                .strokeBorder(Palette.done.opacity(0.85 * glow), lineWidth: 2)
                .shadow(color: Palette.done.opacity(0.55 * glow), radius: 14 * zoom)
                .allowsHitTesting(false)
        }
        .onChange(of: store.paneGlow) { _, glowing in
            guard glowing?.threadId == thread.id else { return }
            if reduceMotion {
                glow = 1
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    glow = 0
                }
            } else {
                withAnimation(.easeOut(duration: 0.15)) { glow = 1 } completion: {
                    withAnimation(.easeIn(duration: 0.55)) { glow = 0 }
                }
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onDrop(of: PaneDrop.types, delegate: PaneDrop(target: thread.id, size: size, zone: $dropZone, store: store, terminal: sessions?.terminal(for: thread.id)))
    }

    private var header: some View {
        HStack(spacing: 10 * zoom) {
            StatusIcon(status: store.activity(for: thread.id).status, size: 16 * zoom)
            Text(store.name(of: thread))
                .font(.system(size: 14 * zoom, weight: .semibold))
                .lineLimit(1)
            Text(thread.displayFolder)
                .font(.system(size: 12 * zoom, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .truncationMode(.head)
            if let steps = thread.textSteps {
                Text(TextZoom.level(textZoom, steps: steps), format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 11 * zoom, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55))
                    .help("This pane's text size; ⌥⌘0 puts it back in line with the others")
            }
            Spacer(minLength: 8)
            if !store.activity(for: thread.id).isAlive {
                Button("Restart", systemImage: "arrow.clockwise") {
                    sessions?.restart(thread.id)
                }
                .labelStyle(.titleAndIcon)
            }
            // Only while the pointer is over the header.
            Menu {
                splitItems
            } label: {
                Label("Split", systemImage: "rectangle.split.2x1")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Split this pane, or close it")
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
            Button(isMaximized ? "Restore" : "Maximize", systemImage: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                store.toggleMaximize(thread.id)
            }
            .help(isMaximized ? "Restore, or double-click the header" : "Maximize, or double-click the header")
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(HeaderButtonStyle(zoom: zoom))
        .foregroundStyle(Palette.text)
        .padding(.leading, 16 * zoom)
        .padding(.trailing, 12 * zoom)
        .padding(.vertical, 8 * zoom)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        // Like a Mac title bar.
        .onTapGesture(count: 2) { store.toggleMaximize(thread.id) }
        .contextMenu {
            splitItems
            Divider()
            Button(isMaximized ? "Restore" : "Maximize") { store.toggleMaximize(thread.id) }
            Menu("Text Size") {
                Button("Bigger") { store.stepTextSize(of: thread.id, by: 1, global: textZoom) }
                Button("Smaller") { store.stepTextSize(of: thread.id, by: -1, global: textZoom) }
                Button("Same as Others") { store.stepTextSize(of: thread.id, by: nil, global: textZoom) }
                    .disabled(thread.textSteps == nil)
            }
            ForEach(Editor.installed) { editor in
                Button("Open in \(editor.name)") { editor.open(thread.folder) }
            }
        }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .glassEffect(.regular, in: .rect)
    }

    @ViewBuilder
    private var splitItems: some View {
        Group {
            Button("Split Right", systemImage: "rectangle.righthalf.inset.filled") { split(.right) }
            Button("Split Left", systemImage: "rectangle.lefthalf.inset.filled") { split(.left) }
            Button("Split Down", systemImage: "rectangle.bottomhalf.inset.filled") { split(.down) }
            Button("Split Up", systemImage: "rectangle.tophalf.inset.filled") { split(.up) }
            Divider()
            Button("Close Pane", systemImage: "xmark") { store.closePane(thread.id) }
                .disabled(store.layout.panes.count < 2)
        }
        .labelStyle(.titleAndIcon)
    }

    private func split(_ side: PaneLayout.Side) {
        if !store.split(thread.id, side: side) { NSSound.beep() }
    }
}

/// Where a card dragged over a pane would land: on an edge it splits the pane there, in the middle it takes it.
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

/// Cards split or take the pane (see `DropZone`). Files and text from other apps paste into the terminal, like
/// Terminal: a file as its path, so a dropped screenshot reaches Claude Code.
private struct PaneDrop: DropDelegate {
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
        let next = isCard ? DropZone(info.location, in: size) : .center
        if zone != next { zone = next }
        return DropProposal(operation: isCard ? .move : .copy)
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
    /// Paths as Terminal pastes dropped files: shell characters escaped with a backslash, a space after each.
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

/// A bare icon or label in the pane header: no glass or bezel.
private struct HeaderButtonStyle: ButtonStyle {
    let zoom: Double

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13 * zoom, weight: .medium))
            .padding(.horizontal, 4 * zoom)
            .padding(.vertical, 2 * zoom)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.5 : 0.85)
    }
}

#Preview {
    let store = Mock.store()
    PaneView(thread: Mock.threads[1])
        .environment(store)
        .frame(width: 560, height: 360)
        .padding()
        .background(Backdrop())
}
