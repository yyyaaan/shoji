import SwiftUI
import UniformTypeIdentifiers

/// Cards in the user's order, with a bar between groups. Groups mean whatever the user wants; cards
/// are dragged into place, and the context menu adds or removes bars. Scrolls sideways when the cards overflow.
struct ShelfView: View {
    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @Environment(\.zoom) private var zoom
    @State private var renaming: ShojiThread?
    @State private var draftTitle = ""
    @State private var dropSpot: DropSpot?

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
                TextField("Name", text: $draftTitle, prompt: Text(thread.folderName))
                Button("Rename") { store.rename(thread.id, to: draftTitle) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Leave it empty to show the folder’s name.")
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
                // A tap gesture rather than a Button: on macOS a Button swallows the drag.
                ThreadCard(
                    thread: thread,
                    name: store.name(of: thread),
                    activity: store.activity(for: thread.id),
                    isFocused: store.focusedThreadId == thread.id
                )
                .contentShape(.rect)
                .onTapGesture { store.open(thread.id) }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { store.open(thread.id) }
                .onDrag { NSItemProvider(object: CardDrop.payload(for: thread.id) as NSString) }
                .onDrop(of: [.plainText], delegate: CardDrop(target: thread.id, width: ThreadCard.width * zoom, spot: $dropSpot, store: store))
                .overlay(alignment: dropSpot?.after == true ? .trailing : .leading) {
                    if dropSpot?.id == thread.id {
                        // Sits in the gap beside the card, outside its glass.
                        Capsule()
                            .fill(Palette.working)
                            .frame(width: 3, height: 80 * zoom)
                            .offset(x: (dropSpot?.after == true ? 6.5 : -6.5) * zoom)
                            .allowsHitTesting(false)
                    }
                }
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

private struct DropSpot: Equatable {
    var id: UUID
    var after: Bool
}

/// Dropping a card on another puts it before or after that card, by which half it lands on.
/// Only Shoji's own payload counts, so text dragged in from elsewhere is ignored.
private struct CardDrop: DropDelegate {
    let target: UUID
    let width: CGFloat
    @Binding var spot: DropSpot?
    let store: ThreadStore

    private nonisolated static let prefix = "shoji-thread:"

    static func payload(for id: UUID) -> String {
        prefix + id.uuidString
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.plainText])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let next = DropSpot(id: target, after: info.location.x > width / 2)
        if spot != next { spot = next }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if spot?.id == target { spot = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        let after = info.location.x > width / 2
        spot = nil
        guard let provider = info.itemProviders(for: [.plainText]).first else { return false }
        let target = target
        let store = store
        _ = provider.loadObject(ofClass: String.self) { text, _ in
            guard let text, text.hasPrefix(Self.prefix), let id = UUID(uuidString: String(text.dropFirst(Self.prefix.count))) else { return }
            Task { @MainActor in
                withAnimation(.snappy) { store.place(id, nextTo: target, after: after) }
            }
        }
        return true
    }
}

#Preview {
    ShelfView()
        .environment(Mock.store())
        .frame(width: 1100)
        .background(Backdrop())
}
