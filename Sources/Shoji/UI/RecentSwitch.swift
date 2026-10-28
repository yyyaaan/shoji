import AppKit
import Carbon.HIToolbox
import SwiftUI

/// ⌃Tab works like ⌘Tab, for threads: hold ⌃ and press Tab to step through the threads you used last,
/// release ⌃ to open the one picked; Esc cancels. An event monitor, so these keys never reach the terminal.
@MainActor
enum RecentSwitchKeys {
    private static var monitor: Any?

    static func install(store: ThreadStore) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            MainActor.assumeIsolated { handle(event, store: store) } ? nil : event
        }
    }

    /// True when the event was used up.
    private static func handle(_ event: NSEvent, store: ThreadStore) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
        if event.type == .flagsChanged {
            if !flags.contains(.control) { store.finishRecentSwitch() }
            return false
        }
        // Not while a sheet or alert is up.
        guard event.window?.sheetParent == nil else { return false }
        if event.keyCode == UInt16(kVK_Tab), flags.subtracting(.shift) == .control {
            store.stepRecent(by: flags.contains(.shift) ? -1 : 1)
            return true
        }
        guard store.recentSwitch != nil else { return false }
        switch Int(event.keyCode) {
        case kVK_Escape:
            store.cancelRecentSwitch()
            return true
        case kVK_Return:
            store.finishRecentSwitch()
            return true
        default:
            store.cancelRecentSwitch()
            return false
        }
    }
}

/// The threads ⌃Tab steps through, shown while ⌃ is held.
struct RecentSwitchPanel: View {
    let recentSwitch: ThreadStore.RecentSwitch

    @Environment(ThreadStore.self) private var store
    @Environment(\.zoom) private var zoom

    var body: some View {
        // Scrolls only when the list doesn't fit.
        ViewThatFits(in: .vertical) {
            list
            ScrollViewReader { proxy in
                ScrollView { list }
                    .scrollIndicators(.never)
                    .onChange(of: recentSwitch.selected, initial: true) { _, id in proxy.scrollTo(id) }
            }
        }
        .frame(width: 380 * zoom)
        .frame(maxHeight: 460 * zoom)
        .glassEffect(.regular, in: .rect(cornerRadius: 20 * zoom))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recent threads")
    }

    private var list: some View {
        VStack(spacing: 2 * zoom) {
            ForEach(recentSwitch.threadIds.compactMap(store.thread)) { thread in
                row(thread, isSelected: thread.id == recentSwitch.selected)
                    .id(thread.id)
            }
        }
        .padding(8 * zoom)
    }

    private func row(_ thread: ShojiThread, isSelected: Bool) -> some View {
        HStack(spacing: 10 * zoom) {
            StatusIcon(status: store.activity(for: thread.id).status, size: 18 * zoom)
            Text(store.name(of: thread))
                .font(.system(size: 14 * zoom, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 8 * zoom)
            Text(thread.displayFolder)
                .font(.system(size: 12 * zoom, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.head)
        }
        .foregroundStyle(Palette.text)
        .padding(.horizontal, 12 * zoom)
        .padding(.vertical, 8 * zoom)
        .background(.white.opacity(isSelected ? 0.16 : 0), in: .rect(cornerRadius: 12 * zoom))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    let store = Mock.store()
    RecentSwitchPanel(recentSwitch: ThreadStore.RecentSwitch(threadIds: store.shelfOrder.map(\.id), index: 1))
        .environment(store)
        .padding(40)
        .background(Backdrop())
}
