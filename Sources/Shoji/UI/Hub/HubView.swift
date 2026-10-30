import SwiftUI

/// Every thread as a card, in shelf order with bars between groups, drawn over the panes.
struct HubView: View {
    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @Environment(\.zoom) private var zoom

    var body: some View {
        let groups = store.shelf
        let numbers = store.showsCardNumbers ? Dictionary(uniqueKeysWithValues: store.shelfOrder.prefix(9).enumerated().map { ($1.id, $0 + 1) }) : [:]
        ScrollView {
            GlassEffectContainer {
                VStack(spacing: 14 * zoom) {
                    ForEach(Array(groups.enumerated()), id: \.element.first?.id) { index, threads in
                        if index > 0 {
                            Rectangle()
                                .fill(.white.opacity(0.16))
                                .frame(height: 1)
                                .accessibilityHidden(true)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320 * zoom), spacing: 10 * zoom)], spacing: 10 * zoom) {
                            ForEach(threads) { HubCard(thread: $0, number: numbers[$0.id]) }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8 * zoom)
                .padding(.bottom, 16)
                .animation(.snappy, value: groups.map { $0.map(\.id) })
                .animation(.easeOut(duration: 0.15), value: store.showsCardNumbers)
            }
        }
        .scrollIndicators(.automatic)
        .background {
            // Esc as a key equivalent, since nothing here holds focus; off while ⌘K's shell needs it.
            Button("Back to Threads") { store.showsHub = false }
                .keyboardShortcut(.cancelAction)
                .disabled(sessions?.popup != nil)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }
}

/// The Hub's top row: Hachi, the thread count and a pill per state worth a look, beside the corner controls.
/// When the pills don't fit they wrap onto rows of their own below.
struct HubHeader: View {
    @Environment(ThreadStore.self) private var store
    @Environment(\.zoom) private var zoom

    var body: some View {
        HStack(alignment: .top, spacing: 12 * zoom) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12 * zoom) {
                    identity
                    HStack(spacing: 8 * zoom) { pills }
                }
                .frame(height: 44 * zoom)
                VStack(alignment: .leading, spacing: 4 * zoom) {
                    HStack(spacing: 12 * zoom) { identity }
                        .frame(height: 44 * zoom)
                    FlowRows(spacing: 8 * zoom) { pills }
                }
            }
            Spacer(minLength: 0)
            CornerControls()
        }
        .lineLimit(1)
        // Hachi beside the window buttons, as in the compact form.
        .padding(.leading, 78)
        .padding(.trailing, 18)
    }

    @ViewBuilder
    private var identity: some View {
        HachiCorner()
            .frame(width: 44 * zoom)
            .frame(maxHeight: .infinity, alignment: .bottom)
        Text(store.threads.count == 1 ? "1 thread" : "\(store.threads.count) threads")
            .font(.system(size: 13 * zoom, weight: .medium))
            .foregroundStyle(.white.opacity(0.72))
            .fixedSize()
    }

    @ViewBuilder
    private var pills: some View {
        let activities = store.threads.map { store.activity(for: $0.id) }
        let count = { (test: (ThreadActivity) -> Bool) in activities.filter(test).count }
        let asking = count { $0.status == .needsYou }
        if asking > 0 {
            Button { store.openNextNeedingYou() } label: {
                pill(asking == 1 ? "1 needs you" : "\(asking) need you", color: Palette.needsYou, stroke: Palette.needsYouStroke, text: Palette.needsYouText)
            }
            .buttonStyle(.plain)
            .help("Next thread that needs you (⌘J)")
        }
        pill(count { $0.status == .done && $0.isUnseen }, "finished", color: Palette.done, text: Palette.done)
        pill(count { $0.status == .working }, "working", color: Palette.working, text: Color(hex: 0xA5D0FF))
        pill(count { $0.status == .running }, "running", color: Palette.running, text: Color(hex: 0x7EE2CB))
        pill(count { if case .exited(let code) = $0.status { code != 0 } else { false } }, "failed", color: Palette.exited, text: Palette.exitedText)
    }

    @ViewBuilder
    private func pill(_ number: Int, _ label: String, color: Color, text: Color) -> some View {
        if number > 0 {
            pill("\(number) \(label)", color: color, stroke: color, text: text)
        }
    }

    private func pill(_ title: String, color: Color, stroke: Color, text: Color) -> some View {
        Text(title)
            .font(.system(size: 12 * zoom, weight: .semibold))
            .foregroundStyle(text)
            .fixedSize()
            .padding(.horizontal, 12 * zoom)
            .padding(.vertical, 6 * zoom)
            .background(color.opacity(0.16), in: .capsule)
            .overlay { Capsule().strokeBorder(stroke.opacity(0.5)) }
    }
}

/// Views left to right, starting a new row when the next one wouldn't fit.
private struct FlowRows: Layout {
    let spacing: CGFloat

    private struct Row {
        var indices: [Int]
        var width: CGFloat
        var height: CGFloat
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(of: subviews, width: proposal.width ?? .infinity)
        return CGSize(
            width: rows.map(\.width).max() ?? 0,
            height: rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(of: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(of subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if let last = rows.last, last.width + spacing + size.width <= width {
                rows[rows.count - 1].indices.append(index)
                rows[rows.count - 1].width += spacing + size.width
                rows[rows.count - 1].height = max(last.height, size.height)
            } else {
                rows.append(Row(indices: [index], width: size.width, height: size.height))
            }
        }
        return rows
    }
}

#Preview {
    let store = Mock.store()
    VStack(spacing: 6) {
        HubHeader()
        HubView()
    }
    .padding(.top, 12)
    .environment(store)
    .frame(width: 1360, height: 860)
    .background(Backdrop())
}
