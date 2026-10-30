import SwiftUI
import UniformTypeIdentifiers

/// Cards in the user's order, with a bar between groups. Groups mean whatever the user wants; cards
/// are dragged into place, and the context menu adds or removes bars. Scrolls sideways when the cards overflow.
struct ShelfView: View {
    @Environment(ThreadStore.self) private var store
    @Environment(\.zoom) private var zoom
    @State private var dropSpot: DropSpot?

    var body: some View {
        let groups = store.shelf
        let numbers = store.showsCardNumbers ? Dictionary(uniqueKeysWithValues: store.shelfOrder.prefix(9).enumerated().map { ($1.id, $0 + 1) }) : [:]
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
                            group(threads, numbers: numbers)
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

    private func group(_ threads: [ShojiThread], numbers: [UUID: Int]) -> some View {
        HStack(spacing: 10 * zoom) {
            ForEach(threads) { thread in
                // A tap gesture rather than a Button: on macOS a Button swallows the drag.
                ThreadCard(
                    thread: thread,
                    name: store.name(of: thread),
                    activity: store.activity(for: thread.id),
                    isFocused: store.focusedThreadId == thread.id,
                    isOnScreen: store.layout.visibleThreadIds.contains(thread.id),
                    wantsYou: store.wantsYou(thread.id),
                    number: numbers[thread.id]
                )
                .contentShape(.rect)
                // A click goes to the thread; ⌥-click brings it to the pane you're in.
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
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// A card's right-click menu, on the shelf and in the Hub.
struct CardMenu: View {
    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    let thread: ShojiThread

    var body: some View {
        Button("Show in This Pane") { store.bringHere(thread.id) }
            .disabled(store.focusedThreadId == nil || store.focusedThreadId == thread.id)
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
        Divider()
        if !store.activity(for: thread.id).isAlive {
            Button("Restart") { sessions?.restart(thread.id) }
        }
        Button("Close Thread", role: .destructive) { store.requestClose(thread.id) }
    }
}

/// Holding ⌘ alone for a moment numbers the cards for ⌘1–9; any key, another modifier or leaving Shoji hides them,
/// so quick shortcuts never flash them.
@MainActor
enum CardNumberKeys {
    private static var monitor: Any?
    private static var pending: Task<Void, Never>?

    static func install(store: ThreadStore) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            MainActor.assumeIsolated {
                hide(store)
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
                if event.type == .flagsChanged, flags == .command {
                    pending = Task {
                        guard (try? await Task.sleep(for: .milliseconds(400))) != nil else { return }
                        store.showsCardNumbers = true
                    }
                }
            }
            return event
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

private struct DropSpot: Equatable {
    var id: UUID
    var after: Bool
}

/// A card being dragged, as Shoji's own text payload, so text dragged in from elsewhere is ignored.
extension UTType {
    /// Declared in Info.plist; never offered to other apps.
    static let shojiThread = UTType(exportedAs: "fi.yan.shoji.thread")
}

enum CardDrag {
    static func item(for id: UUID) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.shojiThread.identifier, visibility: .ownProcess) { completion in
            completion(Data(id.uuidString.utf8), nil)
            return nil
        }
        return provider
    }

    /// Reads the dragged card's thread and hands it over on the main actor. False when nothing could be read.
    static func load(_ providers: [NSItemProvider], then action: @escaping @MainActor (UUID) -> Void) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.shojiThread.identifier) { data, _ in
            guard let data, let id = UUID(uuidString: String(decoding: data, as: UTF8.self)) else { return }
            Task { @MainActor in action(id) }
        }
        return true
    }
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
