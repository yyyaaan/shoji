import SwiftUI

/// The open threads' panes. A pane keeps its identity while the layout changes around it, so its terminal
/// stays hosted where it is instead of moving to a new host on every layout switch.
struct PaneGrid: View {
    @Environment(ThreadStore.self) private var store

    var body: some View {
        let threads = store.layout.visibleThreadIds.compactMap(store.thread)

        if threads.isEmpty {
            ContentUnavailableView("No open threads", systemImage: "rectangle.split.2x1", description: Text("Pick a card on the shelf."))
        } else {
            GeometryReader { proxy in
                let area = CGRect(origin: .zero, size: proxy.size)
                let tiles = PaneTiles(store.layout.maximizedThreadId.map { .pane(id: $0) } ?? store.layout.root, in: area)
                ZStack(alignment: .topLeading) {
                    ForEach(threads) { thread in
                        if let rect = tiles.panes[thread.id] {
                            place(PaneView(thread: thread), in: rect)
                        }
                    }
                    ForEach(tiles.handles) { handle in
                        place(SplitHandle(axis: handle.axis, fraction: ratio(at: handle.path), length: handle.length), in: handle.rect)
                    }
                }
                .onChange(of: proxy.size, initial: true) { _, size in store.paneAreaSize = size }
            }
        }
    }

    private func ratio(at path: [Int]) -> Binding<Double> {
        Binding {
            store.layout.root?.ratio(at: path) ?? 0.5
        } set: {
            store.layout.setRatio($0, at: path)
        }
    }

    private func place(_ view: some View, in rect: CGRect) -> some View {
        view
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

/// A gap between panes: dragging it moves the split, double-click evens it.
private struct SplitHandle: View {
    let axis: PaneNode.Axis
    @Binding var fraction: Double
    /// What `fraction` is a share of.
    let length: CGFloat

    @State private var dragStart: Double?
    private let range = 0.2...0.8

    var body: some View {
        Color.clear
            .contentShape(.rect)
            .pointerStyle(axis == .columns ? .columnResize : .rowResize)
            .gesture(
                // Global space: the handle itself moves while dragging.
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { drag in
                        let start = dragStart ?? fraction
                        dragStart = start
                        let offset = axis == .columns ? drag.translation.width : drag.translation.height
                        fraction = min(max(start + offset / max(length, 1), range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .onTapGesture(count: 2) { fraction = 0.5 }
    }
}

#Preview {
    PaneGrid()
        .environment(Mock.store())
        .frame(width: 1100, height: 600)
        .padding()
        .background(Backdrop())
}
