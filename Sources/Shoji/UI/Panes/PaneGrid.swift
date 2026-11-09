import SwiftUI

/// One `PaneView` per thread (or `EmptyPane`), placed by frame so a layout change never re-hosts a terminal.
struct PaneGrid: View {
    @Environment(ThreadStore.self) private var store

    var body: some View {
        GeometryReader { proxy in
            let area = CGRect(origin: .zero, size: proxy.size)
            let tiles = PaneTiles(store.layout.maximizedPaneId.map { .pane(id: $0) } ?? store.layout.root, in: area)
            ZStack(alignment: .topLeading) {
                ForEach(store.layout.visiblePanes, id: \.self) { id in
                    if let rect = tiles.panes[id] {
                        if let thread = store.thread(id) {
                            place(PaneView(thread: thread), in: rect)
                        } else {
                            place(EmptyPane(id: id), in: rect)
                        }
                    }
                }
                ForEach(tiles.handles) { handle in
                    place(SplitHandle(axis: handle.axis, fraction: ratio(at: handle.path), length: handle.length), in: handle.rect)
                }
            }
            .onChange(of: proxy.size, initial: true) { _, size in store.paneAreaSize = size }
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
