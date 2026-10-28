import SwiftUI

struct ThreadCard: View {
    let thread: ShojiThread
    let activity: ThreadActivity
    var isFocused = false

    private var needsYou: Bool { activity.status == .needsYou }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                StatusIcon(status: activity.status)
                if thread.group == .agent {
                    Text(thread.kind.label)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer(minLength: 0)
                trailing
            }
            Text(thread.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(needsYou ? Palette.needsYouText : .white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(Palette.text)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: thread.group == .agent ? 196 : 168, height: 104, alignment: .topLeading)
        // Overlays must precede the glass: inside a GlassEffectContainer the glass draws over later ones.
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            if activity.attention > 0 {
                Text("\(activity.attention)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: 0x1A1206))
                    .padding(.horizontal, 6)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(Palette.needsYou, in: .capsule)
                    .offset(x: 7, y: -7)
            }
        }
        .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([thread.title, thread.kind.label.capitalized, activity.status.label, subtitle].joined(separator: ", "))
    }

    private var tint: Color {
        if needsYou { return Palette.needsYou.opacity(0.22) }
        return .white.opacity(isFocused ? 0.1 : 0)
    }

    @ViewBuilder
    private var trailing: some View {
        switch activity.status {
        case .working, .done:
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(Self.compactElapsed(since: activity.since, now: context.date))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(activity.status == .working ? Color(hex: 0x9FCBFF) : .white.opacity(0.72))
            }
        case .exited(let code?) where code != 0:
            Text("code \(code)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.exitedText)
        default:
            EmptyView()
        }
    }

    private var subtitle: String {
        if needsYou { return activity.detail ?? "Waiting for you" }
        if thread.group == .task { return thread.displayCommand }
        return activity.terminalTitle.flatMap { $0.isEmpty ? nil : $0 } ?? thread.displayFolder
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
