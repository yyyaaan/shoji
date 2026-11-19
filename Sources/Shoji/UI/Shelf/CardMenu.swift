import SwiftUI

/// A card's right-click menu, on the shelf and in the Hub.
struct CardMenu: View {
    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    let thread: ShojiThread

    var body: some View {
        Button("Show in This Pane") { store.bringHere(thread.id) }
            .disabled(store.focusedPaneId == nil || store.focusedPaneId == thread.id)
        ForEach(Editor.installed) { editor in
            Button("Open in \(editor.name)") { editor.open(thread.folder) }
        }
        Button("Rename…") { store.renameRequest = thread.id }
        Divider()
        Button("Move Left") { store.move(thread.id, by: -1) }
            .disabled(!store.canMove(thread.id, by: -1))
        Button("Move Right") { store.move(thread.id, by: 1) }
            .disabled(!store.canMove(thread.id, by: 1))
        if store.hasBarBefore(thread.id) {
            Button("Remove Bar Before") { store.toggleBarBefore(thread.id) }
        } else if store.shelfOrder.first?.id != thread.id {
            Button("Add Bar Before") { store.toggleBarBefore(thread.id) }
        }
        if !store.showsHub {
            Toggle("Mini Card", isOn: Binding { thread.isMini == true } set: { _ in withAnimation(.snappy) { store.toggleMini(thread.id) } })
        }
        ForEach(CardMark.allCases, id: \.self) { mark in
            Toggle(isOn: Binding { thread.mark == mark } set: { store.setMark(thread.id, to: $0 ? mark : nil) }) {
                Label(mark.title, systemImage: mark.symbol)
            }
        }
        Divider()
        if !store.activity(for: thread.id).isAlive {
            Button("Restart") { sessions?.restart(thread.id) }
        }
        Button("Close Thread", role: .destructive) { store.requestClose(thread.id) }
    }
}
