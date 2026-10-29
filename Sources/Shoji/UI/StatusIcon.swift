import SwiftUI

extension ThreadStatus {
    /// For menus, which can't draw `StatusIcon`.
    var symbol: String {
        switch self {
        case .working: "ellipsis.circle"
        case .needsYou: "exclamationmark.circle"
        case .done, .exited(code: 0?): "checkmark.circle"
        case .idle: "circle"
        case .running: "play.circle"
        case .exited: "xmark.circle"
        }
    }
}

/// One shape per status so state never relies on color alone; the label goes to VoiceOver and the tooltip.
struct StatusIcon: View {
    let status: ThreadStatus
    var size: CGFloat = 22

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The Torii brings its own optical padding, so it fills the whole slot instead of the ring's.
        icon
            .frame(width: status == .idle ? size : ring, height: status == .idle ? size : ring)
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel(status.label)
            .help(status.label)
    }

    private var ring: CGFloat { size * 26 / 32 }
    private var line: CGFloat { max(1.5, size * 2.6 / 32) }

    @ViewBuilder
    private var icon: some View {
        switch status {
        case .working:
            ZStack {
                Circle().stroke(Palette.working.opacity(0.22), lineWidth: line)
                Circle()
                    .trim(from: 0, to: 0.27)
                    .stroke(Palette.working, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .keyframeAnimator(initialValue: 0.0, repeating: !reduceMotion) { arc, angle in
                        arc.rotationEffect(.degrees(angle))
                    } keyframes: { _ in
                        LinearKeyframe(reduceMotion ? 0 : 360, duration: 1.4)
                    }
            }
        case .needsYou:
            glyph("exclamationmark", tint: Palette.needsYouText, ring: Palette.needsYouStroke, fill: Palette.needsYou.opacity(0.18))
        case .done, .exited(code: 0?):
            glyph("checkmark", tint: Palette.done, ring: Palette.done.opacity(0.7), fill: .white.opacity(0.08))
        case .idle:
            // At a prompt (docs/design/status). Hachi stays reserved for needs-you.
            Image(.idleTorii)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Palette.done.opacity(0.55))
        case .running:
            ZStack {
                if !reduceMotion {
                    Circle()
                        .fill(Palette.running)
                        .keyframeAnimator(initialValue: PulseFrame(), repeating: true) { dot, frame in
                            dot.scaleEffect(frame.scale).opacity(frame.opacity)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) { CubicKeyframe(2.4, duration: 1.8) }
                            KeyframeTrack(\.opacity) { CubicKeyframe(0, duration: 1.8) }
                        }
                }
                Circle().fill(Palette.running)
            }
            .frame(width: size * 12 / 32, height: size * 12 / 32)
        case .exited:
            glyph("xmark", tint: Palette.exitedText, ring: Palette.exited, fill: Palette.exited.opacity(0.16))
        }
    }

    private func glyph(_ symbol: String, tint: Color, ring: Color, fill: Color) -> some View {
        ZStack {
            Circle().fill(fill)
            Circle().stroke(ring, lineWidth: line)
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .heavy))
                .foregroundStyle(tint)
        }
    }
}

private struct PulseFrame {
    var scale = 1.0
    var opacity = 0.9
}

#Preview {
    HStack(spacing: 16) {
        ForEach([ThreadStatus.working, .needsYou, .done, .idle, .running, .exited(code: 1)], id: \.label) {
            StatusIcon(status: $0)
        }
    }
    .padding()
    .background(Palette.windowBackground)
}
