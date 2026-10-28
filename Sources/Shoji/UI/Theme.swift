import SwiftUI

enum Palette {
    static let working = Color(hex: 0x74B8FF)
    static let needsYou = Color(hex: 0xFF9F43)
    static let needsYouStroke = Color(hex: 0xFFA94D)
    static let needsYouText = Color(hex: 0xFFC078)
    static let done = Color(hex: 0xE2E8F0)
    static let running = Color(hex: 0x4FD1B5)
    static let exited = Color(hex: 0xFF8787)
    static let exitedText = Color(hex: 0xFFA8A8)
    static let text = Color(hex: 0xF2F4F8)
    static let terminalBackground = Color(hex: 0x0C0F15)
    static let windowBackground = Color(hex: 0x0B0E13)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
