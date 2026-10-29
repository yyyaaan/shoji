import SwiftUI

/// The window's top-left corner, under the close, minimize and zoom buttons. Empty until a thread needs you;
/// then Hachi peeks out with the count, and a click opens the next one (⌘J).
struct HachiCorner: View {
    @Environment(ThreadStore.self) private var store
    @Environment(\.zoom) private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let waiting = store.threads.count { store.wantsYou($0.id) }
        // The column is 78 pt wide whatever the zoom.
        let size = min(36 * zoom, 58)
        ZStack {
            if waiting > 0 {
                Button {
                    store.openNextNeedingYou()
                } label: {
                    HachiPortrait(size: size)
                        .overlay(alignment: .topTrailing) { badge(waiting) }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(waiting == 1 ? "A thread needs you (⌘J)" : "\(waiting) threads need you (⌘J)")
                .accessibilityLabel(waiting == 1 ? "A thread needs you" : "\(waiting) threads need you")
                .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .bottom)))
            }
        }
        // Only on appearing and leaving, never on count changes (Hachi spec).
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: waiting > 0)
    }

    private func badge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 11 * zoom, weight: .bold))
            .foregroundStyle(Color(hex: 0x1A1206))
            .padding(.horizontal, 5 * zoom)
            .frame(minWidth: 18 * zoom, minHeight: 18 * zoom)
            .background(Palette.needsYou, in: .capsule)
            .offset(x: 12 * zoom, y: -6 * zoom)
    }
}

#Preview {
    let quiet = ThreadStore(threads: [ShojiThread()])
    HStack(spacing: 40) {
        HachiCorner().environment(quiet)
        HachiCorner().environment(Mock.store())
    }
    .padding(40)
    .background(Backdrop())
}
