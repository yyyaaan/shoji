import SwiftUI

struct ThreadCard: View {
    static let width: CGFloat = 188
    static let miniWidth: CGFloat = 44

    let thread: ShojiThread
    let name: String
    let activity: ThreadActivity
    var isFocused = false
    /// Shown in a pane, so a click only moves focus there.
    var isOnScreen = false
    /// Needs you, or finished unseen with Hachi on finish (`ThreadStore.wantsYou`): shows Hachi.
    var wantsYou = false
    /// Its ⌘1–9 number, while ⌘ is held.
    var number: Int?

    @Environment(\.zoom) private var zoom
    @Environment(\.colorSchemeContrast) private var contrast

    private var isMini: Bool { thread.isMini == true }
    private var needsYou: Bool { activity.status == .needsYou }
    /// Quiet ivory chrome and halo whatever the Hachi setting (docs/design/completion); orange stays with needs-you.
    private var finishedUnseen: Bool { activity.status == .done && activity.isUnseen }

    var body: some View {
        content
        .foregroundStyle(Palette.text)
        .frame(width: (isMini ? Self.miniWidth : Self.width) * zoom, height: 104 * zoom, alignment: .topLeading)
        // Overlays must precede the glass: inside a GlassEffectContainer the glass draws over later ones.
        .overlay(alignment: .bottom) {
            if isOnScreen {
                Capsule()
                    .fill(.white.opacity(isFocused ? 0.7 : 0.4))
                    .frame(width: (isMini ? 16 : 24) * zoom, height: 3 * zoom)
                    .padding(.bottom, 6 * zoom)
            }
        }
        .overlay(alignment: .topTrailing) {
            if wantsYou, !isMini {
                HachiPortrait(size: 32 * zoom)
                    .padding(.top, 6 * zoom)
                    .padding(.trailing, 38 * zoom)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18 * zoom)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            if let number, isMini {
                // In the leading gutter: an overhanging badge would hit the previous card's count badge.
                Text("\(number)")
                    .font(.system(size: 10 * zoom, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .frame(width: 8 * zoom)
                    .offset(x: 4 * zoom, y: 34 * zoom)
                    .transition(.opacity)
            } else if let number {
                Text("\(number)")
                    .font(.system(size: 12 * zoom, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.terminalBackground)
                    .frame(minWidth: 20 * zoom, minHeight: 20 * zoom)
                    .background(Palette.text, in: .rect(cornerRadius: 6 * zoom))
                    .offset(x: -6 * zoom, y: -6 * zoom)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) {
            if activity.attention > 0 {
                // A wider badge would cover a mini card's status icon.
                Text(isMini && activity.attention > 9 ? "9+" : "\(activity.attention)")
                    .font(.system(size: 12 * zoom, weight: .bold))
                    .foregroundStyle(Color(hex: 0x1A1206))
                    .padding(.horizontal, 6 * zoom)
                    .frame(minWidth: 22 * zoom, minHeight: 22 * zoom)
                    .background(Palette.needsYou, in: .capsule)
                    .offset(x: 7 * zoom, y: -7 * zoom)
            }
        }
        .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: 18 * zoom))
        // The halo comes from the card's shape behind the glass, so no text or glyph gets its own shadow.
        .background {
            if finishedUnseen {
                RoundedRectangle(cornerRadius: 18 * zoom)
                    .fill(Palette.done.opacity(0.07))
                    .blur(radius: 8 * zoom)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([name, tag?.capitalized, activity.status.label, finishedUnseen ? "not seen yet" : nil, subtitle, isOnScreen ? "in a pane" : nil].compactMap(\.self).joined(separator: ", "))
        .help(isMini ? "\(name)\n\(subtitle)" : thread.displayFolder)
    }

    @ViewBuilder
    private var content: some View {
        if isMini {
            VStack(spacing: 3 * zoom) {
                StatusIcon(status: activity.status, size: 18 * zoom)
                // Reads top to bottom, like a book's spine.
                Text(name)
                    .font(.system(size: 11 * zoom, weight: .medium, design: .monospaced))
                    .foregroundStyle(needsYou ? Palette.needsYouText : .white.opacity(0.75))
                    .lineLimit(1)
                    .frame(width: 63 * zoom, height: 14 * zoom, alignment: .leading)
                    .rotationEffect(.degrees(90))
                    .frame(width: 14 * zoom, height: 63 * zoom)
            }
            .padding(.top, 6 * zoom)
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 6 * zoom) {
                HStack(spacing: 8 * zoom) {
                    StatusIcon(status: activity.status, size: 22 * zoom)
                    if let tag {
                        Text(tag)
                            .font(.system(size: 10 * zoom, weight: .bold))
                            .tracking(0.6 * zoom)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    trailing
                }
                Text(name)
                    .font(.system(size: 15 * zoom, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11 * zoom, weight: .medium, design: .monospaced))
                    .foregroundStyle(needsYou ? Palette.needsYouText : .white.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 14 * zoom)
            .padding(.vertical, 12 * zoom)
        }
    }

    private var tint: Color {
        if needsYou { return Palette.needsYou.opacity(0.22) }
        if finishedUnseen { return Palette.done.opacity(isFocused ? 0.1 : 0.03) }
        return .white.opacity(isFocused ? 0.1 : 0)
    }

    @ViewBuilder
    private var trailing: some View {
        switch activity.status {
        case .working, .done, .running:
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(Self.compactElapsed(since: activity.since, now: context.date))
                    .font(.system(size: 11 * zoom, weight: .semibold))
                    .foregroundStyle(activity.status == .working ? Color(hex: 0x9FCBFF) : .white.opacity(0.72))
            }
        case .exited(let code?) where code != 0:
            Text("code \(code)")
                .font(.system(size: 11 * zoom, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.exitedText)
        default:
            EmptyView()
        }
    }

    private var tag: String? { Self.tag(of: thread, activity) }

    /// The agent, or the running command's executable ("PNPM"); none at an idle prompt.
    static func tag(of thread: ShojiThread, _ activity: ThreadActivity) -> String? {
        if let agent = activity.agent { return agent.label }
        guard let executable = thread.command?.split(whereSeparator: \.isWhitespace).first else { return nil }
        return (String(executable) as NSString).lastPathComponent.uppercased()
    }

    /// The folder; a plain command's line instead (its title is the folder), or an agent's question.
    private var subtitle: String {
        if activity.status == .needsYou { return activity.detail ?? "Waiting for you" }
        if activity.agent == nil, let command = thread.command { return command }
        return thread.displayFolder
    }

    private var borderColor: Color {
        if finishedUnseen { return Palette.done.opacity(contrast == .increased ? 0.6 : 0.36) }
        return switch activity.status {
        case .needsYou: Palette.needsYouStroke.opacity(0.85)
        case .done: Palette.working.opacity(0.7)
        case .exited(code: let code) where code != 0: Palette.exited.opacity(0.6)
        default: .white.opacity(isFocused ? 0.4 : 0.12)
        }
    }

    /// "now", "6m", "2h", "3d".
    static func compactElapsed(since date: Date, now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        switch minutes {
        case ..<1: return "now"
        case ..<60: return "\(minutes)m"
        case ..<(60 * 24): return "\(minutes / 60)h"
        default: return "\(minutes / (60 * 24))d"
        }
    }
}

#Preview {
    let store = Mock.store()
    let minis = store.threads.map { thread in
        var mini = thread
        mini.isMini = true
        return mini
    }
    VStack(alignment: .leading, spacing: 18) {
        ForEach([store.threads, minis], id: \.first?.isMini) { threads in
            HStack(spacing: 10) {
                ForEach(threads) { thread in
                    ThreadCard(thread: thread, name: store.name(of: thread), activity: store.activity(for: thread.id), isFocused: thread.id == Mock.threads[1].id, isOnScreen: store.layout.visibleThreadIds.contains(thread.id), wantsYou: store.wantsYou(thread.id))
                }
            }
        }
    }
    .padding(24)
    .background(Backdrop())
}
