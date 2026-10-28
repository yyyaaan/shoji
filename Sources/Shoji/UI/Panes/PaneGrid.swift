import SwiftUI

struct PaneGrid: View {
    @Environment(ThreadStore.self) private var store

    var body: some View {
        let threads = store.layout.visibleThreadIds.compactMap(store.thread)
        let columns = threads.count == 1 ? 1 : 2
        let rows = stride(from: 0, to: threads.count, by: columns).map { Array(threads[$0..<min($0 + columns, threads.count)]) }

        if threads.isEmpty {
            ContentUnavailableView("No open threads", systemImage: "rectangle.split.2x1", description: Text("Pick a card on the shelf."))
        } else {
            VStack(spacing: 14) {
                ForEach(rows, id: \.first?.id) { row in
                    HStack(spacing: 14) {
                        ForEach(row) { PaneView(thread: $0) }
                    }
                }
            }
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
