import SwiftUI

struct ThreadCard: View {
    let thread: ShojiThread
    let activity: ThreadActivity
    var isFocused = false

    @Environment(\.zoom) private var zoom

    private var needsYou: Bool { activity.status == .needsYou }

    var body: some View {
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
            Text(thread.displayTitle)
                .font(.system(size: 15 * zoom, weight: .semibold))
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 11 * zoom, weight: .medium, design: .monospaced))
                .foregroundStyle(needsYou ? Palette.needsYouText : .white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(Palette.text)
        .padding(.horizontal, 14 * zoom)
        .padding(.vertical, 12 * zoom)
        .frame(width: 188 * zoom, height: 104 * zoom, alignment: .topLeading)
        // Overlays must precede the glass: inside a GlassEffectContainer the glass draws over later ones.
        .overlay(alignment: .topTrailing) {
            if needsYou {
                HachiPortrait(size: 32 * zoom)
                    .padding(.top, 6 * zoom)
                    .padding(.trailing, 38 * zoom)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18 * zoom)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            if activity.attention > 0 {
                Text("\(activity.attention)")
                    .font(.system(size: 12 * zoom, weight: .bold))
                    .foregroundStyle(Color(hex: 0x1A1206))
                    .padding(.horizontal, 6 * zoom)
                    .frame(minWidth: 22 * zoom, minHeight: 22 * zoom)
                    .background(Palette.needsYou, in: .capsule)
                    .offset(x: 7 * zoom, y: -7 * zoom)
            }
        }
        .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: 18 * zoom))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([thread.displayTitle, tag?.capitalized, activity.status.label, subtitle].compactMap(\.self).joined(separator: ", "))
    }

    private var tint: Color {
        if needsYou { return Palette.needsYou.opacity(0.22) }
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

    /// The agent, or the running command's executable ("PNPM"); none at an idle prompt.
    private var tag: String? {
        if let agent = activity.agent { return agent.label }
        guard let executable = thread.command?.split(whereSeparator: \.isWhitespace).first else { return nil }
        return (String(executable) as NSString).lastPathComponent.uppercased()
    }

    private var subtitle: String {
        if needsYou { return activity.detail ?? "Waiting for you" }
        if activity.agent != nil, let title = activity.terminalTitle, !title.isEmpty { return title }
        if activity.agent == nil, let command = thread.command { return command }
        return thread.displayFolder
    }

    private var borderColor: Color {
        switch activity.status {
        case .needsYou: Palette.needsYouStroke.opacity(0.85)
        case .done: Palette.working.opacity(0.7)
        case .exited(code: let code) where code != 0: Palette.exited.opacity(0.6)
        default: .white.opacity(isFocused ? 0.4 : 0.12)
        }
    }

    /// "now", "6m", "2h", "3d".
    private static func compactElapsed(since date: Date, now: Date) -> String {
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
    HStack(spacing: 10) {
        ForEach(store.threads) { thread in
            ThreadCard(thread: thread, activity: store.activity(for: thread.id), isFocused: thread.id == Mock.threads[1].id)
        }
    }
    .padding(24)
    .background(Backdrop())
}
