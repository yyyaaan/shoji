import SwiftUI

struct ShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Zoom.storageKey) private var zoom = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            HStack(alignment: .top, spacing: 36) {
                ForEach(ShortcutSection.columns.indices, id: \.self) { column in
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(ShortcutSection.columns[column]) { section in
                            SectionView(section: section)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            footer
        }
        .padding(28)
        .frame(width: 780)
        .foregroundStyle(Palette.text)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "keyboard")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Palette.working)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.tint(Palette.working.opacity(0.18)), in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 20, weight: .semibold))
                Text("They work everywhere in Shoji, even while a terminal has focus.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.cancelAction)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "textformat.size")
            Text("Zoom \(zoom, format: .percent.precision(.fractionLength(0)))")
                .monospacedDigit()
            Text("·")
            Text("Press")
            KeyCap(label: "⌘")
            KeyCap(label: "/")
            Text("to open this anytime")
        }
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(0.5))
        .frame(maxWidth: .infinity)
    }
}

private struct SectionView: View {
    let section: ShortcutSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(section.title.uppercased(), systemImage: section.symbol)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.55))
            VStack(spacing: 8) {
                ForEach(section.shortcuts) { shortcut in
                    HStack(spacing: 12) {
                        Text(shortcut.title)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.88))
                        Spacer(minLength: 8)
                        HStack(spacing: 4) {
                            ForEach(Array(shortcut.caps.enumerated()), id: \.offset) { KeyCap(label: $0.element) }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct KeyCap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, label.count > 1 ? 7 : 0)
            .frame(minWidth: 24, minHeight: 24)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.linearGradient(colors: [.white.opacity(0.17), .white.opacity(0.07)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.45), radius: 0, y: 1.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
    }
}

#Preview {
    ShortcutsSheet()
        .background(Backdrop())
}
