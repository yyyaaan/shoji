import SwiftUI

/// The ⌘K quick terminal, styled like a pane; see `TerminalSessions.Popup`.
struct QuickTerminal: View {
    let popup: TerminalSessions.Popup
    let close: () -> Void

    @Environment(\.zoom) private var zoom

    var body: some View {
        GeometryReader { proxy in
            // At least 18 pt clear of the window's edges.
            let height = min(300 * zoom, proxy.size.height - 36)
            ZStack(alignment: .top) {
                // A click outside closes it.
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
                .frame(width: min(max(proxy.size.width * 2 / 3, 560), proxy.size.width - 36), height: height)
                .clipShape(.rect(cornerRadius: 18 * zoom))
                .overlay {
                    RoundedRectangle(cornerRadius: 18 * zoom)
                        .strokeBorder(.white.opacity(0.32))
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.45), radius: 30, y: 12)
                // Above centre, like Spotlight; level with the panes it read as one more pane.
                .padding(.top, max((proxy.size.height - height) * 0.4, 18))
            }
        }
    }

    /// The hint moves to a second line rather than squeezing the title when narrow.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10 * zoom) {
                title
                Spacer(minLength: 8)
                hint
            }
            VStack(alignment: .leading, spacing: 2 * zoom) {
                title
                hint
            }
        }
        .foregroundStyle(Palette.text)
        .padding(.horizontal, 16 * zoom)
        .padding(.vertical, 8 * zoom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect)
    }

    private var title: some View {
        HStack(spacing: 10 * zoom) {
            Image(systemName: "terminal")
                .font(.system(size: 13 * zoom, weight: .semibold))
            Text("Quick terminal")
                .font(.system(size: 14 * zoom, weight: .semibold))
                .fixedSize()
            // Counts as a short folder when deciding whether the hint fits beside it; truncates from there.
            Text(popup.thread.displayFolder)
                .font(.system(size: 12 * zoom, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .truncationMode(.head)
                .frame(minWidth: 0, idealWidth: 120 * zoom, alignment: .leading)
        }
    }

    private var hint: some View {
        Text(popup.running == nil ? "⌘K to close" : "⌘K keeps it running as a thread")
            .font(.system(size: 11 * zoom, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .fixedSize()
    }
}
