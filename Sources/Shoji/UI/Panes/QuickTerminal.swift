import SwiftUI

/// The ⌘K quick terminal: a fresh shell in your folder, floating just under the shelf with a pane's look.
/// A click outside, ⌘K, ⌘W or `exit` closes it (`TerminalSessions.closePopup`).
struct QuickTerminal: View {
    let popup: TerminalSessions.Popup
    let close: () -> Void

    @Environment(\.zoom) private var zoom

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                // Like Spotlight: a click anywhere else closes it.
                Color.black.opacity(0.12)
                    .contentShape(.rect)
                    .onTapGesture(perform: close)
                VStack(spacing: 0) {
                    header
                    TerminalHost(terminal: popup.backend, wantsFocus: true)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Palette.terminalBackground)
                }
                .frame(width: min(max(proxy.size.width * 2 / 3, 560), proxy.size.width - 36), height: 300 * zoom)
                .clipShape(.rect(cornerRadius: 18 * zoom))
                .overlay {
                    RoundedRectangle(cornerRadius: 18 * zoom)
                        .strokeBorder(.white.opacity(0.32))
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.45), radius: 30, y: 12)
                .padding(.top, 120 * zoom + 14)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10 * zoom) {
            Image(systemName: "terminal")
                .font(.system(size: 13 * zoom, weight: .semibold))
            Text("Quick terminal")
                .font(.system(size: 14 * zoom, weight: .semibold))
            Text(popup.thread.displayFolder)
                .font(.system(size: 12 * zoom, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .truncationMode(.head)
            Spacer(minLength: 8)
            // Closing never stops a command: it moves to the shelf instead.
            Text(popup.running == nil ? "⌘K to close" : "⌘K keeps it running as a thread")
                .font(.system(size: 11 * zoom, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .foregroundStyle(Palette.text)
        .padding(.horizontal, 16 * zoom)
        .padding(.vertical, 8 * zoom)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect)
    }
}
