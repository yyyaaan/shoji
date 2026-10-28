import SwiftUI

/// Agent cards, a divider, then task cards. Scrolls sideways when the cards overflow.
struct ShelfView: View {
    @Environment(ThreadStore.self) private var store
    @Environment(\.zoom) private var zoom

    var body: some View {
        let agents = store.threads(in: .agent)
        let tasks = store.threads(in: .task)
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassEffectContainer {
                    HStack(spacing: 18 * zoom) {
                        group("Agents", agents)
                        if !agents.isEmpty, !tasks.isEmpty {
                            Rectangle()
                                .fill(.white.opacity(0.16))
                                .frame(width: 1, height: 104 * zoom)
                        }
                        group("Tasks", tasks)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10 * zoom)
                    .padding(.bottom, 6 * zoom)
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

    private func group(_ title: String, _ threads: [ShojiThread]) -> some View {
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
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

#Preview {
    ShelfView()
        .environment(Mock.store())
        .frame(width: 900)
        .background(Backdrop())
}
