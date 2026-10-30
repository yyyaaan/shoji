import SwiftUI

/// Every thread as a big card, in shelf order with the shelf's bars between groups, so cards stay where your
/// hand expects them and match ⌘1–9. Drawn over the panes, which keep their terminals hosted underneath.
struct HubView: View {
    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @Environment(\.zoom) private var zoom

    var body: some View {
        let numbers = store.showsCardNumbers ? Dictionary(uniqueKeysWithValues: store.shelfOrder.prefix(9).enumerated().map { ($1.id, $0 + 1) }) : [:]
        ScrollView {
            GlassEffectContainer {
                VStack(spacing: 18 * zoom) {
                    ForEach(Array(store.shelf.enumerated()), id: \.element.first?.id) { index, threads in
                        if index > 0 {
                            Rectangle()
                                .fill(.white.opacity(0.16))
                                .frame(height: 1)
                                .accessibilityHidden(true)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 440 * zoom), spacing: 14 * zoom)], spacing: 14 * zoom) {
                            ForEach(threads) { HubCard(thread: $0, number: numbers[$0.id]) }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8 * zoom)
                .padding(.bottom, 16)
                .animation(.snappy, value: store.shelf.map { $0.map(\.id) })
                .animation(.easeOut(duration: 0.15), value: store.showsCardNumbers)
            }
        }
        .scrollIndicators(.automatic)
        .background {
            // Esc goes back; no view holds keyboard focus here, so it's a key equivalent. Off while the quick
            // terminal is up, whose shell needs Esc.
            Button("Back to Threads") { store.showsHub = false }
                .keyboardShortcut(.cancelAction)
                .disabled(sessions?.popup != nil)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }
}

/// The Hub's top row beside Hachi: how many threads, and pills for the states that want a look.
struct HubTotals: View {
    @Environment(ThreadStore.self) private var store
    @Environment(\.zoom) private var zoom

    var body: some View {
        let activities = store.threads.map { store.activity(for: $0.id) }
        let count = { (test: (ThreadActivity) -> Bool) in activities.filter(test).count }
        let asking = count { $0.status == .needsYou }
        HStack(spacing: 8 * zoom) {
            Text(store.threads.count == 1 ? "1 thread" : "\(store.threads.count) threads")
                .font(.system(size: 13 * zoom, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.trailing, 4 * zoom)
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
        .lineLimit(1)
        .fixedSize()
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
            .padding(.horizontal, 12 * zoom)
            .padding(.vertical, 6 * zoom)
            .background(color.opacity(0.16), in: .capsule)
            .overlay { Capsule().strokeBorder(stroke.opacity(0.5)) }
    }
}

/// Threads | Hub, at the same spot in both.
struct HubSwitch: View {
    @Environment(ThreadStore.self) private var store

    var body: some View {
        Picker("View", selection: Bindable(store).showsHub) {
            Text("Threads").tag(false)
            Text("Hub").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("Threads or Hub (⇧⌘H)")
    }
}

#Preview {
    let store = Mock.store()
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            HubTotals()
            Spacer()
            HubSwitch()
        }
        .padding(.horizontal, 18)
        HubView()
    }
    .padding(.top, 12)
    .environment(store)
    .frame(width: 1360, height: 860)
    .background(Backdrop())
}
