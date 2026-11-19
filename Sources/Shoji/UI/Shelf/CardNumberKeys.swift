import AppKit

/// ⌘ or ⌥⌘ held alone for a moment shows the card keys, so quick shortcuts never flash them.
/// A number with no card is swallowed so it can't reach the terminal.
@MainActor
enum CardNumberKeys {
    private static var monitor: Any?
    private static var pending: Task<Void, Never>?

    static func install(store: ThreadStore) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
            let keys: NumberKeys? = flags == .command ? .command : flags == [.command, .option] ? .optionCommand : nil
            let isFlags = event.type == .flagsChanged
            // Panels, sheets and alerts (Choose Folder, Rename) keep their own ⌘ digits.
            let inMainWindow = event.window?.sheetParent == nil && !(event.window is NSPanel) && NSApp.modalWindow == nil
            let number = isFlags ? nil : event.charactersIgnoringModifiers.flatMap { Int($0) }
            let swallow = MainActor.assumeIsolated {
                hide(store)
                guard let keys else { return false }
                if isFlags {
                    pending = Task {
                        guard (try? await Task.sleep(for: .milliseconds(400))) != nil else { return }
                        store.showsCardNumbers = true
                    }
                    return false
                }
                guard inMainWindow, let number, (1...9).contains(number), store.numbered(keys).count < number else { return false }
                NSSound.beep()
                return true
            }
            return swallow ? nil : event
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { hide(store) }
        }
    }

    private static func hide(_ store: ThreadStore) {
        pending?.cancel()
        if store.showsCardNumbers { store.showsCardNumbers = false }
    }
}
