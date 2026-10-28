import SwiftUI

struct ShelfView: View {
    @Environment(ThreadStore.self) private var store
    @Environment(\.zoom) private var zoom

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer {
                HStack(alignment: .bottom, spacing: 18 * zoom) {
                    cluster("Agents", group: .agent)
                    Rectangle()
                        .fill(.white.opacity(0.16))
                        .frame(width: 1, height: 104 * zoom)
                    cluster("Tasks", group: .task)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10 * zoom)
                .padding(.bottom, 6 * zoom)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func cluster(_ title: String, group: ShojiThread.Group) -> some View {
        VStack(alignment: .leading, spacing: 8 * zoom) {
            Text(title.uppercased())
                .font(.system(size: 11 * zoom, weight: .bold))
                .tracking(1.2 * zoom)
                .foregroundStyle(.white.opacity(0.72))
                .padding(.leading, 4)
            HStack(spacing: 10 * zoom) {
                ForEach(store.threads(in: group)) { thread in
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
                }
            }
        }
    }
}

#Preview {
    ShelfView()
        .environment(Mock.store())
        .background(Backdrop())
}
