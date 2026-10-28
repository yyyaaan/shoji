import SwiftUI

struct ShelfView: View {
    @Environment(ThreadStore.self) private var store

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer {
                HStack(alignment: .bottom, spacing: 18) {
                    cluster("Agents", group: .agent)
                    Rectangle()
                        .fill(.white.opacity(0.16))
                        .frame(width: 1, height: 104)
                    cluster("Tasks", group: .task)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 6)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func cluster(_ title: String, group: ShojiThread.Group) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.72))
                .padding(.leading, 4)
            HStack(spacing: 10) {
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
