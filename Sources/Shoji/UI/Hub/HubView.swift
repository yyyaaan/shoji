import SwiftUI

/// Every thread as a card over the panes: groups left to right, each in one or more columns.
struct HubView: View {
    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @Environment(\.zoom) private var zoom
    @State private var width: CGFloat = 0

    var body: some View {
        let groups = store.shelf
        let numbers = store.showsCardNumbers ? Dictionary(uniqueKeysWithValues: store.shelfOrder.prefix(9).enumerated().map { ($1.id, $0 + 1) }) : [:]
        let spacing = 10 * zoom
        let barGap = 14 * zoom
        let room = max(width - 36, 0)
        let bars = CGFloat(max(groups.count - 1, 0)) * (2 * barGap + 1)
        // As if every gap were a column gap: a bar takes a wider one.
        let columnRoom = room - bars + CGFloat(max(groups.count - 1, 0)) * spacing
        let fit = max(1, Int((columnRoom + spacing) / (320 * zoom + spacing)))
        let spans = Self.columns(for: groups.map(\.count), fitting: fit)
        let total = max(spans.reduce(0, +), 1)
        let gaps = CGFloat(total - groups.count) * spacing
        // Filling the width, but never wider than a card would be with every column in use.
        let columnWidth = max(320 * zoom, min((room - bars - gaps) / CGFloat(total), (columnRoom - CGFloat(fit - 1) * spacing) / CGFloat(fit)))
        let overflows = CGFloat(total) * columnWidth + gaps + bars > room + 0.5
        ScrollView(overflows ? [.vertical, .horizontal] : .vertical) {
            GlassEffectContainer {
                // One flat list of cards, so reordering never rebuilds a card (and its screen lines).
                HubColumns(counts: groups.map(\.count), spans: spans, columnWidth: columnWidth, spacing: spacing, barGap: barGap) {
                    ForEach(groups.flatMap { $0 }) { HubCard(thread: $0, number: numbers[$0.id]) }
                    ForEach(1..<max(groups.count, 1), id: \.self) { _ in
                        Rectangle()
                            .fill(.white.opacity(0.16))
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 8 * zoom)
                .padding(.bottom, 16)
                .animation(.snappy, value: groups.map { $0.map(\.id) })
                .animation(.easeOut(duration: 0.15), value: store.showsCardNumbers)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
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

extension HubView {
    /// Columns per group: one each, then spare columns go to the tallest group, as many as it takes to lose a row.
    static func columns(for counts: [Int], fitting fit: Int) -> [Int] {
        var spans = counts.map { _ in 1 }
        var spare = fit - counts.count
        while spare > 0 {
            let rows = counts.indices.map { (counts[$0] + spans[$0] - 1) / spans[$0] }
            guard let tallest = rows.indices.max(by: { rows[$0] < rows[$1] }), rows[tallest] > 1 else { break }
            let needed = (counts[tallest] + rows[tallest] - 2) / (rows[tallest] - 1)
            guard needed - spans[tallest] <= spare else { break }
            spare -= needed - spans[tallest]
            spans[tallest] = needed
        }
        return spans
    }
}

/// Groups left to right, each in its `spans` columns read top to bottom; then the bars, as tall as the tallest column.
private struct HubColumns: Layout {
    let counts: [Int]
    let spans: [Int]
    let columnWidth: CGFloat
    let spacing: CGFloat
    let barGap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (cards, bars, size) = arrange(subviews)
        for (index, frame) in cards.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
        for (index, x) in bars.enumerated() where subviews.indices.contains(cards.count + index) {
            subviews[cards.count + index].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY), proposal: ProposedViewSize(width: 1, height: size.height))
        }
    }

    private func arrange(_ subviews: Subviews) -> (cards: [CGRect], bars: [CGFloat], size: CGSize) {
        var cards: [CGRect] = []
        var bars: [CGFloat] = []
        var (x, height) = (CGFloat.zero, CGFloat.zero)
        for (group, count) in counts.enumerated() {
            if group > 0 {
                bars.append(x + barGap)
                x += 2 * barGap + 1
            }
            let span = spans[group]
            let rows = (count + span - 1) / span
            for column in 0..<span {
                var y = CGFloat.zero
                for _ in 0..<max(min(rows, count - column * rows), 0) where subviews.indices.contains(cards.count) {
                    let cardHeight = subviews[cards.count].sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
                    cards.append(CGRect(x: x, y: y, width: columnWidth, height: cardHeight))
                    y += cardHeight + spacing
                }
                height = max(height, y - spacing)
                x += columnWidth + (column < span - 1 ? spacing : 0)
            }
        }
        return (cards, bars, CGSize(width: x, height: height))
    }
}

/// The Hub's top row; the pills wrap below when they don't fit.
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
        // Clear of the window buttons.
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
        let finished = count { $0.status == .done && $0.isUnseen }
        let working = count { $0.status == .working }
        let running = count { $0.status == .running }
        let failed = count { if case .exited(let code) = $0.status { code != 0 } else { false } }
        if asking > 0 {
            Button { store.openNextNeedingYou() } label: {
                pill(asking == 1 ? "1 needs you" : "\(asking) need you", color: Palette.needsYou, stroke: Palette.needsYouStroke, text: Palette.needsYouText)
            }
            .buttonStyle(.plain)
            .help("Next thread that needs you (⌘J)")
        }
        pill(finished, "finished", color: Palette.done, text: Palette.done)
        pill(working, "working", color: Palette.working, text: Color(hex: 0xA5D0FF))
        pill(running, "running", color: Palette.running, text: Color(hex: 0x7EE2CB))
        pill(failed, "failed", color: Palette.exited, text: Palette.exitedText)
        if asking + finished + working + running + failed == 0 {
            Label {
                Text("All quiet")
                    .font(.system(size: 12 * zoom, weight: .medium))
            } icon: {
                Image(.zenBonsai)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18 * zoom, height: 18 * zoom)
            }
            .foregroundStyle(.white.opacity(0.55))
            .fixedSize()
        }
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
