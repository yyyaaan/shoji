import SwiftUI

/// Soft color fields behind the glass chrome, after the design mockup.
struct Backdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Palette.windowBackground
                glow(Color(hex: 0x3557D6), opacity: 0.5, center: CGPoint(x: size.width * 0.3, y: -40), radius: 520)
                glow(Color(hex: 0xD9631E), opacity: 0.36, center: CGPoint(x: size.width + 40, y: 360), radius: 420)
                glow(Color(hex: 0x1C9A86), opacity: 0.32, center: CGPoint(x: 140, y: size.height + 60), radius: 420)
            }
        }
        .ignoresSafeArea()
    }

    private func glow(_ color: Color, opacity: Double, center: CGPoint, radius: CGFloat) -> some View {
        RadialGradient(colors: [color.opacity(opacity), .clear], center: .center, startRadius: 0, endRadius: radius)
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
    }
}

#Preview {
    Backdrop()
        .frame(width: 1000, height: 640)
}
