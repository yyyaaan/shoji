import SwiftUI

/// The open threads' panes. A pane keeps its identity while the layout changes around it, so its terminal
/// stays hosted where it is instead of moving to a new host on every layout switch.
struct PaneGrid: View {
    @Environment(ThreadStore.self) private var store
    private let gap: CGFloat = 14

    var body: some View {
        @Bindable var store = store
        let threads = store.layout.visibleThreadIds.compactMap(store.thread)

        if threads.isEmpty {
            ContentUnavailableView("No open threads", systemImage: "rectangle.split.2x1", description: Text("Pick a card on the shelf."))
        } else {
            GeometryReader { proxy in
                let tiles = PaneTiles(count: threads.count, mode: store.layout.mode, size: proxy.size, columnSplit: store.layout.columnSplit, rowSplit: store.layout.rowSplit, gap: gap)
                ZStack(alignment: .topLeading) {
                    ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                        place(PaneView(thread: thread), in: tiles.panes[index])
                    }
                    if let rect = tiles.columnHandle {
                        place(SplitHandle(axis: .horizontal, fraction: $store.layout.columnSplit, length: proxy.size.width - gap), in: rect)
                    }
                    if let rect = tiles.rowHandle {
                        place(SplitHandle(axis: .vertical, fraction: $store.layout.rowSplit, length: proxy.size.height - gap), in: rect)
                    }
                }
            }
        }
    }

    private func place(_ view: some View, in rect: CGRect) -> some View {
        view
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

/// Where each pane goes, in `PaneLayout`'s pane order, and the gaps that work as split handles.
/// Three panes in the grid layout are two up, one down; both grid rows share the column split.
struct PaneTiles {
    var panes: [CGRect] = []
    var columnHandle: CGRect?
    var rowHandle: CGRect?

    init(count: Int, mode: PaneLayout.Mode, size: CGSize, columnSplit: Double, rowSplit: Double, gap: CGFloat) {
        let (width, height) = (size.width, size.height)
        let x = ((width - gap) * columnSplit).rounded()
        let y = ((height - gap) * rowSplit).rounded()
        func columns(_ top: CGFloat, _ bottom: CGFloat) -> [CGRect] {
            [CGRect(x: 0, y: top, width: x, height: bottom - top), CGRect(x: x + gap, y: top, width: width - x - gap, height: bottom - top)]
        }
        func rows(_ left: CGFloat, _ right: CGFloat) -> [CGRect] {
            [CGRect(x: left, y: 0, width: right - left, height: y), CGRect(x: left, y: y + gap, width: right - left, height: height - y - gap)]
        }
        func columnGap(_ top: CGFloat, _ bottom: CGFloat) -> CGRect { CGRect(x: x, y: top, width: gap, height: bottom - top) }
        func rowGap(_ left: CGFloat, _ right: CGFloat) -> CGRect { CGRect(x: left, y: y, width: right - left, height: gap) }

        switch count {
        case 0:
            break
        case 1:
            panes = [CGRect(origin: .zero, size: size)]
        case 2:
            panes = columns(0, height)
            columnHandle = columnGap(0, height)
        case 3 where mode == .threePanes:
            panes = [columns(0, height)[0]] + rows(x + gap, width)
            columnHandle = columnGap(0, height)
            rowHandle = rowGap(x + gap, width)
        case 3:
            panes = columns(0, y) + [rows(0, width)[1]]
            columnHandle = columnGap(0, y)
            rowHandle = rowGap(0, width)
        default:
            panes = columns(0, y) + columns(y + gap, height)
            columnHandle = columnGap(0, height)
            rowHandle = rowGap(0, width)
        }
    }
}

/// A gap between panes: dragging it moves the split, double-click resets it.
private struct SplitHandle: View {
    let axis: Axis
    @Binding var fraction: Double
    /// What `fraction` is a share of.
    let length: CGFloat

    @State private var dragStart: Double?
    private let range = 0.2...0.8

    var body: some View {
        Color.clear
            .contentShape(.rect)
            .pointerStyle(axis == .horizontal ? .columnResize : .rowResize)
            .gesture(
                // Global space: the handle itself moves while dragging.
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { drag in
                        let start = dragStart ?? fraction
                        dragStart = start
                        let offset = axis == .horizontal ? drag.translation.width : drag.translation.height
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
