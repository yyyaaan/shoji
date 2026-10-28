import SwiftUI

struct PaneGrid: View {
    @Environment(ThreadStore.self) private var store

    var body: some View {
        @Bindable var store = store
        let threads = store.layout.visibleThreadIds.compactMap(store.thread)

        switch threads.count {
        case 0:
            ContentUnavailableView("No open threads", systemImage: "rectangle.split.2x1", description: Text("Pick a card on the shelf."))
        case 1, 2:
            row(threads, split: $store.layout.columnSplit)
        default:
            SplitStack(axis: .vertical, fraction: $store.layout.rowSplit) {
                row(Array(threads.prefix(2)), split: $store.layout.columnSplit)
            } second: {
                row(Array(threads.dropFirst(2)), split: $store.layout.columnSplit)
            }
        }
    }

    /// Both grid rows share one column split so the panes stay aligned.
    @ViewBuilder
    private func row(_ threads: [ShojiThread], split: Binding<Double>) -> some View {
        if let first = threads.first, let second = threads.dropFirst().first {
            SplitStack(axis: .horizontal, fraction: split) {
                PaneView(thread: first)
            } second: {
                PaneView(thread: second)
            }
        } else if let first = threads.first {
            PaneView(thread: first)
        }
    }
}

#Preview {
    PaneGrid()
        .environment(Mock.store())
        .frame(width: 1100, height: 600)
        .padding()
        .background(Backdrop())
}
