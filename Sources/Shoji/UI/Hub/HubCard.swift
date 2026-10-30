import SwiftUI

/// A thread in the Hub.
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
        VStack(alignment: .leading, spacing: 8 * zoom) {
            title
            metadata
            if let summaryText {
                summary(summaryText)
            }
            excerpt
            actions
            folderLinks
        }
        .padding(12 * zoom)
        .foregroundStyle(Palette.text)
        .contentShape(.rect)
        .onTapGesture { store.open(thread.id) }
        .overlay {
            RoundedRectangle(cornerRadius: 16 * zoom)
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
        .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 16 * zoom))
        .contextMenu { CardMenu(thread: thread) }
        .task(id: thread.folder) { branch = GitBranch.of(thread.folder) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.name(of: thread))
    }

    private var title: some View {
        HStack(spacing: 8 * zoom) {
            StatusIcon(status: activity.status, size: 24 * zoom)
            Text(store.name(of: thread))
                .font(.system(size: 14 * zoom, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(store.name(of: thread))
            statusPill
        }
    }

    private var metadata: some View {
        let place = [thread.displayFolder, branch].compactMap(\.self).joined(separator: " · ")
        return HStack(spacing: 6 * zoom) {
            if let tag = ThreadCard.tag(of: thread, activity) {
                // About 72 pt at most, so a long command name can't crowd out the folder.
                Text(tag.count > 10 ? tag.prefix(9) + "…" : tag)
                    .font(.system(size: 9 * zoom, weight: .bold))
                    .tracking(0.5 * zoom)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize()
                    .padding(.horizontal, 5 * zoom)
                    .padding(.vertical, 2 * zoom)
                    .background(.white.opacity(0.14), in: .rect(cornerRadius: 5 * zoom))
                    .help(tag)
            }
            Text(place)
                .font(.system(size: 11 * zoom, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(place)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(elapsed(now: context.date))
                    .font(.system(size: 10 * zoom))
                    .foregroundStyle(.white.opacity(0.65))
                    .monospacedDigit()
                    .fixedSize()
            }
        }
        // The tag chip's height, so cards without one line up.
        .frame(minHeight: 15 * zoom)
    }

    private var statusPill: some View {
        let (fill, stroke, text): (Color, Color, Color) = switch activity.status {
        case .needsYou: (Palette.needsYou, .clear, Color(hex: 0x1A1206))
        case .working: (Palette.working.opacity(0.18), Palette.working.opacity(0.5), Color(hex: 0xA5D0FF))
        case .running: (Palette.running.opacity(0.18), Palette.running.opacity(0.5), Color(hex: 0x7EE2CB))
        case .exited(let code) where code != 0: (Palette.exited.opacity(0.16), Palette.exited.opacity(0.5), Palette.exitedText)
        case .idle: (.clear, .white.opacity(contrast == .increased ? 0.36 : 0.18), .white.opacity(0.85))
        default: (.white.opacity(0.12), .white.opacity(0.28), Palette.done)
        }
        return Text(activity.status.label)
            .font(.system(size: 11 * zoom, weight: .semibold))
            .foregroundStyle(text)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8 * zoom)
            .padding(.vertical, 2 * zoom)
            .background(fill, in: .capsule)
            .overlay {
                Capsule().strokeBorder(stroke)
            }
            .accessibilityHidden(true)
    }

    private func summary(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12 * zoom, design: activity.status == .running ? .monospaced : .default))
            .foregroundStyle(needsYou ? Color(hex: 0xFFE0C2) : .white.opacity(0.88))
            .lineLimit(1)
            .padding(.horizontal, 10 * zoom)
            .padding(.vertical, 6 * zoom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(needsYou ? Palette.needsYou.opacity(0.1) : .white.opacity(0.06), in: .rect(cornerRadius: 9 * zoom))
            .overlay {
                if needsYou {
                    RoundedRectangle(cornerRadius: 9 * zoom).strokeBorder(Palette.needsYouStroke.opacity(0.35))
                }
            }
            .help(text)
    }

    /// From hooks and the shell, never the screen (AGENTS invariant 5); none while idle.
    private var summaryText: String? {
        switch activity.status {
        case .needsYou: activity.detail ?? "Waiting for you"
        case .working: activity.detail ?? "Working"
        case .done: activity.isUnseen ? "Finished while you were away" : "Finished its turn"
        case .running: thread.command ?? "Running a command"
        case .idle: nil
        case .exited: activity.isAlive ? "The last command failed" : "The shell has ended"
        }
    }

    /// Without a summary it takes that room, so cards stay one height.
    private var excerpt: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let roomy = summaryText == nil
            let lines = Excerpt.lines(sessions?.terminal(for: thread.id)?.screenLines() ?? [], count: roomy ? 5 : 3)
            VStack(alignment: .leading, spacing: 1 * zoom) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line).lineLimit(1)
                }
            }
            .font(.system(size: 10.5 * zoom, design: .monospaced))
            .foregroundStyle(Color(hex: 0xA9B2C0))
            .frame(maxWidth: .infinity, minHeight: (roomy ? 75 : 40) * zoom, maxHeight: (roomy ? 75 : 40) * zoom, alignment: .bottomLeading)
            .clipped()
            .padding(.horizontal, 10 * zoom)
            .padding(.vertical, 7 * zoom)
            .background(Palette.terminalBackground, in: .rect(cornerRadius: 9 * zoom))
        }
    }

    private var actions: some View {
        HStack(spacing: 6 * zoom) {
            Button("Open") { store.open(thread.id) }
                .buttonStyle(HubButtonStyle(zoom: zoom, fill: needsYou ? Palette.needsYou : .white.opacity(0.16), text: needsYou ? Color(hex: 0x1A1206) : .white))
            Button("Open Maximized", systemImage: "arrow.up.left.and.arrow.down.right") {
                store.open(thread.id)
                if store.layout.maximizedThreadId != thread.id { store.toggleMaximize(thread.id) }
            }
            .labelStyle(.iconOnly)
            .help("Open Maximized")
            if !activity.isAlive {
                Button("Restart") { sessions?.restart(thread.id) }
            }
            Spacer(minLength: 0)
            if store.wantsYou(thread.id) {
                HachiPortrait(size: 26 * zoom)
            }
        }
        .buttonStyle(HubButtonStyle(zoom: zoom))
    }

    private var folderLinks: some View {
        HStack(spacing: 4 * zoom) {
            Button("Finder") {
                NSWorkspace.shared.open(URL(filePath: (thread.folder as NSString).expandingTildeInPath, directoryHint: .isDirectory))
            }
            .help("Open in Finder")
            ForEach(Editor.installed) { editor in
                Button(editor.name) { editor.open(thread.folder) }
                    .help("Open in \(editor.name)")
            }
        }
        .buttonStyle(FolderLinkStyle(zoom: zoom))
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

/// A thread's last screen lines, without an agent's input box and footer (from a box-drawing rule near the bottom).
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

/// Scales with Interface Size, which native buttons don't.
private struct HubButtonStyle: ButtonStyle {
    let zoom: Double
    var fill: Color = .white.opacity(0.08)
    var text: Color = Palette.text

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12 * zoom, weight: .semibold))
            .foregroundStyle(text)
            .padding(.horizontal, 10 * zoom)
            .frame(minWidth: 28 * zoom, minHeight: 26 * zoom)
            .background(fill, in: .rect(cornerRadius: 8 * zoom))
            .overlay {
                RoundedRectangle(cornerRadius: 8 * zoom).strokeBorder(.white.opacity(0.16))
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(.rect)
    }
}

/// The quiet row under a card's actions.
private struct FolderLinkStyle: ButtonStyle {
    let zoom: Double

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11 * zoom, weight: .medium))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 7 * zoom)
            .frame(minHeight: 22 * zoom)
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0.05), in: .rect(cornerRadius: 6 * zoom))
            .contentShape(.rect)
    }
}

#Preview {
    let store = Mock.store()
    VStack(spacing: 14) {
        ForEach(store.threads.prefix(3)) { HubCard(thread: $0) }
    }
    .frame(width: 340)
    .padding(24)
    .environment(store)
    .background(Backdrop())
}
