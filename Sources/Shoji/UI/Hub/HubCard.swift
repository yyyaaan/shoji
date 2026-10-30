import SwiftUI

/// A thread in the Hub: where it is, what it's doing or waiting on, its last lines, and the way in.
struct HubCard: View {
    let thread: ShojiThread
    /// Its ⌘1–9 number, while ⌘ is held.
    var number: Int?

    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @Environment(\.zoom) private var zoom
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var branch: String?

    private var activity: ThreadActivity { store.activity(for: thread.id) }
    private var needsYou: Bool { activity.status == .needsYou }
    private var finishedUnseen: Bool { activity.status == .done && activity.isUnseen }

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * zoom) {
            header
            summary
            excerpt
            actions
        }
        .padding(18 * zoom)
        .foregroundStyle(Palette.text)
        .contentShape(.rect)
        .onTapGesture { store.open(thread.id) }
        // Overlays must precede the glass: inside a GlassEffectContainer the glass draws over later ones.
        .overlay {
            RoundedRectangle(cornerRadius: 22 * zoom)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            if let number {
                Text("\(number)")
                    .font(.system(size: 12 * zoom, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.terminalBackground)
                    .frame(minWidth: 20 * zoom, minHeight: 20 * zoom)
                    .background(Palette.text, in: .rect(cornerRadius: 6 * zoom))
                    .offset(x: -6 * zoom, y: -6 * zoom)
                    .transition(.opacity)
            }
        }
        .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 22 * zoom))
        .contextMenu { CardMenu(thread: thread) }
        .task(id: thread.folder) { branch = GitBranch.of(thread.folder) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.name(of: thread))
    }

    private var header: some View {
        HStack(spacing: 12 * zoom) {
            StatusIcon(status: activity.status, size: 34 * zoom)
            VStack(alignment: .leading, spacing: 3 * zoom) {
                HStack(spacing: 8 * zoom) {
                    Text(store.name(of: thread))
                        .font(.system(size: 18 * zoom, weight: .bold))
                        .lineLimit(1)
                    if let tag = ThreadCard.tag(of: thread, activity) {
                        Text(tag)
                            .font(.system(size: 10 * zoom, weight: .bold))
                            .tracking(0.6 * zoom)
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 7 * zoom)
                            .padding(.vertical, 3 * zoom)
                            .background(.white.opacity(0.14), in: .rect(cornerRadius: 6 * zoom))
                    }
                }
                Text([thread.displayFolder, branch].compactMap(\.self).joined(separator: " · "))
                    .font(.system(size: 12 * zoom, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            if store.wantsYou(thread.id) {
                HachiPortrait(size: 34 * zoom)
            }
            statusPill
        }
    }

    private var statusPill: some View {
        let (fill, stroke, text): (Color, Color, Color) = switch activity.status {
        case .needsYou: (Palette.needsYou, .clear, Color(hex: 0x1A1206))
        case .working: (Palette.working.opacity(0.18), Palette.working.opacity(0.5), Color(hex: 0xA5D0FF))
        case .running: (Palette.running.opacity(0.18), Palette.running.opacity(0.5), Color(hex: 0x7EE2CB))
        case .exited(let code) where code != 0: (Palette.exited.opacity(0.16), Palette.exited.opacity(0.5), Palette.exitedText)
        case .idle: (.clear, .white.opacity(0.4), .white.opacity(0.85))
        default: (.white.opacity(0.12), .white.opacity(0.28), Palette.done)
        }
        return Text(activity.status.label)
            .font(.system(size: 12 * zoom, weight: .semibold))
            .foregroundStyle(text)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 12 * zoom)
            .padding(.vertical, 5 * zoom)
            .background(fill, in: .capsule)
            .overlay {
                Capsule().strokeBorder(stroke, style: StrokeStyle(lineWidth: 1, dash: activity.status == .idle ? [3, 3] : []))
            }
            // The status icon already says it.
            .accessibilityHidden(true)
    }

    private var summary: some View {
        Text(summaryText)
            .font(.system(size: 13 * zoom, design: activity.status == .running ? .monospaced : .default))
            .foregroundStyle(needsYou ? Color(hex: 0xFFE0C2) : .white.opacity(0.88))
            .lineLimit(1)
            .padding(.horizontal, 12 * zoom)
            .padding(.vertical, 9 * zoom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(needsYou ? Palette.needsYou.opacity(0.1) : .white.opacity(0.06), in: .rect(cornerRadius: 12 * zoom))
            .overlay {
                if needsYou {
                    RoundedRectangle(cornerRadius: 12 * zoom).strokeBorder(Palette.needsYouStroke.opacity(0.35))
                }
            }
            .help(summaryText)
    }

    /// From hooks and the shell integration, never read off the screen (AGENTS invariant 5).
    private var summaryText: String {
        switch activity.status {
        case .needsYou: activity.detail ?? "Waiting for you"
        case .working: activity.detail ?? "Working"
        case .done: activity.isUnseen ? "Finished while you were away" : "Finished its turn"
        case .running: thread.command ?? "Running a command"
        case .idle: activity.agent.map { "\($0.rawValue.capitalized) is at its prompt" } ?? "At the prompt"
        case .exited: activity.isAlive ? "The last command failed" : "The shell has ended"
        }
    }

    /// Read once a second while the Hub shows.
    private var excerpt: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let lines = Excerpt.lines(sessions?.terminal(for: thread.id)?.screenLines() ?? [], count: 4)
            VStack(alignment: .leading, spacing: 2 * zoom) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line).lineLimit(1)
                }
            }
            .font(.system(size: 11.5 * zoom, design: .monospaced))
            .foregroundStyle(Color(hex: 0xA9B2C0))
            .frame(maxWidth: .infinity, minHeight: 62 * zoom, maxHeight: 62 * zoom, alignment: .bottomLeading)
            .clipped()
            .padding(.horizontal, 12 * zoom)
            .padding(.vertical, 10 * zoom)
            .background(Palette.terminalBackground, in: .rect(cornerRadius: 12 * zoom))
        }
    }

    private var actions: some View {
        HStack(spacing: 8 * zoom) {
            Button("Open") { store.open(thread.id) }
                .buttonStyle(HubButtonStyle(zoom: zoom, fill: needsYou ? Palette.needsYou : .white.opacity(0.16), text: needsYou ? Color(hex: 0x1A1206) : .white))
            Button("Open Maximized", systemImage: "arrow.up.left.and.arrow.down.right") {
                store.open(thread.id)
                if store.layout.maximizedThreadId != thread.id { store.toggleMaximize(thread.id) }
            }
            .labelStyle(.iconOnly)
            .help("Open Maximized")
            ForEach(Editor.installed) { editor in
                Button(editor.name) { editor.open(thread.folder) }
                    .help("Open in \(editor.name)")
            }
            if !activity.isAlive {
                Button("Restart") { sessions?.restart(thread.id) }
            }
            Spacer(minLength: 0)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(elapsed(now: context.date))
                    .font(.system(size: 12 * zoom))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .buttonStyle(HubButtonStyle(zoom: zoom))
    }

    private func elapsed(now: Date) -> String {
        let span = ThreadCard.compactElapsed(since: activity.since, now: now)
        let ongoing = { (verb: String) in span == "now" ? verb : "\(verb) \(span)" }
        let ago = span == "now" ? "just now" : "\(span) ago"
        return switch activity.status {
        case .needsYou: ongoing("waiting")
        case .working: ongoing("working")
        case .running: ongoing("running")
        case .idle: ongoing("idle")
        case .done: "finished \(ago)"
        case .exited: activity.isAlive ? "failed \(ago)" : "ended \(ago)"
        }
    }

    private var tint: Color {
        if needsYou { return Palette.needsYou.opacity(0.22) }
        if finishedUnseen { return Palette.done.opacity(0.03) }
        return .clear
    }

    private var borderColor: Color {
        if finishedUnseen { return Palette.done.opacity(contrast == .increased ? 0.6 : 0.36) }
        return switch activity.status {
        case .needsYou: Palette.needsYouStroke.opacity(0.85)
        case .done: Palette.working.opacity(0.7)
        case .exited(code: let code) where code != 0: Palette.exited.opacity(0.6)
        default: .white.opacity(contrast == .increased ? 0.3 : 0.14)
        }
    }
}

/// The last lines of a thread's screen for its Hub card. An agent's input box and footer start at a rule of
/// box-drawing characters near the bottom; they're left out so the lines show the work.
enum Excerpt {
    static func lines(_ screen: [String], count: Int) -> [String] {
        var rows = Array(screen.reversed().drop(while: isBlank).reversed())
        if let rule = rows.indices.suffix(12).first(where: { isRule(rows[$0]) }) {
            rows.removeSubrange(rule...)
        }
        return Array(rows.filter { !isBlank($0) }.suffix(count))
    }

    private static func isBlank(_ line: String) -> Bool {
        line.allSatisfy(\.isWhitespace)
    }

    private static func isRule(_ line: String) -> Bool {
        let marks = line.unicodeScalars.filter { !CharacterSet.whitespaces.contains($0) }
        return marks.count >= 3 && marks.allSatisfy { (0x2500...0x257F).contains($0.value) }
    }
}

/// Plain rounded buttons sized by the interface size, like the mockup's (`docs/design/hub.html`).
private struct HubButtonStyle: ButtonStyle {
    let zoom: Double
    var fill: Color = .white.opacity(0.08)
    var text: Color = Palette.text

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13 * zoom, weight: .semibold))
            .foregroundStyle(text)
            .padding(.horizontal, 14 * zoom)
            .frame(minWidth: 34 * zoom, minHeight: 32 * zoom)
            .background(fill, in: .rect(cornerRadius: 10 * zoom))
            .overlay {
                RoundedRectangle(cornerRadius: 10 * zoom).strokeBorder(.white.opacity(0.16))
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(.rect)
    }
}

#Preview {
    let store = Mock.store()
    VStack(spacing: 14) {
        ForEach(store.threads.prefix(3)) { HubCard(thread: $0) }
    }
    .frame(width: 520)
    .padding(24)
    .environment(store)
    .background(Backdrop())
}
