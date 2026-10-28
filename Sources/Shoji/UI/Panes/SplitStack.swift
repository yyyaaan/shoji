import SwiftUI

/// Two panes split along `axis`. The gap between them is the drag handle; double-click resets it.
struct SplitStack<First: View, Second: View>: View {
    let axis: Axis
    @Binding var fraction: Double
    var gap: CGFloat = 14
    @ViewBuilder var first: First
    @ViewBuilder var second: Second

    @State private var dragStart: Double?
    private let range = 0.2...0.8

    var body: some View {
        GeometryReader { proxy in
            let length = (axis == .horizontal ? proxy.size.width : proxy.size.height) - gap
            let stack = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
            stack {
                first
                    .frame(
                        width: axis == .horizontal ? length * fraction : nil,
                        height: axis == .vertical ? length * fraction : nil
                    )
                handle(length: length)
                second
            }
        }
    }

    private func handle(length: CGFloat) -> some View {
        Color.clear
            .frame(width: axis == .horizontal ? gap : nil, height: axis == .vertical ? gap : nil)
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
