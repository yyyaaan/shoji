import SwiftUI

struct PaneView: View {
    let thread: ShojiThread

    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @Environment(\.zoom) private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(TextZoom.storageKey) private var textZoom = 1.0
    @State private var dropZone: DropZone?
    /// Go-to glow, 0…1.
    @State private var glow = 0.0
    @State private var size = CGSize.zero
    @State private var isHovering = false
    @FocusState private var focusedControl: HeaderControl?

    private enum HeaderControl {
        case threads, split, maximize
    }

    private var isFocused: Bool { store.focusedThreadId == thread.id }
    private var isMaximized: Bool { store.layout.maximizedPaneId == thread.id }
    private var opacity: Double { reduceTransparency ? 1 : Palette.paneOpacity }
    /// On hover, or while one has keyboard focus (Full Keyboard Access).
    private var showsControls: Bool { isHovering || focusedControl != nil }
    private static let margin = CGSize(width: 10, height: 8)

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if let terminal = sessions?.terminal(for: thread.id) {
                    TerminalHost(terminal: terminal, wantsFocus: store.focusRequest == thread.id, backgroundOpacity: opacity)
                } else {
                    Palette.terminalBackground.opacity(opacity)
                }
            }
            .padding(.horizontal, Self.margin.width)
            .padding(.vertical, Self.margin.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Only around the terminal, which draws its own background: two translucent layers would stack.
            .background(Palette.terminalBackground.opacity(opacity), in: Margin(inset: Self.margin), fillStyle: FillStyle(eoFill: true))
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
        // Go-to glow (`ThreadStore.paneGlow`).
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
            if store.isCompact {
                // No shelf here, so the name itself is the dropdown.
                Menu {
                    threadItems
                } label: {
                    HStack(spacing: 4 * zoom) {
                        name
                        chevron
                    }
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .layoutPriority(1)
                .help("Show another thread here")
            } else {
                HStack(spacing: 4 * zoom) {
                    name
                    // Apart from the name, which still maximizes on a double-click.
                    Menu {
                        threadItems
                    } label: {
                        Label { Text("Show Thread") } icon: { chevron }
                    }
                    .menuStyle(.button)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Show another thread here")
                    .focused($focusedControl, equals: .threads)
                    .opacity(showsControls ? 1 : 0)
                    .allowsHitTesting(showsControls)
                }
                // The name before the folder when the pane is narrow.
                .layoutPriority(1)
            }
            Text(thread.displayFolder)
                .font(.system(size: 12 * zoom, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .truncationMode(.head)
            Spacer(minLength: 8)
            if !store.activity(for: thread.id).isAlive {
                Button("Restart", systemImage: "arrow.clockwise") {
                    sessions?.restart(thread.id)
                }
                .labelStyle(.titleAndIcon)
                .fixedSize()
            }
            Menu {
                splitItems
            } label: {
                Label("Split", systemImage: store.isCompact ? "rectangle.split.1x2" : "rectangle.split.2x1")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Split this pane, or close it")
            .focused($focusedControl, equals: .split)
            .opacity(showsControls ? 1 : 0)
            .allowsHitTesting(showsControls)
            Button(isMaximized ? "Restore" : "Maximize", systemImage: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                store.toggleMaximize(thread.id)
            }
            .help(isMaximized ? "Restore, or double-click the header" : "Maximize, or double-click the header")
            .fixedSize()
            .focused($focusedControl, equals: .maximize)
            .opacity(showsControls ? 1 : 0)
            .allowsHitTesting(showsControls)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(BareButtonStyle(zoom: zoom))
        .foregroundStyle(Palette.text)
        .padding(.leading, 16 * zoom)
        .padding(.trailing, 12 * zoom)
        .padding(.vertical, 6 * zoom)
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
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showsControls)
        .glassEffect(.regular, in: .rect)
    }

    private var name: some View {
        Text(store.name(of: thread))
            .font(.system(size: 14 * zoom, weight: .semibold))
            .lineLimit(1)
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 10 * zoom, weight: .bold))
    }

    /// Picking one is like a drop on this pane.
    @ViewBuilder
    private var threadItems: some View {
        Picker("Thread", selection: Binding { thread.id } set: { store.show($0, inPaneOf: thread.id) }) {
            ForEach(Array(store.shelf.enumerated()), id: \.offset) { index, group in
                if index > 0 { Divider() }
                ForEach(group) { item in
                    let status = store.activity(for: item.id).status
                    Label(status == .idle ? store.name(of: item) : "\(store.name(of: item)) — \(status.label)", systemImage: status.symbol)
                        .tag(item.id)
                }
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
        Divider()
        Button("New Thread", systemImage: "plus") { store.newThread(inPaneOf: thread.id) }
    }

    @ViewBuilder
    private var splitItems: some View {
        Group {
            if !store.isCompact {
                Button("Split Right", systemImage: "rectangle.righthalf.inset.filled") { split(.right) }
                Button("Split Left", systemImage: "rectangle.lefthalf.inset.filled") { split(.left) }
            }
            Group {
                Button("Split Down", systemImage: "rectangle.bottomhalf.inset.filled") { split(.down) }
                Button("Split Up", systemImage: "rectangle.tophalf.inset.filled") { split(.up) }
            }
            .disabled(store.isCompact && store.layout.panes.count > 1)
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

/// The frame around a terminal, filled even-odd so the middle stays empty.
private struct Margin: Shape {
    let inset: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRect(rect.insetBy(dx: inset.width, dy: inset.height))
        return path
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
