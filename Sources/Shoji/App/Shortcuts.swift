import SwiftUI

/// One app shortcut. The menu bar and the shortcuts sheet both read these, so they never disagree.
struct Shortcut: Identifiable {
    let title: String
    let key: KeyEquivalent
    var modifiers: EventModifiers = .command
    /// Shown in place of the key where that reads better ("1–9", "+").
    var keyLabel: String?
    /// Extra words for the shortcuts sheet only; menus show the title alone.
    var hint: String?

    var id: String { title }

    /// Key caps in macOS order: ⌃ ⌥ ⇧ ⌘, then the key.
    var caps: [String] {
        let symbols: [(EventModifiers, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        let key = keyLabel ?? (key == .return ? "↩" : key == .tab ? "⇥" : String(key.character).uppercased())
        return symbols.filter { modifiers.contains($0.0) }.map(\.1) + [key]
    }
}

extension Shortcut {
    static let newThread = Shortcut(title: "New Thread", key: "n")
    static let closeThread = Shortcut(title: "Close Thread", key: "w")
    static let jumpToThread = Shortcut(title: "Jump to Thread 1–9", key: "1", keyLabel: "1–9")
    static let nextNeedingYou = Shortcut(title: "Next Thread That Needs You", key: "j")
    static let quickTerminal = Shortcut(title: "Quick Terminal", key: "k", hint: "in this thread's folder")
    static let showInYourPane = Shortcut(title: "Show a Card in Your Pane", key: " ", modifiers: .option, keyLabel: "Click")
    static let recentThread = Shortcut(title: "Previous Thread", key: .tab, modifiers: .control, hint: "hold ⌃ for more")
    static let recentThreadReversed = Shortcut(title: "Recent Threads, Oldest First", key: .tab, modifiers: [.control, .shift])
    static let nextPane = Shortcut(title: "Next Pane", key: "]")
    static let previousPane = Shortcut(title: "Previous Pane", key: "[")
    static let splitRight = Shortcut(title: "Split Pane Right", key: "d")
    static let splitDown = Shortcut(title: "Split Pane Down", key: "d", modifiers: [.command, .shift])
    static let toggleMaximize = Shortcut(title: "Maximize or Restore Pane", key: .return, modifiers: [.command, .shift])
    static let singlePane = Shortcut(title: "Single Pane", key: "1", modifiers: [.command, .option])
    static let twoColumns = Shortcut(title: "Two Columns", key: "2", modifiers: [.command, .option])
    static let threePanes = Shortcut(title: "Three Panes", key: "3", modifiers: [.command, .option])
    static let grid = Shortcut(title: "Grid of Four", key: "4", modifiers: [.command, .option])
    // ⌘= so no Shift is needed; shown as + like every zoom menu.
    static let zoomIn = Shortcut(title: "Bigger Text", key: "=", keyLabel: "+")
    static let zoomOut = Shortcut(title: "Smaller Text", key: "-", keyLabel: "−")
    static let actualSize = Shortcut(title: "Actual Text Size", key: "0")
    static let paneZoomIn = Shortcut(title: "Bigger Text in Pane", key: "=", modifiers: [.command, .option], keyLabel: "+")
    static let paneZoomOut = Shortcut(title: "Smaller Text in Pane", key: "-", modifiers: [.command, .option], keyLabel: "−")
    static let paneActualSize = Shortcut(title: "Pane Text Like Others", key: "0", modifiers: [.command, .option])
    static let showShortcuts = Shortcut(title: "Keyboard Shortcuts", key: "/")

    // Handled inside the terminal; listed for reference only.
    static let newline = Shortcut(title: "New Line in an Agent Prompt", key: .return, modifiers: .shift)
    static let copy = Shortcut(title: "Copy Selection", key: "c")
    static let paste = Shortcut(title: "Paste", key: "v")
    static let openLink = Shortcut(title: "Open Link or Path", key: " ", keyLabel: "Click")
}

struct ShortcutSection: Identifiable {
    let title: String
    let symbol: String
    let shortcuts: [Shortcut]

    var id: String { title }

    static let columns: [[ShortcutSection]] = [
        [
            ShortcutSection(title: "Threads", symbol: "rectangle.stack", shortcuts: [.newThread, .jumpToThread, .showInYourPane, .recentThread, .recentThreadReversed, .nextNeedingYou, .quickTerminal, .closeThread]),
            ShortcutSection(title: "Panes", symbol: "rectangle.split.2x1", shortcuts: [.nextPane, .previousPane, .splitRight, .splitDown, .toggleMaximize]),
        ],
        [
            ShortcutSection(title: "Arrange", symbol: "square.grid.2x2", shortcuts: [.singlePane, .twoColumns, .threePanes, .grid]),
            ShortcutSection(title: "View", symbol: "textformat.size", shortcuts: [.zoomIn, .zoomOut, .actualSize, .paneZoomIn, .paneZoomOut, .paneActualSize, .showShortcuts]),
            ShortcutSection(title: "In a terminal", symbol: "terminal", shortcuts: [.newline, .copy, .paste, .openLink]),
        ],
    ]
}

extension FocusedValues {
    @Entry var showsShortcuts: Binding<Bool>?
}

struct ShojiCommands: Commands {
    let store: ThreadStore
    let sessions: TerminalSessions
    let notifier: Notifier?
    @AppStorage(TextZoom.storageKey) private var textZoom = 1.0
    @AppStorage(InterfaceSize.storageKey) private var interfaceSize = 1.0
    @FocusedBinding(\.showsShortcuts) private var showsShortcuts

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Shoji") { showAbout() }
        }

        CommandGroup(replacing: .newItem) {
            button(.newThread) { store.newThread() }
            button(.quickTerminal) { sessions.togglePopup() }
        }

        // Like closing a tab in a terminal app; confirms while the process runs. Closes the quick terminal first.
        CommandGroup(replacing: .saveItem) {
            button(.closeThread) {
                if sessions.popup != nil { sessions.closePopup() } else { store.focusedThreadId.map(store.requestClose) }
            }
            .disabled(store.focusedThreadId == nil && sessions.popup == nil)
        }

        CommandMenu("Threads") {
            ForEach(Array(store.shelfOrder.prefix(9).enumerated()), id: \.element.id) { index, thread in
                Button(store.name(of: thread)) { store.openThread(at: index) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
            Divider()
            button(.nextNeedingYou) { if !store.openNextNeedingYou() { NSSound.beep() } }
            // From the keyboard, RecentSwitchKeys takes these first so ⌃ can be held; a click switches at once.
            // RecentSwitchKeys lets ⌃Tab through while a sheet or alert is up, so never switch behind one.
            button(.recentThread) {
                guard NSApp.keyWindow?.sheetParent == nil else { return }
                store.stepRecent(by: 1)
                store.finishRecentSwitch()
            }
            button(.recentThreadReversed) {
                guard NSApp.keyWindow?.sheetParent == nil else { return }
                store.stepRecent(by: -1)
                store.finishRecentSwitch()
            }
            if !Editor.installed.isEmpty {
                Divider()
                ForEach(Editor.installed) { editor in
                    Button("Open in \(editor.name)") { store.focusedThreadId.flatMap(store.thread).map { editor.open($0.folder) } }
                        .disabled(store.focusedThreadId == nil)
                }
            }
            // Options, one click each (PLAN Decisions › Options live in the Threads menu).
            Divider()
            Toggle("Show Hachi When an Agent Finishes", isOn: Bindable(store).hachiOnFinish)
            if let notifier {
                if notifier.isDenied {
                    Button("Allow Notifications in System Settings…") {
                        let id = Bundle.main.bundleIdentifier ?? ""
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)")!)
                    }
                } else {
                    Toggle("Notify Me When Shoji Is Away", isOn: Binding { notifier.isOn } set: { notifier.setOn($0) })
                }
            }
        }

        CommandMenu("Panes") {
            button(.nextPane) { store.focusPane(offset: 1) }
            button(.previousPane) { store.focusPane(offset: -1) }
            Divider()
            Group {
                button(.splitRight) { if !store.split(side: .right) { NSSound.beep() } }
                button(.splitDown) { if !store.split(side: .down) { NSSound.beep() } }
                Button("Close Pane") { store.focusedThreadId.map(store.closePane) }
                    .disabled(store.layout.panes.count < 2)
                button(.toggleMaximize) { store.focusedThreadId.map(store.toggleMaximize) }
            }
            .disabled(store.focusedThreadId == nil)
            Divider()
            button(.singlePane) { store.arrange(.single) }
            button(.twoColumns) { store.arrange(.twoColumns) }
            button(.threePanes) { store.arrange(.threePanes) }
            button(.grid) { store.arrange(.grid) }
        }

        // How things look: sizes here, Enter Full Screen below from the system.
        CommandGroup(before: .toolbar) {
            Section("Interface Size") {
                Picker("Interface Size", selection: $interfaceSize) {
                    ForEach(InterfaceSize.allCases) { Text($0.name).tag($0.rawValue) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Divider()
            button(.zoomIn) { textZoom = TextZoom.step(textZoom, by: 1) }
            button(.zoomOut) { textZoom = TextZoom.step(textZoom, by: -1) }
            button(.actualSize) { textZoom = 1 }
            Group {
                button(.paneZoomIn) { store.focusedThreadId.map { store.stepTextSize(of: $0, by: 1, global: textZoom) } }
                button(.paneZoomOut) { store.focusedThreadId.map { store.stepTextSize(of: $0, by: -1, global: textZoom) } }
                button(.paneActualSize) { store.focusedThreadId.map { store.stepTextSize(of: $0, by: nil, global: textZoom) } }
            }
            .disabled(store.focusedThreadId == nil)
            Divider()
        }

        CommandGroup(replacing: .help) {
            button(.showShortcuts) { showsShortcuts?.toggle() }
                .disabled(showsShortcuts == nil)
        }
    }

    /// The standard About panel, credits giving the full name and the bundled open-source notices.
    private func showAbout() {
        let notices = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        let credits = NSMutableAttributedString(
            string: "Hachi no Shoji (ハチの障子)\nLicensed under the Apache License 2.0\n\n",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor, .paragraphStyle: centered]
        )
        credits.append(NSAttributedString(string: notices, attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.secondaryLabelColor]))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    private func button(_ shortcut: Shortcut, action: @escaping () -> Void) -> some View {
        Button(shortcut.title, action: action)
            .keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
    }
}
