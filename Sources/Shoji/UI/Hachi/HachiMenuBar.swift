import SwiftUI

/// Hachi in the menu bar (`docs/design/menubar/`): alone when calm, with the count of threads that want you
/// when calling. A template image, so macOS tints it; the app's zoom doesn't apply.
struct HachiMenuBarLabel: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image("HachiMenuBar")
            if count > 0 {
                Text("\(count)").monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count == 0 ? "Shoji, no threads need you" : count == 1 ? "Shoji, 1 thread needs you" : "Shoji, \(count) threads need you")
    }
}

/// The threads that want you, then working agents; choosing one brings Shoji forward on that thread.
struct HachiMenuBarMenu: View {
    @Environment(ThreadStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let waiting = store.wantingYou
        let working = store.shelfOrder.filter { store.activity(for: $0.id).status == .working && !store.wantsYou($0.id) }
        if waiting.isEmpty && working.isEmpty {
            Text("Nothing needs you")
        }
        if !waiting.isEmpty {
            Section("Wants You") { ForEach(waiting, content: item) }
        }
        if !working.isEmpty {
            Section("Working") { ForEach(working, content: item) }
        }
        Divider()
        Button("Show Shoji") { bringForward() }
    }

    private func item(_ thread: ShojiThread) -> some View {
        let activity = store.activity(for: thread.id)
        return Button {
            bringForward()
            store.open(thread.id)
        } label: {
            Text(store.name(of: thread))
            Text([activity.status.label, activity.detail].compactMap(\.self).joined(separator: " · "))
        }
    }

    private func bringForward() {
        NSApp.activate()
        openWindow(id: "main")
    }
}
