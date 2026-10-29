import SwiftUI

struct PaneView: View {
    let thread: ShojiThread

    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @Environment(\.zoom) private var zoom
    @State private var isDropTarget = false

    private var isFocused: Bool { store.focusedThreadId == thread.id }
    private var isMaximized: Bool { store.layout.maximizedThreadId == thread.id }
    private var isPinned: Bool { store.layout.pinnedThreadIds.contains(thread.id) }

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
                .fill(Palette.working.opacity(isDropTarget ? 0.08 : 0))
                .strokeBorder(isDropTarget ? Palette.working : .white.opacity(isFocused ? 0.32 : 0.16), lineWidth: isDropTarget ? 2 : 1)
                .allowsHitTesting(false)
        }
        // A card dropped here takes this pane.
        .onDrop(of: [.plainText], isTargeted: $isDropTarget) { providers in
            CardDrag.load(providers) { store.show($0, inPaneOf: thread.id) }
        }
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
            Spacer(minLength: 8)
            if !store.activity(for: thread.id).isAlive {
                Button("Restart", systemImage: "arrow.clockwise") {
                    sessions?.restart(thread.id)
                }
            }
            Button(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.fill" : "pin") {
                store.togglePin(thread.id)
            }
            .foregroundStyle(isPinned ? Palette.working : Palette.text)
            .help(isPinned ? "Pinned: opening other threads won't replace this pane" : "Pin, so opening other threads won't replace this pane")
            Button(isMaximized ? "Restore" : "Maximize", systemImage: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                store.toggleMaximize(thread.id)
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .controlSize(zoom < 0.9 ? .small : zoom > 1.3 ? .large : .regular)
        .foregroundStyle(Palette.text)
        .padding(.leading, 16 * zoom)
        .padding(.trailing, 12 * zoom)
        .padding(.vertical, 8 * zoom)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect)
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
