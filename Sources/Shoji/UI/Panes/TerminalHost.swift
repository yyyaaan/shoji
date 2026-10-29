import AppKit
import SwiftUI

/// Shows a terminal that `TerminalSessions` owns. The view is re-parented, never recreated,
/// so processes and scrollback survive layout changes.
struct TerminalHost: NSViewRepresentable {
    let terminal: any TerminalBackend
    var wantsFocus = false
    var backgroundOpacity = 1.0

    final class Coordinator {
        var wantedFocus = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> TerminalContainer {
        TerminalContainer()
    }

    func updateNSView(_ container: TerminalContainer, context: Context) {
        terminal.setBackgroundOpacity(backgroundOpacity)
        container.host(terminal.view)
        // Only when a request arrives: a pending one must not pull focus back after the user clicked another pane.
        if wantsFocus, !context.coordinator.wantedFocus {
            Task { terminal.focus() }
        }
        context.coordinator.wantedFocus = wantsFocus
    }
}

final class TerminalContainer: NSView {
    func host(_ view: NSView) {
        guard view.superview !== self else { return }
        subviews.forEach { $0.removeFromSuperview() }
        addSubview(view)
        needsLayout = true
    }

    // A zero-sized frame would resize the PTY to nothing and garble TUIs; keep the last real size.
    override func layout() {
        super.layout()
        guard bounds.width >= 1, bounds.height >= 1 else { return }
        subviews.first?.frame = bounds
    }
}
