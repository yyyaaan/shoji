import SwiftUI

/// Hachi's static portrait, decoration on needs-you agent cards only. Spec: docs/design/hachi/README.md.
struct HachiPortrait: View {
    let size: CGFloat

    var body: some View {
        Image(.hachiPortrait)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        HachiPortrait(size: 32)
        HachiPortrait(size: 48)
        HachiPortrait(size: 64)
    }
    .padding()
    .background(Palette.windowBackground)
}
