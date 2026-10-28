import SwiftUI

/// One app shortcut. The menu bar and the shortcuts sheet both read these, so they never disagree.
struct Shortcut: Identifiable {
    let title: String
    let key: KeyEquivalent
    var modifiers: EventModifiers = .command
    /// Shown in place of the key where that reads better ("1–9", "+").
    var keyLabel: String?

    var id: String { title }

    /// Key caps in macOS order: ⌃ ⌥ ⇧ ⌘, then the key.
    var caps: [String] {
        let symbols: [(EventModifiers, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        let key = keyLabel ?? (key == .return ? "↩" : String(key.character).uppercased())
        return symbols.filter { modifiers.contains($0.0) }.map(\.1) + [key]
    }
}

extension Shortcut {
    static let newThread = Shortcut(title: "New thread", key: "n")
    static let closeThread = Shortcut(title: "Close thread", key: "w")
    static let jumpToThread = Shortcut(title: "Jump to thread 1–9", key: "1", keyLabel: "1–9")
    static let nextNeedingYou = Shortcut(title: "Next thread that needs you", key: "j")
    static let nextPane = Shortcut(title: "Next pane", key: "]")
    static let previousPane = Shortcut(title: "Previous pane", key: "[")
    static let toggleMaximize = Shortcut(title: "Maximize or restore pane", key: .return, modifiers: [.command, .shift])
    static let minimizePane = Shortcut(title: "Minimize pane to shelf", key: "m", modifiers: [.command, .shift])
    static let singlePane = Shortcut(title: "Single pane", key: "1", modifiers: [.command, .option])
    static let twoColumns = Shortcut(title: "Two columns", key: "2", modifiers: [.command, .option])
    static let grid = Shortcut(title: "Grid of four", key: "3", modifiers: [.command, .option])
    // ⌘= so no Shift is needed; shown as + like every zoom menu.
    static let zoomIn = Shortcut(title: "Zoom in", key: "=", keyLabel: "+")
    static let zoomOut = Shortcut(title: "Zoom out", key: "-", keyLabel: "−")
    static let actualSize = Shortcut(title: "Actual size", key: "0")
    static let showShortcuts = Shortcut(title: "Keyboard shortcuts", key: "/")

    // Handled inside the terminal; listed for reference only.
    static let newline = Shortcut(title: "New line in an agent prompt", key: .return, modifiers: .shift)
    static let copy = Shortcut(title: "Copy selection", key: "c")
    static let paste = Shortcut(title: "Paste", key: "v")
    static let openLink = Shortcut(title: "Open link or path", key: " ", keyLabel: "Click")
}

struct ShortcutSection: Identifiable {
    let title: String
    let symbol: String
    let shortcuts: [Shortcut]

    var id: String { title }

    static let columns: [[ShortcutSection]] = [
        [
            ShortcutSection(title: "Threads", symbol: "rectangle.stack", shortcuts: [.newThread, .jumpToThread, .nextNeedingYou, .closeThread]),
            ShortcutSection(title: "Panes", symbol: "rectangle.split.2x1", shortcuts: [.nextPane, .previousPane, .toggleMaximize, .minimizePane]),
            ShortcutSection(title: "Layout", symbol: "square.grid.2x2", shortcuts: [.singlePane, .twoColumns, .grid]),
        ],
        [
            ShortcutSection(title: "View", symbol: "textformat.size", shortcuts: [.zoomIn, .zoomOut, .actualSize, .showShortcuts]),
            ShortcutSection(title: "In a terminal", symbol: "terminal", shortcuts: [.newline, .copy, .paste, .openLink]),
        ],
    ]
}

extension FocusedValues {
    @Entry var showsShortcuts: Binding<Bool>?
}

struct ShojiCommands: Commands {
    let store: ThreadStore
    @AppStorage(Zoom.storageKey) private var zoom = 1.0
    @FocusedBinding(\.showsShortcuts) private var showsShortcuts

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            button(.newThread) { store.newThread() }
        }

        // Like closing a tab in a terminal app; confirms while the process runs.
        CommandGroup(replacing: .saveItem) {
            button(.closeThread) { store.focusedThreadId.map(store.requestClose) }
                .disabled(store.focusedThreadId == nil)
        }

        CommandMenu("Threads") {
            ForEach(Array(store.shelfOrder.prefix(9).enumerated()), id: \.element.id) { index, thread in
                Button(thread.displayTitle) { store.openThread(at: index) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
            Divider()
            button(.nextNeedingYou) { if !store.openNextNeedingYou() { NSSound.beep() } }
            Divider()
            button(.nextPane) { store.focusPane(offset: 1) }
            button(.previousPane) { store.focusPane(offset: -1) }
            Group {
                button(.toggleMaximize) { store.focusedThreadId.map(store.toggleMaximize) }
                button(.minimizePane) { store.focusedThreadId.map(store.minimize) }
            }
            .disabled(store.focusedThreadId == nil)
        }

        CommandGroup(before: .toolbar) {
            button(.singlePane) { store.layout.mode = .single }
            button(.twoColumns) { store.layout.mode = .twoColumns }
            button(.grid) { store.layout.mode = .grid }
            Divider()
            button(.zoomIn) { zoom = Zoom.step(zoom, by: 1) }
            button(.zoomOut) { zoom = Zoom.step(zoom, by: -1) }
            button(.actualSize) { zoom = 1 }
            Divider()
        }

        CommandGroup(replacing: .help) {
            button(.showShortcuts) { showsShortcuts?.toggle() }
                .disabled(showsShortcuts == nil)
        }
    }

    private func button(_ shortcut: Shortcut, action: @escaping () -> Void) -> some View {
        Button(shortcut.title, action: action)
            .keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
    }
}
