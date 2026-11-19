import SwiftUI

/// Cards in the user's order, with a bar between groups.
struct ShelfView: View {
    @Environment(ThreadStore.self) private var store
    @Environment(\.zoom) private var zoom
    @State private var dropSpot: DropSpot?

    var body: some View {
        let groups = store.shelf
        let numbers = store.cardNumbers
        let groupStarts = Set(groups.dropFirst().compactMap(\.first?.id))
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassEffectContainer {
                    // One flat row, bars drawn beside their card, so reordering never rebuilds a card.
                    HStack(spacing: 10 * zoom) {
                        ForEach(groups.flatMap { $0 }) { thread in
                            card(thread, numbers: numbers, barBefore: groupStarts.contains(thread.id))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10 * zoom)
                    .padding(.bottom, 6 * zoom)
                    .animation(.snappy, value: groups.map { $0.map(\.id) })
                    .animation(.easeOut(duration: 0.15), value: store.showsCardNumbers)
                }
            }
            .scrollIndicators(.automatic)
            // Keyboard jumps can land on a card that is scrolled out of view.
            .onChange(of: store.focusedThreadId) { _, id in
                guard let id else { return }
                withAnimation(.snappy) { proxy.scrollTo(id) }
            }
        }
    }

    /// A bar before the card stands 18 pt from it and from the card on its left.
    private func card(_ thread: ShojiThread, numbers: [UUID: String], barBefore: Bool) -> some View {
        // A tap gesture rather than a Button: on macOS a Button swallows the drag.
        ThreadCard(
            thread: thread,
            name: store.name(of: thread),
            activity: store.activity(for: thread.id),
            isFocused: store.focusedThreadId == thread.id,
            isOnScreen: store.layout.visiblePanes.contains(thread.id),
            wantsYou: store.wantsYou(thread.id),
            number: numbers[thread.id]
        )
        .contentShape(.rect)
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.option) { store.bringHere(thread.id) } else { store.open(thread.id) }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { store.open(thread.id) }
        .onDrag { CardDrag.item(for: thread.id) }
        .onDrop(of: [.shojiThread], delegate: CardDrop(target: thread.id, width: (thread.isMini == true ? ThreadCard.miniWidth : ThreadCard.width) * zoom, spot: $dropSpot, store: store))
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
        .contextMenu { CardMenu(thread: thread) }
        .padding(.leading, barBefore ? 26 * zoom + 1 : 0)
        .background(alignment: .leading) {
            if barBefore {
                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 1, height: 104 * zoom)
                    .offset(x: 8 * zoom)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct DropSpot: Equatable {
    var id: UUID
    var after: Bool
}

/// Dropping a card on another puts it before or after that card, by which half it lands on.
private struct CardDrop: DropDelegate {
    let target: UUID
    let width: CGFloat
    @Binding var spot: DropSpot?
    let store: ThreadStore

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.shojiThread])
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
        let target = target
        let store = store
        return CardDrag.load(info.itemProviders(for: [.shojiThread])) { id in
            withAnimation(.snappy) { store.place(id, nextTo: target, after: after) }
        }
    }
}

#Preview {
    ShelfView()
        .environment(Mock.store())
        .frame(width: 1100)
        .background(Backdrop())
}
