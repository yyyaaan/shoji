import SwiftUI

/// Cards in the user's order, with a bar between groups. Groups mean whatever the user wants;
/// the context menu moves cards and adds or removes bars. Scrolls sideways when the cards overflow.
struct ShelfView: View {
    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @Environment(\.zoom) private var zoom
    @State private var renaming: ShojiThread?
    @State private var draftTitle = ""

    var body: some View {
        let groups = store.shelf
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassEffectContainer {
                    HStack(spacing: 18 * zoom) {
                        ForEach(Array(groups.enumerated()), id: \.element.first?.id) { index, threads in
                            if index > 0 {
                                Rectangle()
                                    .fill(.white.opacity(0.16))
                                    .frame(width: 1, height: 104 * zoom)
                                    .accessibilityHidden(true)
                            }
                            group(threads)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10 * zoom)
                    .padding(.bottom, 6 * zoom)
                    .animation(.snappy, value: groups.map { $0.map(\.id) })
                }
            }
            .scrollIndicators(.automatic)
            .alert("Rename Thread", isPresented: Binding { renaming != nil } set: { if !$0 { renaming = nil } }, presenting: renaming) { thread in
                TextField("Name", text: $draftTitle, prompt: Text(thread.displayFolder))
                Button("Rename") { store.rename(thread.id, to: draftTitle) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Leave it empty to show the folder's name.")
            }
            // Keyboard jumps can land on a card that is scrolled out of view.
            .onChange(of: store.focusedThreadId) { _, id in
                guard let id else { return }
                withAnimation(.snappy) { proxy.scrollTo(id) }
            }
        }
    }

    private func group(_ threads: [ShojiThread]) -> some View {
        HStack(spacing: 10 * zoom) {
            ForEach(threads) { thread in
                Button {
                    store.open(thread.id)
                } label: {
                    ThreadCard(
                        thread: thread,
                        activity: store.activity(for: thread.id),
                        isFocused: store.focusedThreadId == thread.id
                    )
                }
                .buttonStyle(.plain)
                .id(thread.id)
                .contextMenu { menu(for: thread) }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func menu(for thread: ShojiThread) -> some View {
        Button("Rename…") {
            draftTitle = thread.title ?? ""
            renaming = thread
        }
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
        Divider()
        if !store.activity(for: thread.id).isAlive {
            Button("Restart") { sessions?.restart(thread.id) }
        }
        Button("Close Thread", role: .destructive) { store.requestClose(thread.id) }
    }
}

#Preview {
    ShelfView()
        .environment(Mock.store())
        .frame(width: 1100)
        .background(Backdrop())
}
