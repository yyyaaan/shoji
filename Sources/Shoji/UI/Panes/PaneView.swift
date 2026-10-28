import SwiftUI

struct PaneView: View {
    let thread: ShojiThread

    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @Environment(\.zoom) private var zoom

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
                .strokeBorder(.white.opacity(isFocused ? 0.32 : 0.16), lineWidth: 1)
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
            Button(isMaximized ? "Restore" : "Maximize", systemImage: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                store.toggleMaximize(thread.id)
            }
            Button("Minimize to shelf", systemImage: "minus") {
                store.minimize(thread.id)
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
