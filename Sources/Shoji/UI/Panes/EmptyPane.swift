import SwiftUI

/// What a closed thread leaves: a pick of the threads not on screen, or a new one. ⌘W again closes the pane.
struct EmptyPane: View {
    let id: UUID

    @Environment(ThreadStore.self) private var store
    @Environment(\.zoom) private var zoom
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @FocusState private var isFocused: Bool
    @State private var selection: Choice?
    @State private var hovered: Choice?
    @State private var isTargeted = false

    private enum Choice: Hashable {
        case thread(UUID)
        case newThread
    }

    /// Shelf groups, minus the threads already on screen.
    private var groups: [[ShojiThread]] {
        let onScreen = Set(store.layout.panes)
        return store.shelf.map { $0.filter { !onScreen.contains($0.id) } }.filter { !$0.isEmpty }
    }

    var body: some View {
        let groups = groups
        let choices = groups.flatMap { $0.map { Choice.thread($0.id) } } + [.newThread]
        let current = selection.flatMap { choices.contains($0) ? $0 : nil } ?? choices[0]
        let highlighted = hovered ?? (isFocused ? current : nil)
        VStack(spacing: 0) {
            Spacer(minLength: 12 * zoom)
            ViewThatFits(in: .vertical) {
                picker(groups, highlighted: highlighted)
                ScrollView { picker(groups, highlighted: highlighted) }
                    .scrollIndicators(.automatic)
            }
            .frame(maxWidth: 360 * zoom)
            .glassEffect(.regular, in: .rect(cornerRadius: 16 * zoom))
            .padding(.horizontal, 16 * zoom)
            Spacer(minLength: 12 * zoom)
            if store.layout.panes.count > 1 {
                Button("Close Pane") { store.closePane(id) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12 * zoom, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .help("Or ⌘W")
                    .padding(.bottom, 12 * zoom)
            }
        }
        .foregroundStyle(Palette.text)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.terminalBackground.opacity(reduceTransparency ? 1 : Palette.paneOpacity), in: .rect(cornerRadius: 18 * zoom))
        .overlay {
            RoundedRectangle(cornerRadius: 18 * zoom)
                .fill(Palette.working.opacity(isTargeted ? 0.08 : 0))
                .strokeBorder(isTargeted ? Palette.working : .white.opacity(isFocused ? 0.32 : 0.16), lineWidth: isTargeted ? 2 : 1)
                .allowsHitTesting(false)
        }
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { step(-1, in: choices, from: current) }
        .onKeyPress(.downArrow) { step(1, in: choices, from: current) }
        .onKeyPress(.return) {
            pick(current)
            return .handled
        }
        // Already focused (back from the Hub), onChange(of: isFocused) won't fire; and a new view takes focus a turn later.
        .onChange(of: store.focusRequest, initial: true) { _, request in
            guard request == id else { return }
            if isFocused { store.focus(id) } else { Task { isFocused = true } }
        }
        .onChange(of: isFocused) { _, focused in
            if focused { store.focus(id) }
        }
        // Anywhere on it, like a drop in a pane's middle: an empty pane has nothing to split from.
        .onDrop(of: [.shojiThread], isTargeted: $isTargeted) { providers in
            CardDrag.load(providers) { store.show($0, inPaneOf: id) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Empty pane")
    }

    private func picker(_ groups: [[ShojiThread]], highlighted: Choice?) -> some View {
        VStack(alignment: .leading, spacing: 2 * zoom) {
            Text(store.threads.isEmpty ? "No threads yet" : groups.isEmpty ? "Every thread is on screen" : "Show a thread here")
                .font(.system(size: 12 * zoom, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 10 * zoom)
                .padding(.bottom, 4 * zoom)
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index > 0 { separator }
                ForEach(group) { thread in
                    let status = store.activity(for: thread.id).status
                    row(.thread(thread.id), highlighted: highlighted) {
                        StatusIcon(status: status, size: 16 * zoom)
                        Text(store.name(of: thread))
                            .font(.system(size: 13 * zoom, weight: .semibold))
                            .layoutPriority(1)
                        Spacer(minLength: 8 * zoom)
                        Text(thread.displayFolder)
                            .font(.system(size: 11 * zoom, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .truncationMode(.head)
                    }
                    .accessibilityLabel("\(store.name(of: thread)), \(status.label)")
                }
            }
            separator
            row(.newThread, highlighted: highlighted) {
                Image(systemName: "plus")
                    .font(.system(size: 12 * zoom, weight: .bold))
                    .frame(width: 16 * zoom, height: 16 * zoom)
                Text("New Thread")
                    .font(.system(size: 13 * zoom, weight: .semibold))
                Spacer(minLength: 8 * zoom)
                Text("⌘N")
                    .font(.system(size: 11 * zoom, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .lineLimit(1)
        .padding(8 * zoom)
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 10 * zoom)
            .padding(.vertical, 4 * zoom)
            .accessibilityHidden(true)
    }

    private func row(_ choice: Choice, highlighted: Choice?, @ViewBuilder content: () -> some View) -> some View {
        Button { pick(choice) } label: {
            HStack(spacing: 8 * zoom) { content() }
                .padding(.horizontal, 10 * zoom)
                .frame(height: 28 * zoom)
                .background(.white.opacity(highlighted == choice ? 0.1 : 0), in: .rect(cornerRadius: 8 * zoom))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? choice : (hovered == choice ? nil : hovered) }
    }

    private func step(_ offset: Int, in choices: [Choice], from current: Choice) -> KeyPress.Result {
        let index = choices.firstIndex(of: current) ?? 0
        selection = choices[(index + offset + choices.count) % choices.count]
        hovered = nil
        return .handled
    }

    private func pick(_ choice: Choice) {
        switch choice {
        case .thread(let thread): store.show(thread, inPaneOf: id)
        case .newThread: store.newThread(inPaneOf: id)
        }
    }
}

#Preview {
    let store = Mock.store()
    EmptyPane(id: UUID())
        .environment(store)
        .frame(width: 560, height: 420)
        .padding()
        .background(Backdrop())
}
